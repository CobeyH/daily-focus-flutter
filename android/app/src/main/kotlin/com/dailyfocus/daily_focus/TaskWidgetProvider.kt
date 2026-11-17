package com.dailyfocus.daily_focus

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

open class TaskWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        renderAll(context)
        refresh(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager,
        id: Int, options: Bundle) = renderAll(context)

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(REFRESH, Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                Intent.ACTION_DATE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            renderAll(context)
            refresh(context)
        }
    }

    override fun onDisabled(context: Context) {
        if (ids(context).isNotEmpty()) return
        alarm(context).cancel(refreshIntent(context))
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    companion object {
        const val CHANNEL = "daily_focus/home_widget"
        const val REFRESH = "com.dailyfocus.daily_focus.REFRESH_TASK_WIDGET"
        private const val WORK_NAME = "daily-focus-task-widget"
        private const val PREFS = "task_widget"

        fun store(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        fun ids(context: Context): IntArray {
            val manager = AppWidgetManager.getInstance(context)
            return listOf(TaskWidgetProvider::class.java, CompactTaskWidgetProvider::class.java)
                .flatMap { manager.getAppWidgetIds(ComponentName(context, it)).toList() }.toIntArray()
        }

        fun publish(context: Context, signedIn: Boolean, snapshot: String?) {
            val prefs = store(context)
            prefs.edit().putBoolean("signedIn", signedIn)
                .putLong("revision", prefs.getLong("revision", 0) + 1)
                .putString("snapshot", if (signedIn) snapshot else null).apply()
            renderAll(context)
            schedule(context)
        }

        fun publishBackground(context: Context, snapshot: String, revision: Long) {
            val prefs = store(context)
            // Never restore signed-out content or overwrite a newer app change.
            if (!prefs.getBoolean("signedIn", false) ||
                prefs.getLong("revision", 0) != revision) return
            prefs.edit().putString("snapshot", snapshot).apply()
            renderAll(context)
            schedule(context)
        }

        fun snapshot(context: Context): JSONObject? {
            val prefs = store(context)
            if (!prefs.getBoolean("signedIn", false)) return null
            return try {
                val result = JSONObject(prefs.getString("snapshot", null) ?: return null)
                // Do not leave yesterday's completed/one-off tasks on screen at rollover.
                if (result.optString("date") !=
                    SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())) null else result
            } catch (_: Exception) { null }
        }

        fun refresh(context: Context) {
            if (ids(context).isEmpty()) return
            WorkManager.getInstance(context).enqueueUniqueWork(WORK_NAME,
                ExistingWorkPolicy.KEEP, OneTimeWorkRequestBuilder<TaskWidgetWorker>().build())
        }

        private fun alarm(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        private fun refreshIntent(context: Context) = PendingIntent.getBroadcast(context, 1,
            Intent(context, TaskWidgetProvider::class.java).setAction(REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun schedule(context: Context) {
            if (ids(context).isEmpty()) return
            val pending = refreshIntent(context)
            val next = snapshot(context)?.optLong("nextRefreshAt", 0) ?: 0
            if (next <= System.currentTimeMillis()) {
                alarm(context).cancel(pending)
            } else {
                // Inexact alarms respect Android's battery/background limits and
                // need no additional exact-alarm permission or foreground service.
                alarm(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
            }
        }

        fun row(context: Context, task: JSONObject, compact: Boolean = false): RemoteViews =
            RemoteViews(context.packageName, if (compact) R.layout.task_widget_compact_row else R.layout.task_widget_row).apply {
                setTextViewText(R.id.widget_task_name, task.optString("name"))
                setTextViewText(R.id.widget_task_detail, if (compact)
                    task.optString("compactDetail", task.optString("detail")) else task.optString("detail"))
                setProgressBar(R.id.widget_task_progress, task.optInt("goal", 1).coerceAtLeast(1),
                    task.optInt("progress", 0), false)
                setOnClickFillInIntent(R.id.widget_task_row, Intent())
            }

        fun createViews(context: Context, id: Int, compact: Boolean = false): RemoteViews {
            val signedIn = store(context).getBoolean("signedIn", false)
            val data = snapshot(context)
            val tasks = data?.optJSONArray("tasks")
            val count = tasks?.length() ?: 0
            val open = PendingIntent.getActivity(context, 0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            // Collection fill-in intents require a mutable, explicit template.
            val openRow = PendingIntent.getActivity(context, 2,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0))
            val views = RemoteViews(context.packageName,
                if (compact) R.layout.task_widget_compact else R.layout.task_widget)
            val datePattern = android.text.format.DateFormat.getBestDateTimePattern(
                Locale.getDefault(), if (compact) "MMM d" else "EEE MMM d")
            views.setTextViewText(R.id.widget_date,
                SimpleDateFormat(datePattern, Locale.getDefault()).format(Date()))
            views.setOnClickPendingIntent(R.id.widget_header, open)
            views.setOnClickPendingIntent(R.id.widget_empty, open)
            views.setOnClickPendingIntent(R.id.widget_footer, open)
            views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent(context))
            views.setPendingIntentTemplate(R.id.widget_tasks, openRow)
            views.setViewVisibility(R.id.widget_tasks, if (count > 0) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_empty, if (count > 0) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_empty, when {
                !signedIn -> "Sign in to see your tasks"
                data == null -> "Open Daily Focus to load tasks"
                else -> data.optString("empty", "All clear for now")
            })
            val upcoming = data?.optInt("upcoming") ?: 0
            val total = data?.optInt("total") ?: 0
            views.setTextViewText(R.id.widget_footer, when {
                !signedIn -> "Tap to open Daily Focus"
                total > count -> "${total - count} more in Daily Focus"
                compact && count > 0 -> "$total ${if (total == 1) "task" else "tasks"}"
                upcoming > 0 -> "$upcoming ${if (upcoming == 1) "task" else "tasks"} later today"
                else -> "Daily Focus"
            })
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val items = RemoteViews.RemoteCollectionItems.Builder().setViewTypeCount(1)
                for (i in 0 until count) items.addItem(i.toLong(), row(context, tasks!!.getJSONObject(i), compact))
                views.setRemoteAdapter(R.id.widget_tasks, items.build())
            } else {
                val adapter = Intent(context, TaskWidgetService::class.java)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    .putExtra("compact", compact)
                adapter.data = android.net.Uri.parse("dailyfocus-widget://tasks/$id/$compact")
                @Suppress("DEPRECATION")
                views.setRemoteAdapter(R.id.widget_tasks, adapter)
            }
            return views
        }

        fun renderAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val widgetIds = ids(context)
            for (id in widgetIds) {
                val compact = manager.getAppWidgetInfo(id)?.provider?.className ==
                    CompactTaskWidgetProvider::class.java.name
                manager.updateAppWidget(id, createViews(context, id, compact))
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && widgetIds.isNotEmpty()) {
                @Suppress("DEPRECATION")
                manager.notifyAppWidgetViewDataChanged(widgetIds, R.id.widget_tasks)
            }
        }
    }
}
