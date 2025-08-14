package com.example.sinkplayer

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ABI_CHANNEL = "flutter/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register ABI channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ABI_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAbi") {
                result.success(Build.SUPPORTED_ABIS.getOrNull(0) ?: "unknown")
            } else {
                result.notImplemented()
            }
        }

        // Register NewPipe handler with context parameter
        // val newPipeHandler = NewPipeMethodHandler(flutterEngine, this)  // Pass 'this' as context
        // newPipeHandler.register()
    }
}