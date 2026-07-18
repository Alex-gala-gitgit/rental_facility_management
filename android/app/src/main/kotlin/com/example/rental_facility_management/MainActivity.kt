package com.example.rental_facility_management

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val versionChannel = "rental_facility_manager/app_version"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, versionChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getAppVersion") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageInfo.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        packageInfo.versionCode.toLong()
                    }
                    result.success(
                        mapOf(
                            "versionName" to (packageInfo.versionName ?: "Unknown"),
                            "versionCode" to versionCode
                        )
                    )
                } catch (error: Exception) {
                    result.error(
                        "VERSION_LOOKUP_FAILED",
                        "Unable to read the installed app version.",
                        error.message
                    )
                }
            }
    }
}
