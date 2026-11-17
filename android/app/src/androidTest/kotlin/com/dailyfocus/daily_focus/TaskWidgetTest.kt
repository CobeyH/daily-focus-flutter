package com.dailyfocus.daily_focus

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.SystemClock
import android.view.View
import android.widget.ListView
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class TaskWidgetTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    private fun sample(): String = JSONObject().apply {
        put("date", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
        put("nextRefreshAt", System.currentTimeMillis() + 3600000)
        put("total", 2)
        put("upcoming", 1)
        put("empty", "All clear for now")
        put("tasks", JSONArray().put(JSONObject().apply {
            put("name", "Read a chapter")
            put("detail", "5 / 15 min · Due today")
            put("progress", 5)
            put("goal", 15)
        }).put(JSONObject().apply {
            put("name", "Laundry")
            put("detail", "Step 2 / 2 · Dry · Due today at 18:00")
            put("progress", 1)
            put("goal", 2)
        }))
    }.toString()

    @After fun clearWidgetCache() {
        TaskWidgetProvider.publish(context, false, null)
    }

    @Test fun signOutAndNewAppChangesRejectStaleBackgroundResults() {
        TaskWidgetProvider.publish(context, true, sample())
        val revision = TaskWidgetProvider.store(context).getLong("revision", 0)
        TaskWidgetProvider.publish(context, true, sample().replace("Laundry", "Updated laundry"))
        TaskWidgetProvider.publishBackground(context, sample(), revision)
        assertEquals("Updated laundry", TaskWidgetProvider.snapshot(context)!!
            .getJSONArray("tasks").getJSONObject(1).getString("name"))
        TaskWidgetProvider.publish(context, false, null)
        TaskWidgetProvider.publishBackground(context, sample(), revision)
        assertNull(TaskWidgetProvider.snapshot(context))
        instrumentation.runOnMainSync {
            val view = TaskWidgetProvider.createViews(context, 0).apply(context, AppWidgetHostView(context))
            assertEquals("Sign in to see your tasks", view.findViewById<TextView>(R.id.widget_empty).text.toString())
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_tasks).visibility)
        }
    }

    @Test fun nativePanelRendersScrollableTasksAndCapturesLightAndDarkPreviews() {
        TaskWidgetProvider.publish(context, true, sample())
        for ((name, mode) in listOf("light" to Configuration.UI_MODE_NIGHT_NO,
                "dark" to Configuration.UI_MODE_NIGHT_YES)) {
            val config = Configuration(context.resources.configuration).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
            }
            val themed = context.createConfigurationContext(config)
            instrumentation.runOnMainSync {
                val view = TaskWidgetProvider.createViews(themed, 0).apply(themed, AppWidgetHostView(themed))
                val list = view.findViewById<ListView>(R.id.widget_tasks)
                assertEquals(2, list.adapter.count)
                val first = list.adapter.getView(0, null, list)
                assertEquals("Read a chapter", first.findViewById<TextView>(R.id.widget_task_name).text.toString())
                assertEquals("1 task later today", view.findViewById<TextView>(R.id.widget_footer).text.toString())
                val density = themed.resources.displayMetrics.density
                val width = (340 * density).toInt()
                val height = (300 * density).toInt()
                view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                view.layout(0, 0, width, height)
                val image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                view.draw(Canvas(image))
                File(context.cacheDir, "task-widget-$name.png").outputStream().use {
                    image.compress(Bitmap.CompressFormat.PNG, 100, it)
                }
                image.recycle()
                // The same panel must also lay out at its minimum resizable size.
                view.measure(View.MeasureSpec.makeMeasureSpec((180 * density).toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec((180 * density).toInt(), View.MeasureSpec.EXACTLY))
                view.layout(0, 0, view.measuredWidth, view.measuredHeight)
            }
        }
    }

    @Test fun backgroundRefreshUsesSavedDartSchedulesWithoutOpeningTheApp() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val saved = listOf("flutter.tasks_v1", "flutter.entries_v1", "flutter.active_timers_v1", "flutter.day_slots_v1")
            .associateWith { prefs.getString(it, null) }
        val host = AppWidgetHost(context, 812)
        val id = host.allocateAppWidgetId()
        try {
            val task = JSONObject().apply {
                put("id", "widget-offline-test"); put("name", "Offline laundry")
                put("type", "count"); put("goal", 1); put("step", 1)
                put("createdAt", "2026-01-01T00:00:00")
            }
            assertTrue(prefs.edit().putString("flutter.tasks_v1", JSONArray().put(task).toString())
                .putString("flutter.entries_v1", "[]").putString("flutter.active_timers_v1", "[]")
                .remove("flutter.day_slots_v1").commit())
            TaskWidgetProvider.publish(context, true, sample())
            instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET")
            val bound = AppWidgetManager.getInstance(context).bindAppWidgetIdIfAllowed(id,
                ComponentName(context, TaskWidgetProvider::class.java))
            instrumentation.uiAutomation.dropShellPermissionIdentity()
            assertTrue("Could not bind test widget", bound)
            TaskWidgetProvider.refresh(context)
            val deadline = SystemClock.elapsedRealtime() + 40000
            var actual: String? = null
            while (SystemClock.elapsedRealtime() < deadline) {
                actual = TaskWidgetProvider.snapshot(context)?.optJSONArray("tasks")
                    ?.optJSONObject(0)?.optString("name")
                if (actual == "Offline laundry") break
                SystemClock.sleep(200)
            }
            assertEquals("Headless Dart refresh did not publish saved tasks", "Offline laundry", actual)
        } finally {
            instrumentation.uiAutomation.dropShellPermissionIdentity()
            host.deleteAppWidgetId(id)
            val editor = prefs.edit()
            for ((key, value) in saved) if (value == null) editor.remove(key) else editor.putString(key, value)
            editor.commit()
        }
    }
}
