package com.ainexus.ai_nexus

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.zip.GZIPInputStream

/**
 * AI Nexus 内置 Ubuntu 终端桥接层（PRoot，rootless，无需 Termux / root）。
 *
 * 背景：Termux 在部分国产手机（如 OPPO）上被后台强杀导致不可用，故改为内置
 * PRoot 方案——把 Linux 用户态直接打包进 App，首次运行时下载并解压 rootfs，
 * 用 PRoot 挂载假 proc/dev 后即可运行完整 Linux/CLI（python/node/git 等）。
 *
 * 职责（MethodChannel: com.ai-nexus/proot）：
 *  - status：报告 PRoot 二进制与 rootfs 就绪状态、下载进度；
 *  - install：后台下载并解压 rootfs（进度经 status 轮询）；
 *  - execute：通过 PRoot 在 rootfs 内执行命令；
 *  - cancel：终止指定会话进程。
 *
 * 说明：PRoot 二进制需置于 apk 的 jniLibs/arm64-v8a/ 目录（工程内已预留），
 * [locateBundledProot] 会在首次使用时把它复制到私有目录并加执行权限。
 */
class ProotBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val TAG = "AI-Nexus/ProotBridge"
        private const val CHANNEL = "com.ai-nexus/proot"

        /**
         * 首次运行时下载 Ubuntu rootfs 的镜像地址（清华源）。
         *
         * 若该版本失效，请到
         *   https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/
         * 换一个仍有效的 `ubuntu-base-<版本>-base-arm64.tar.gz` 直链。
         */
        private const val ROOTFS_URL =
            "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-arm64.tar.gz"

        /** 内置 PRoot 二进制在 jniLibs 中的候选文件名。 */
        private val BUNDLED_PROOT_NAMES =
            arrayOf("libproot.so", "proot", "proot-static", "libproot-loader.so")
    }

    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val runningProcesses = ConcurrentHashMap<String, Process>()

    // 下载进度（跨线程可见，经 status 轮询读取）
    @Volatile private var downloading = false
    @Volatile private var downloadedBytes = 0L
    @Volatile private var totalBytes = -1L
    @Volatile private var phase = ""
    @Volatile private var lastError: String? = null

    private val prootDir: File get() = File(context.filesDir, "proot")
    private val rootfsDir: File get() = File(prootDir, "rootfs")
    private val prootBinary: File get() = File(prootDir, "proot")
    private val installMarker: File get() = File(rootfsDir, ".installed")

    fun register() {
        Log.i(TAG, "register: 注册 MethodChannel=$CHANNEL")
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> mainHandler.post { result.success(status()) }
                "install" -> handleInstall(call, result)
                "execute" -> handleExecute(call, result)
                "cancel" -> handleCancel(call, result)
                else -> result.notImplemented()
            }
        }
    }

    // ---------- 状态 ----------

    private fun status(): Map<String, Any> {
        val binaryPresent = prootBinary.exists() || locateBundledProot() != null
        val installed = installMarker.exists()
        return mapOf(
            "prootBinary" to binaryPresent,
            "installed" to installed,
            "downloading" to downloading,
            "phase" to phase,
            "downloadedBytes" to downloadedBytes,
            "totalBytes" to totalBytes,
            "error" to (lastError ?: ""),
            "rootfsPath" to rootfsDir.absolutePath,
            "arch" to (android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
        )
    }

    // ---------- 安装 ----------

    private fun handleInstall(call: MethodCall, result: MethodChannel.Result) {
        // 幂等：已装好直接返回
        if (installMarker.exists()) {
            result.success(
                mapOf("started" to false, "installed" to true, "message" to "已安装")
            )
            return
        }
        if (downloading) {
            result.success(
                mapOf(
                    "started" to false,
                    "installed" to false,
                    "message" to "正在下载，请稍候"
                )
            )
            return
        }

        downloading = true
        lastError = null
        downloadedBytes = 0
        totalBytes = -1
        phase = "prepare"

        executor.execute {
            try {
                ensureProotBinary()
                phase = "download"
                val archive = downloadRootfs()
                phase = "extract"
                extractTarGz(archive)
                installMarker.writeText("ok")
                phase = "done"
                Log.i(TAG, "install: rootfs 安装完成 -> ${rootfsDir.absolutePath}")
            } catch (e: Exception) {
                lastError = e.message ?: "安装失败"
                Log.e(TAG, "install: 安装失败", e)
            } finally {
                downloading = false
            }
        }
        result.success(mapOf("started" to true, "installed" to false, "message" to "已开始下载"))
    }

    /** 从 jniLibs/arm64-v8a 复制内置 PRoot 二进制到私有目录并加执行权限。 */
    private fun ensureProotBinary() {
        if (prootBinary.exists() && prootBinary.canExecute()) return
        val bundled = locateBundledProot()
            ?: throw IllegalStateException(
                "未找到内置 PRoot 二进制（jniLibs/arm64-v8a）。请先在真机提取并放置 PRoot 二进制后重试。"
            )
        prootDir.mkdirs()
        bundled.inputStream().use { input ->
            prootBinary.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        if (!prootBinary.setExecutable(true, true)) {
            Log.w(TAG, "ensureProotBinary: setExecutable 返回 false，仍将尝试执行")
        }
    }

    private fun locateBundledProot(): File? {
        val nativeDir = context.applicationInfo.nativeLibraryDir
        if (nativeDir.isNullOrEmpty()) return null
        for (name in BUNDLED_PROOT_NAMES) {
            val f = File(nativeDir, name)
            if (f.exists() && f.canRead()) {
                Log.i(TAG, "locateBundledProot: 命中 $f")
                return f
            }
        }
        return null
    }

    /** 下载 rootfs tarball 到私有目录，返回文件；期间更新下载进度。 */
    private fun downloadRootfs(): File {
        val target = File(prootDir, "rootfs.tar.gz")
        prootDir.mkdirs()

        val conn = URL(ROOTFS_URL).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "GET"
            conn.connectTimeout = 20_000
            conn.readTimeout = 60_000
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android) AI-Nexus")
            conn.instanceFollowRedirects = true

            val code = conn.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("下载 rootfs 失败 HTTP $code")
            }
            totalBytes = conn.contentLengthLong // 可能为 -1（无 Content-Length）
            downloadedBytes = 0

            val input = BufferedInputStream(conn.inputStream)
            var written = 0L
            FileOutputStream(target).use { fileOut ->
                val out = BufferedOutputStream(fileOut)
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                    written += n
                    downloadedBytes = written
                }
                out.flush()
            }
            Log.i(TAG, "downloadRootfs: 完成 $written bytes -> $target")
            return target
        } finally {
            conn.disconnect()
        }
    }

    // ---------- 执行 ----------

    private fun handleExecute(call: MethodCall, result: MethodChannel.Result) {
        val command = call.argument<String>("command")?.trim().orEmpty()
        val sessionId =
            call.argument<String>("sessionId") ?: System.currentTimeMillis().toString()

        if (command.isEmpty()) {
            result.success(
                mapOf(
                    "exitCode" to 0,
                    "stdout" to "",
                    "stderr" to "",
                    "sessionId" to sessionId,
                    "executor" to "none",
                )
            )
            return
        }

        if (!installMarker.exists()) {
            result.success(
                mapOf(
                    "exitCode" to -1,
                    "stdout" to "",
                    "stderr" to "内置 Ubuntu 尚未安装，请先在终端页点击「安装」下载 rootfs",
                    "sessionId" to sessionId,
                    "executor" to "proot",
                )
            )
            return
        }

        executor.execute {
            val startMs = System.currentTimeMillis()
            try {
                val pb = ProcessBuilder(buildProotCommand(command))
                val process = pb.start()
                runningProcesses[sessionId] = process

                val stdoutFuture = executor.submit<String> { readStream(process.inputStream) }
                val stderrFuture = executor.submit<String> { readStream(process.errorStream) }
                val exitCode = process.waitFor()
                runningProcesses.remove(sessionId)

                val stdout = stdoutFuture.get()
                val stderr = stderrFuture.get()
                Log.i(
                    TAG,
                    "execute: sessionId=$sessionId exitCode=$exitCode " +
                        "耗时=${System.currentTimeMillis() - startMs}ms"
                )
                mainHandler.post {
                    result.success(
                        mapOf(
                            "exitCode" to exitCode,
                            "stdout" to stdout,
                            "stderr" to stderr,
                            "sessionId" to sessionId,
                            "executor" to "proot",
                        )
                    )
                }
            } catch (e: Exception) {
                runningProcesses.remove(sessionId)
                Log.e(TAG, "execute: sessionId=$sessionId 异常", e)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "exitCode" to -1,
                            "stdout" to "",
                            "stderr" to "PRoot 执行失败：${e.message}",
                            "sessionId" to sessionId,
                            "executor" to "proot",
                        )
                    )
                }
            }
        }
    }

    /**
     * 组装 PRoot 调用参数。
     *
     * `-0` 将调用者视作 uid 0；`-b` 假绑定 /dev /proc /sys 等；`-w` 设定工作目录。
     * 命令统一用 /bin/bash -lc 包裹以便支持管道/重定向。
     */
    private fun buildProotCommand(command: String): Array<String> = arrayOf(
        prootBinary.absolutePath,
        "-0",
        "-r", rootfsDir.absolutePath,
        "-b", "/dev",
        "-b", "/proc",
        "-b", "/sys",
        "-w", "/root",
        "/bin/bash", "-lc", command,
    )

    private fun handleCancel(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId").orEmpty()
        val process = runningProcesses.remove(sessionId)
        try {
            process?.destroy()
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun readStream(input: InputStream): String =
        input.bufferedReader(Charsets.UTF_8).use { it.readText() }

    // ---------- tar.gz 解压 ----------

    /**
     * 解压 ubuntu-base tarball 到 [rootfsDir]。
     *
     * 仅实现 Ubuntu base 需要的最小 tar 子集：普通文件、目录、符号链接、
     * GNU 长文件名（typeflag 'L'）；硬链接（'1'）跳过并记录日志、确保可执行位。
     */
    private fun extractTarGz(archive: File) {
        if (rootfsDir.exists()) rootfsDir.deleteRecursively()
        rootfsDir.mkdirs()

        GZIPInputStream(archive.inputStream()).use { gz ->
            val input = BufferedInputStream(gz, 64 * 1024)
            var longName: String? = null

            while (true) {
                val header = readBlock(input) ?: break
                if (header.all { it == 0.toByte() }) break // 结束块

                val nameField = header.name()
                val typeflag = (header[156].toInt() and 0xFF).toChar()
                val size = header.octal(124, 12)
                val mode = header.octal(100, 8)

                var name = if (longName != null) longName!! else nameField
                longName = null

                when (typeflag) {
                    'L' -> {
                        val data = readBytes(input, size)
                        longName = String(data, Charsets.UTF_8).trimEnd('\u0000')
                        skipPadding(input, size)
                        continue
                    }
                    'x', 'g' -> {
                        skipData(input, size)
                        continue
                    }
                }

                val safeName = name.trimStart('/')
                val target = File(rootfsDir, safeName)

                when (typeflag) {
                    '0', '\u0000' -> {
                        target.parentFile?.mkdirs()
                        target.outputStream().buffered().use { out ->
                            var remaining = size
                            val buf = ByteArray(64 * 1024)
                            while (remaining > 0) {
                                val n = input.read(buf, 0, minOf(remaining, buf.size))
                                if (n < 0) break
                                out.write(buf, 0, n)
                                remaining -= n
                            }
                        }
                        applyMode(target, mode)
                        skipPadding(input, size)
                    }
                    '5' -> target.mkdirs()
                    '2' -> {
                        val link = String(
                            header.copyOfRange(157, 257),
                            Charsets.UTF_8
                        ).trimEnd('\u0000')
                        target.parentFile?.mkdirs()
                        try {
                            java.nio.file.Files.createSymbolicLink(
                                target.toPath(),
                                java.nio.file.Paths.get(link)
                            )
                        } catch (e: Exception) {
                            Log.w(TAG, "创建符号链接失败 $safeName -> $link: ${e.message}")
                        }
                    }
                    '1' -> {
                        Log.w(TAG, "跳过硬链接条目：$safeName")
                        skipData(input, size)
                    }
                    else -> skipData(input, size)
                }
            }
        }
        Log.i(TAG, "extractTarGz: 解压完成 -> ${rootfsDir.absolutePath}")
    }

    private fun applyMode(file: File, mode: Int) {
        // mode 最低位若含任一执行位则尝试赋予可执行权限
        val executable = (mode and 0b001_001_001) != 0
        if (executable) {
            file.setExecutable(true, false)
            file.setWritable(true, true)
            file.setReadable(true, false)
        }
    }

    private fun readBlock(input: InputStream): ByteArray? {
        val buf = ByteArray(512)
        var off = 0
        while (off < buf.size) {
            val n = input.read(buf, off, buf.size - off)
            if (n < 0) return if (off == 0) null else buf
            off += n
        }
        return buf
    }

    private fun readBytes(input: InputStream, count: Int): ByteArray {
        val buf = ByteArray(count)
        var off = 0
        while (off < count) {
            val n = input.read(buf, off, count - off)
            if (n < 0) break
            off += n
        }
        return buf
    }

    private fun skipData(input: InputStream, count: Int) {
        var remaining = count
        val buf = ByteArray(64 * 1024)
        while (remaining > 0) {
            val n = input.read(buf, 0, minOf(remaining, buf.size))
            if (n < 0) break
            remaining -= n
        }
        skipPadding(input, count)
    }

    private fun skipPadding(input: InputStream, size: Int) {
        val pad = (512 - (size % 512)) % 512
        if (pad == 0) return
        var remaining = pad
        val buf = ByteArray(pad)
        while (remaining > 0) {
            val n = input.read(buf, 0, remaining)
            if (n < 0) break
            remaining -= n
        }
    }

    private fun ByteArray.name(): String {
        val end = indexOfFirst { it == 0.toByte() }.let { if (it < 0) 100 else it }
        return String(this, 0, end, Charsets.UTF_8)
    }

    private fun ByteArray.octal(start: Int, len: Int): Int {
        var v = 0
        for (i in start until start + len) {
            val c = (this[i].toInt() and 0xFF).toChar()
            if (c == 0.toChar() || c == ' ') break
            v = v * 8 + c.digitToInt(8)
        }
        return v
    }
}