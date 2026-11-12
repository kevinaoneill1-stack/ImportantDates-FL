package com.kevinaoneill.importantdates

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * "Upcoming Dates" home screen widget.
 *
 * The app (lib/services/home_widget_sync.dart) saves the active items as JSON
 * under "upcoming_dates": {"showDetails": bool, "items": [{"due": "yyyy-MM-dd",
 * "item", "name", "travel"}]}, soonest first. Days left are worked out here
 * from each due date, so they stay right when the app isn't opened (the system
 * redraws the widget every few hours, see upcoming_dates_widget_info.xml).
 */
class UpcomingDatesWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) draw(context, appWidgetManager, id, widgetData)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // Resized: show as many rows as fit.
        draw(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private data class Entry(val due: Calendar, val item: String, val name: String)

    private fun draw(context: Context, manager: AppWidgetManager, widgetId: Int, data: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.upcoming_dates_widget)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )

        var showDetails = true
        val entries = mutableListOf<Entry>()
        try {
            val raw = data.getString(DATA_KEY, null)
            if (raw != null) {
                val json = JSONObject(raw)
                showDetails = json.optBoolean("showDetails", true)
                val items = json.optJSONArray("items")
                if (items != null) {
                    for (i in 0 until items.length()) {
                        val o = items.getJSONObject(i)
                        val due = parseDay(o.optString("due")) ?: continue
                        entries.add(Entry(due, o.optString("item"), o.optString("name")))
                    }
                }
            }
        } catch (e: Exception) {
            // Unreadable data: show the empty state rather than crash the launcher.
            entries.clear()
        }

        val todayDate = today()
        val within30 = entries.count { daysBetween(todayDate, it.due) in 0..30 }
        val overdue = entries.count { daysBetween(todayDate, it.due) < 0 }
        views.setTextViewText(
            R.id.widget_summary,
            when {
                overdue > 0 -> context.getString(R.string.widget_overdue_count, overdue)
                else -> context.getString(R.string.widget_due_30_count, within30)
            },
        )
        views.setTextColor(
            R.id.widget_summary,
            ContextCompat.getColor(context, if (overdue > 0) R.color.widget_danger else R.color.widget_secondary_text),
        )

        val rowCount = rowsThatFit(manager, widgetId)
        // Due dates are held at midnight UTC (see day()), so format them in UTC.
        val dateFormat = SimpleDateFormat("d MMM yyyy", Locale.getDefault()).apply { timeZone = UTC }
        for ((index, row) in ROWS.withIndex()) {
            val entry = entries.getOrNull(index)
            if (entry == null || index >= rowCount) {
                views.setViewVisibility(row.container, View.GONE)
                continue
            }
            views.setViewVisibility(row.container, View.VISIBLE)
            val days = daysBetween(todayDate, entry.due)
            val dueText = dateFormat.format(entry.due.time)
            if (showDetails) {
                views.setTextViewText(row.title, entry.item.ifBlank { context.getString(R.string.widget_untitled) })
                val subtitle = if (entry.name.isBlank()) dueText else "${entry.name} · $dueText"
                views.setTextViewText(row.subtitle, subtitle)
            } else {
                views.setTextViewText(row.title, context.getString(R.string.widget_due_on, dueText))
                views.setTextViewText(row.subtitle, "")
            }
            views.setViewVisibility(row.subtitle, if (showDetails) View.VISIBLE else View.GONE)
            views.setTextViewText(row.days, daysText(context, days))
            views.setTextColor(row.days, ContextCompat.getColor(context, statusColor(days)))
        }
        views.setViewVisibility(R.id.widget_empty, if (entries.isEmpty()) View.VISIBLE else View.GONE)

        manager.updateAppWidget(widgetId, views)
    }

    private fun rowsThatFit(manager: AppWidgetManager, widgetId: Int): Int {
        val minHeight = manager.getAppWidgetOptions(widgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if (minHeight <= 0) return 3
        // Header ~40dp, each row ~44dp.
        return ((minHeight - 40) / 44).coerceIn(1, ROWS.size)
    }

    private fun daysText(context: Context, days: Int): String = when {
        days < 0 -> context.resources.getQuantityString(R.plurals.widget_days_overdue, -days, -days)
        days == 0 -> context.getString(R.string.widget_today)
        days == 1 -> context.getString(R.string.widget_tomorrow)
        else -> context.resources.getQuantityString(R.plurals.widget_days_left, days, days)
    }

    // Same thresholds as AppTheme.statusColor in the app.
    private fun statusColor(days: Int): Int = when {
        days < 0 -> R.color.widget_danger
        days <= 30 -> R.color.widget_warning
        else -> R.color.widget_success
    }

    private class Row(val container: Int, val title: Int, val subtitle: Int, val days: Int)

    companion object {
        const val DATA_KEY = "upcoming_dates"

        private val ROWS = listOf(
            Row(R.id.widget_row_0, R.id.widget_row_0_title, R.id.widget_row_0_subtitle, R.id.widget_row_0_days),
            Row(R.id.widget_row_1, R.id.widget_row_1_title, R.id.widget_row_1_subtitle, R.id.widget_row_1_days),
            Row(R.id.widget_row_2, R.id.widget_row_2_title, R.id.widget_row_2_subtitle, R.id.widget_row_2_days),
            Row(R.id.widget_row_3, R.id.widget_row_3_title, R.id.widget_row_3_subtitle, R.id.widget_row_3_days),
        )

        private val UTC: TimeZone = TimeZone.getTimeZone("UTC")

        /** A calendar date at midnight UTC, so day differences ignore DST. */
        private fun day(year: Int, month0: Int, dayOfMonth: Int): Calendar =
            Calendar.getInstance(UTC).apply {
                clear()
                set(year, month0, dayOfMonth)
            }

        private fun today(): Calendar {
            val now = Calendar.getInstance()
            return day(now.get(Calendar.YEAR), now.get(Calendar.MONTH), now.get(Calendar.DAY_OF_MONTH))
        }

        private fun parseDay(s: String): Calendar? {
            val parts = s.split("-")
            if (parts.size != 3) return null
            val y = parts[0].toIntOrNull() ?: return null
            val m = parts[1].toIntOrNull() ?: return null
            val d = parts[2].toIntOrNull() ?: return null
            return day(y, m - 1, d)
        }

        private fun daysBetween(from: Calendar, to: Calendar): Int =
            ((to.timeInMillis - from.timeInMillis) / 86_400_000L).toInt()
    }
}
