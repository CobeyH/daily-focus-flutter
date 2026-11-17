package com.dailyfocus.daily_focus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TaskWidgetProvider.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "publish") {
                    TaskWidgetProvider.publish(applicationContext,
                        call.argument<Boolean>("signedIn") == true,
                        call.argument<String>("snapshot"))
                    result.success(null)
                } else result.notImplemented()
            }
    }
}
