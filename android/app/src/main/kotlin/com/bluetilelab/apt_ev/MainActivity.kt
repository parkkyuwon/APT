package com.bluetilelab.apt_ev

import android.os.Build
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var indoorMonitor: IndoorLocationMonitor? = null
    private var nfcReader: ForegroundNfcReader? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        indoorMonitor = IndoorLocationMonitor(this).also { monitor ->
            monitor.recordTap(intent)
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "apt_ev/indoor_location")
                .setMethodCallHandler(monitor::handle)
        }
        nfcReader = ForegroundNfcReader(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "apt_ev/bluetooth_permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        indoorMonitor?.permissionResponse(requestCode)
    }

    override fun onResume() {
        super.onResume()
        nfcReader?.resume()
    }

    override fun onNewIntent(intent: Intent) {
        indoorMonitor?.recordTap(intent)
        nfcReader?.suppressDispatchedTag(intent)
        super.onNewIntent(intent)
    }

    override fun onPause() {
        nfcReader?.pause()
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        indoorMonitor?.dispose()
        indoorMonitor = null
        nfcReader?.dispose()
        nfcReader = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
