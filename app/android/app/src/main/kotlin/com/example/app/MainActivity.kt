package com.example.app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val arCoreDepthChannelName = "roomforge/arcore_depth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            arCoreDepthChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method != "isDepthSupported") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val hasArCameraFeature = packageManager.hasSystemFeature("android.hardware.camera.ar")
            val hasArCorePackage = isPackageInstalled("com.google.ar.core")
            val supported = hasArCameraFeature && hasArCorePackage
            val reason = if (supported) {
                "Android AR camera feature and ARCore package detected. Depth metadata is still approximate."
            } else {
                "Android ARCore Depth capability was not detected; guided photos remain available."
            }
            result.success(
                mapOf(
                    "supported" to supported,
                    "reason" to reason
                )
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }
}
