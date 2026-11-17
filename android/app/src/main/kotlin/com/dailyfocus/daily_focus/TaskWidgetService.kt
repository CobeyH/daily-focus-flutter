package com.dailyfocus.daily_focus

import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

// Compatibility adapter for launchers on Android 11 and earlier.
class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = object : RemoteViewsFactory {
        private var tasks = JSONArray()
        override fun onCreate() = onDataSetChanged()
        override fun onDataSetChanged() {
            tasks = TaskWidgetProvider.snapshot(applicationContext)?.optJSONArray("tasks") ?: JSONArray()
        }
        override fun onDestroy() { tasks = JSONArray() }
        override fun getCount() = tasks.length()
        override fun getViewAt(position: Int): RemoteViews? = tasks.optJSONObject(position)?.let {
            TaskWidgetProvider.row(applicationContext, it)
        }
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = false
    }
}
