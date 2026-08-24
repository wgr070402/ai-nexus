package com.ainexus.ai_nexus

import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 主界面 Activity。
 *
 * 除了承载 Flutter UI 外，负责：
 * 1. 动态申请 Termux 的 RUN_COMMAND 权限（dangerous 级别，需运行时授权）；
 * 2. 注册终端执行桥接层（TermuxBridge），打通 Flutter -> Kotlin -> Termux/本地 shell。
 *
 * 说明：
 * Flutter 受 Android 沙盒限制无法直接执行 shell，必须通过 Platform Channel
 * （名称 com.ai-nexus/termux）桥接到 Termux 提供的 Linux/CLI 环境；
 * 同时 TermuxBridge 内置本地 shell（/system/bin/sh）作为无 Termux 时的兜底。
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Termux 0.118+ 的 com.termux.permission.RUN_COMMAND 是 dangerous 权限，
        // 仅在 manifest 声明不够，必须在运行时弹窗申请，否则调用 RunCommandService
        // 会抛 SecurityException。
        requestRunCommandPermission()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 授权结果由系统记录，无需额外处理；后续 TermuxBridge 调用会重新检查权限。
    }

    private fun requestRunCommandPermission() {
        if (checkSelfPermission(RUN_COMMAND_PERMISSION) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(RUN_COMMAND_PERMISSION), REQUEST_RUN_COMMAND)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册终端桥接层；具体实现见 TermuxBridge.kt / ProotBridge.kt。
        TermuxBridge(this, flutterEngine.dartExecutor.binaryMessenger).register()
        ProotBridge(this, flutterEngine.dartExecutor.binaryMessenger).register()
    }

    companion object {
        private const val RUN_COMMAND_PERMISSION = "com.termux.permission.RUN_COMMAND"
        private const val REQUEST_RUN_COMMAND = 1001
    }
}
