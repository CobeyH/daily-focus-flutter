package com.dailyfocus.daily_focus

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class TaskWidgetWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        val context = applicationContext
        if (TaskWidgetProvider.ids(context).isEmpty() ||
            !TaskWidgetProvider.store(context).getBoolean("signedIn", false)) return Result.success()
        val revision = TaskWidgetProvider.store(context).getLong("revision", 0)
        val done = CountDownLatch(1)
        val main = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null
        var succeeded = false
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context)
                loader.ensureInitializationComplete(context, null)
                val background = FlutterEngine(context)
                engine = background
                MethodChannel(background.dartExecutor.binaryMessenger, TaskWidgetProvider.CHANNEL)
                    .setMethodCallHandler { call, result ->
                        when (call.method) {
                            "backgroundSnapshot" -> {
                                TaskWidgetProvider.publishBackground(context, call.arguments as String, revision)
                                succeeded = true
                                result.success(null)
                                done.countDown()
                            }
                            "backgroundError" -> {
                                Log.w("DailyFocusWidget", "Could not refresh cached tasks: ${call.arguments}")
                                result.success(null)
                                done.countDown()
                            }
                            else -> result.notImplemented()
                        }
                    }
                background.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "homeWidgetMain"))
            } catch (error: Exception) {
                Log.w("DailyFocusWidget", "Could not start widget refresh", error)
                done.countDown()
            }
        }
        try {
            done.await(25, TimeUnit.SECONDS)
        } finally {
            main.post { engine?.destroy() }
        }
        return if (succeeded) Result.success() else Result.retry()
    }
}
