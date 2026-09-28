package ve.cuantoes.cuantoes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BcvWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_bcv)
            val hasSnapshot = widgetData.getInt(KEY_SNAPSHOT_VERSION, 0) == SNAPSHOT_VERSION
            val usd = if (hasSnapshot) widgetData.getString(KEY_USD, null) else null
            val eur = if (hasSnapshot) widgetData.getString(KEY_EUR, null) else null
            val effectiveDate = if (hasSnapshot) widgetData.getString(KEY_EFFECTIVE_DATE, null) else null
            val validatedAt = if (hasSnapshot) widgetData.getString(KEY_VALIDATED_AT, null) else null
            val source = if (hasSnapshot) widgetData.getString(KEY_SOURCE, null) else null
            val status = if (hasSnapshot) widgetData.getString(KEY_STATUS, null) else null

            views.setTextViewText(R.id.widget_usd_rate, usd?.let { "Bs. $it" } ?: "—")
            views.setTextViewText(R.id.widget_eur_rate, eur?.let { "Bs. $it" } ?: "—")
            views.setTextViewText(
                R.id.widget_effective_date,
                effectiveDate?.let { "Fecha efectiva · $it" } ?: "Abre Cuantoes para cargar tasas",
            )
            views.setTextViewText(R.id.widget_source, source?.let { "Fuente · $it" } ?: "BCV · USD / EUR")
            views.setTextViewText(R.id.widget_status, status ?: validatedAt ?: "Toca para consultar")
            views.setContentDescription(
                R.id.widget_root,
                "Tasas BCV. Dólar: ${usd ?: "sin dato"} bolívares. Euro: ${eur ?: "sin dato"} bolívares. " +
                    (effectiveDate ?: "Sin fecha efectiva"),
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchApp(context, widgetId))
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launchApp(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val KEY_SNAPSHOT_VERSION = "widget_snapshot_version"
        const val SNAPSHOT_VERSION = 1
        const val KEY_USD = "widget_usd_rate"
        const val KEY_EUR = "widget_eur_rate"
        const val KEY_EFFECTIVE_DATE = "widget_effective_date"
        const val KEY_VALIDATED_AT = "widget_validated_at"
        const val KEY_SOURCE = "widget_source"
        const val KEY_STATUS = "widget_status"
    }
}

class BcvCompactWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_bcv_compact)
            val currency = widgetData.getString(KEY_COMPACT_CURRENCY, "USD")
                ?.takeIf { it == "EUR" } ?: "USD"
            val hasSnapshot = widgetData.getInt(KEY_SNAPSHOT_VERSION, 0) == SNAPSHOT_VERSION
            val rate = if (hasSnapshot) {
                widgetData.getString(if (currency == "EUR") KEY_EUR else KEY_USD, null)
            } else null
            val effectiveDate = if (hasSnapshot) widgetData.getString(KEY_EFFECTIVE_DATE, null) else null
            val source = if (hasSnapshot) widgetData.getString(KEY_SOURCE, "BCV") else null

            views.setTextViewText(R.id.widget_compact_currency, "$currency · BCV")
            views.setTextViewText(
                R.id.widget_compact_rate,
                rate?.let { "Bs. $it" } ?: "Sin dato · abre Cuantoes",
            )
            views.setTextViewText(
                R.id.widget_compact_footer,
                listOfNotNull(source, effectiveDate).joinToString(" · "),
            )
            views.setContentDescription(
                R.id.widget_compact_root,
                "$currency BCV: ${rate ?: "sin dato"} bolívares. Toca para abrir Cuantoes.",
            )

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId + REQUEST_CODE_OFFSET,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_compact_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private companion object {
        const val KEY_SNAPSHOT_VERSION = "widget_snapshot_version"
        const val SNAPSHOT_VERSION = 1
        const val KEY_USD = "widget_usd_rate"
        const val KEY_EUR = "widget_eur_rate"
        const val KEY_EFFECTIVE_DATE = "widget_effective_date"
        const val KEY_SOURCE = "widget_source"
        const val KEY_COMPACT_CURRENCY = "widget_compact_currency"
        const val REQUEST_CODE_OFFSET = 100_000
    }
}
