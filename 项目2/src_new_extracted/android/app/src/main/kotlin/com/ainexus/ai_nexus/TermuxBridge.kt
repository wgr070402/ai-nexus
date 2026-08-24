package com.ainexus.ai_nexus

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.ResultReceiver
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * AI Nexus 终端执行桥接层。
 *
 * 职责：
 * 1. 通过 MethodChannel(com.ai-nexus/termux) 暴露 execute / kill / listSessions / checkInstalled。
 * 2. 提供两条执行通道：
 *    - 本地 shell（/system/bin/sh -c）：不依赖 Termux，任何 Android 设备都能运行基础命令，
 *      作为默认且必定可用的兜底。
 *    - Termux（Termux:API RunCommandService）：提供完整 Linux/CLI（python/node/git 等），
 *      需要真机安装 Termux 并实测。
 *
 * 安全（策划书硬性要求）：Termux 自 0.118 起强制签名校验，仅信任 F-Droid 版与
 * GitHub Release 版。本类在调用 Termux 前校验其签名证书 SHA-256，防止被恶意替换；
 * 校验失败则拒绝走 Termux 通道并回退本地 shell，同时输出详细日志便于排查。
 */
class TermuxBridge(
    private val context: Context,
    private val messenger: BinaryMessenger,
) {
    companion object {
        private const val TAG = "AI-Nexus/TermuxBridge"
        private const val CHANNEL = "com.ai-nexus/termux"
        private const val TERMUX_PACKAGE = "com.termux"
        private const val TERMUX_API_PACKAGE = "com.termux.api"

        // Termux RUN_COMMAND 服务由 Termux 本体提供（非 Termux:API）。
        // 组件：com.termux.app.RunCommandService。
        private const val TERMUX_RUN_COMMAND_SERVICE = "com.termux.app.RunCommandService"

        // RUN_COMMAND 协议约定的 Intent 参数键
        private const val RUN_COMMAND_ACTION = "com.termux.RUN_COMMAND"
        private const val EXTRA_PATH = "com.termux.RUN_COMMAND_PATH"
        private const val EXTRA_ARGUMENTS = "com.termux.RUN_COMMAND_ARGUMENTS"
        private const val EXTRA_WORKDIR = "com.termux.RUN_COMMAND_WORKDIR"
        private const val EXTRA_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND"
        private const val EXTRA_RESULT_RECEIVER = "com.termux.RUN_COMMAND_RESULT_RECEIVER"
        private const val RESULT_STDOUT = "com.termux.RUN_COMMAND_STDOUT"
        private const val RESULT_STDERR = "com.termux.RUN_COMMAND_STDERR"
        private const val RESULT_EXIT_CODE = "com.termux.RUN_COMMAND_EXIT_CODE"

        /**
         * Termux 官方签名证书 SHA-256（源自 termux-app 源码 TermuxConstants.java）。
         * 仅信任这两个发布渠道，其余签名视为非法（被替换/仿冒）。
         */
        private const val FDROID_SIGNING_CERT_SHA256 =
            "228FB2CFE90831C1499EC3CCAF61E96E8E1CE70766B9474672CE427334D41C42"
        private const val GITHUB_SIGNING_CERT_SHA256 =
            "B6DA01480EEFD5FBF2CD3771B8D1021EC791304BDD6C4BF41D3FAABAD48EE5E1"
    }

    // sessionId -> 本地 shell 正在运行的 Process（供 kill 使用）
    private val runningProcesses = ConcurrentHashMap<String, Process>()
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register() {
        Log.i(TAG, "register: 注册 MethodChannel=$CHANNEL")
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "onMethodCall: method=${call.method}")
            when (call.method) {
                "checkInstalled" -> result.success(checkInstalled())
                "execute" -> handleExecute(call, result)
                "kill" -> handleKill(call, result)
                "listSessions" -> result.success(runningProcesses.keys.toList())
                else -> result.notImplemented()
            }
        }
    }

    /** 检测 Termux 与 Termux:API 是否安装、版本号及签名校验结果。 */
    private fun checkInstalled(): Map<String, Any> {
        val termux = queryPackage(TERMUX_PACKAGE)
        val termuxApi = queryPackage(TERMUX_API_PACKAGE)

        val sha256 = if (termux.first) getSigningCertificateSha256(TERMUX_PACKAGE) else ""
        val signatureValid = if (termux.first) isTermuxSignatureValidInternal(sha256) else false

        Log.i(
            TAG,
            "checkInstalled: termux=${termux.first}(v=${termux.second}) " +
                "termuxApi=${termuxApi.first}(v=${termuxApi.second}) " +
                "sha256=$sha256 signatureValid=$signatureValid"
        )

        return mapOf(
            "termux" to termux.first,
            "termuxVersion" to termux.second,
            "termuxApi" to termuxApi.first,
            "termuxApiVersion" to termuxApi.second,
            "termuxSha256" to sha256,
            "termuxSignatureValid" to signatureValid,
        )
    }

    private fun queryPackage(pkg: String): Pair<Boolean, String> {
        return try {
            val info = context.packageManager.getPackageInfo(pkg, 0)
            Pair(true, info.versionName ?: "unknown")
        } catch (e: PackageManager.NameNotFoundException) {
            Pair(false, "")
        }
    }

    /**
     * 计算指定应用的签名证书 SHA-256（十六进制大写、无冒号）。
     * 使用 GET_SIGNING_CERTIFICATES（API 28+，minSdk 29 满足要求）。
     */
    private fun getSigningCertificateSha256(pkg: String): String {
        return try {
            val info = context.packageManager.getPackageInfo(
                pkg,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
            val signers = info.signingInfo?.apkContentsSigners ?: emptyArray()
            if (signers.isEmpty()) {
                Log.w(TAG, "getSigningCertificateSha256: $pkg 无签名证书")
                return ""
            }
            val cert = signers[0]
            val digest = MessageDigest.getInstance("SHA-256").digest(cert.toByteArray())
            val hex = digest.joinToString("") {
                (it.toInt() and 0xFF).toString(16).padStart(2, '0').uppercase()
            }
            Log.d(TAG, "getSigningCertificateSha256: $pkg -> $hex")
            hex
        } catch (e: Exception) {
            Log.e(TAG, "getSigningCertificateSha256: 计算 $pkg 签名失败", e)
            ""
        }
    }

    /** 校验给定 SHA-256 是否为可信 Termux 签名。 */
    private fun isTermuxSignatureValidInternal(sha256: String): Boolean {
        val valid = sha256.equals(FDROID_SIGNING_CERT_SHA256, ignoreCase = true) ||
            sha256.equals(GITHUB_SIGNING_CERT_SHA256, ignoreCase = true)
        Log.i(TAG, "isTermuxSignatureValid: sha256=$sha256 valid=$valid")
        return valid
    }

    private fun handleExecute(call: MethodCall, result: MethodChannel.Result) {
        val command = call.argument<String>("command")?.trim().orEmpty()
        val sessionId = call.argument<String>("sessionId")
            ?: System.currentTimeMillis().toString()
        val useTermux = call.argument<Boolean>("useTermux") ?: true

        Log.i(
            TAG,
            "handleExecute: sessionId=$sessionId useTermux=$useTermux command=" +
                command.take(200)
        )

        if (command.isEmpty()) {
            Log.d(TAG, "handleExecute: 空命令，直接返回")
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

        // RUN_COMMAND 由 Termux 本体提供，只需 Termux 已安装即可走 Termux 通道；
        // Termux:API 是独立的 Android 系统 API 桥接 App，并非执行 shell 命令的前置条件。
        val termuxReady = queryPackage(TERMUX_PACKAGE).first
        val signatureValid = if (termuxReady) {
            isTermuxSignatureValidInternal(getSigningCertificateSha256(TERMUX_PACKAGE))
        } else {
            false
        }

        Log.i(
            TAG,
            "handleExecute 决策: termuxReady=$termuxReady signatureValid=$signatureValid " +
                "-> 通道=${if (useTermux && termuxReady && signatureValid) "termux" else "local"}"
        )

        when {
            useTermux && termuxReady && signatureValid -> {
                Log.i(TAG, "handleExecute: 走 Termux 通道")
                executeViaTermux(command, sessionId, result)
            }
            useTermux && termuxReady && !signatureValid -> {
                Log.w(TAG, "handleExecute: Termux 签名校验失败，拒绝 Termux，回退本地 shell")
                executeLocal(
                    command,
                    sessionId,
                    result,
                    "TERMUX 签名校验失败（已被回退本地 shell 执行，结果能力受限）"
                )
            }
            else -> {
                Log.i(TAG, "handleExecute: 本地 shell 兜底")
                executeLocal(command, sessionId, result)
            }
        }
    }

    /** 本地 shell 执行：`/system/bin/sh -c <command>`，保证可用（无需 Termux）。 */
    private fun executeLocal(
        command: String,
        sessionId: String,
        result: MethodChannel.Result,
        stderrNote: String? = null,
    ) {
        executor.execute {
            val startMs = System.currentTimeMillis()
            try {
                Log.d(TAG, "executeLocal: sessionId=$sessionId 启动 /system/bin/sh -c")
                val process = ProcessBuilder("/system/bin/sh", "-c", command).start()
                runningProcesses[sessionId] = process

                // 并发读取 stdout/stderr，避免缓冲区写满导致死锁
                val stdoutFuture = executor.submit<String> { readStream(process.inputStream) }
                val stderrFuture = executor.submit<String> { readStream(process.errorStream) }
                val exitCode = process.waitFor()
                runningProcesses.remove(sessionId)

                val stdout = stdoutFuture.get()
                var stderr = stderrFuture.get()
                if (!stderrNote.isNullOrEmpty()) {
                    stderr = if (stderr.isEmpty()) stderrNote else "$stderrNote\n$stderr"
                }

                Log.i(
                    TAG,
                    "executeLocal: sessionId=$sessionId exitCode=$exitCode " +
                        "耗时=${System.currentTimeMillis() - startMs}ms"
                )

                val output = mapOf(
                    "exitCode" to exitCode,
                    "stdout" to stdout,
                    "stderr" to stderr,
                    "sessionId" to sessionId,
                    "executor" to "local",
                )
                mainHandler.post { result.success(output) }
            } catch (e: Exception) {
                Log.e(TAG, "executeLocal: sessionId=$sessionId 执行异常", e)
                runningProcesses.remove(sessionId)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "exitCode" to -1,
                            "stdout" to "",
                            "stderr" to (e.message ?: "本地执行失败"),
                            "sessionId" to sessionId,
                            "executor" to "local",
                        )
                    )
                }
            }
        }
    }

    /** Termux 路径：通过 Termux 的 RunCommandService 执行完整的 Linux 命令。 */
    private fun executeViaTermux(command: String, sessionId: String, result: MethodChannel.Result) {
        try {
            Log.i(
                TAG,
                "executeViaTermux: sessionId=$sessionId 通过 RunCommandService 执行 command=" +
                    command.take(200)
            )
            val intent = Intent().apply {
                setClassName(TERMUX_PACKAGE, TERMUX_RUN_COMMAND_SERVICE)
                action = RUN_COMMAND_ACTION
                putExtra(EXTRA_PATH, "/data/data/com.termux/files/usr/bin/bash")
                putExtra(EXTRA_ARGUMENTS, arrayOf("-c", command))
                putExtra(EXTRA_WORKDIR, "/data/data/com.termux/files/home")
                // 后台执行模式：不打开 Termux 前台终端会话，结果经 ResultReceiver 回传。
                // 若设为 false，会在 Android 12+ 触发
                // BackgroundServiceStartNotAllowedException（前台服务启动被限制）。
                putExtra(EXTRA_BACKGROUND, true)
                putExtra(
                    EXTRA_RESULT_RECEIVER,
                    object : ResultReceiver(mainHandler) {
                        override fun onReceiveResult(resultCode: Int, resultData: Bundle) {
                            val stdout = readFileDescriptor(resultData.getParcelable(RESULT_STDOUT))
                            val stderr = readFileDescriptor(resultData.getParcelable(RESULT_STDERR))
                            val exitCode = resultData.getInt(RESULT_EXIT_CODE, resultCode)
                            Log.i(
                                TAG,
                                "executeViaTermux onReceive: sessionId=$sessionId " +
                                    "resultCode=$resultCode exitCode=$exitCode"
                            )
                            result.success(
                                mapOf(
                                    "exitCode" to exitCode,
                                    "stdout" to stdout,
                                    "stderr" to stderr,
                                    "sessionId" to sessionId,
                                    "executor" to "termux",
                                )
                            )
                        }
                    }
                )
            }
            context.startService(intent)
        } catch (e: SecurityException) {
            // Termux 签名校验失败或权限不足
            Log.e(TAG, "executeViaTermux: sessionId=$sessionId 被拒绝（签名/权限）", e)
            result.success(
                mapOf(
                    "exitCode" to -1,
                    "stdout" to "",
                    "stderr" to "Termux 调用被拒绝（签名校验/权限不足）：${e.message}",
                    "sessionId" to sessionId,
                    "executor" to "termux",
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "executeViaTermux: sessionId=$sessionId 调用失败", e)
            result.success(
                mapOf(
                    "exitCode" to -1,
                    "stdout" to "",
                    "stderr" to "Termux 调用失败：${e.message}",
                    "sessionId" to sessionId,
                    "executor" to "termux",
                )
            )
        }
    }

    private fun readFileDescriptor(fd: ParcelFileDescriptor?): String {
        if (fd == null) return ""
        return try {
            FileInputStream(fd.fileDescriptor).use { input ->
                input.readBytes().toString(Charsets.UTF_8)
            }
        } catch (e: Exception) {
            Log.e(TAG, "readFileDescriptor 失败", e)
            ""
        }
    }

    private fun handleKill(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId").orEmpty()
        val process = runningProcesses.remove(sessionId)
        Log.i(TAG, "handleKill: sessionId=$sessionId process=${process != null}")
        try {
            process?.destroy()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "handleKill: sessionId=$sessionId 失败", e)
            result.success(false)
        }
    }

    private fun readStream(input: InputStream): String =
        input.bufferedReader(Charsets.UTF_8).use { it.readText() }
}