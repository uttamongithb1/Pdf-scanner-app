package com.lumen.pdfscanner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity: FlutterActivity() {
    private lateinit var engine: ScannerEngine
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = ScannerEngine(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    @Deprecated("Activity result is forwarded to the scanner bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!engine.activityResult(requestCode, resultCode, data)) super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onDestroy() { if (::engine.isInitialized) engine.close(); super.onDestroy() }
}
