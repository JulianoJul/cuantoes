package ve.cuantoes.cuantoes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

private data class NativeWidgetSnapshot(
    val usd: String,
    val eur: String,
    val effectiveDate: String,
    val validatedAt: String,
    val source: String,
    val status: String,
    val validatedAtUtc: String?,
)

private object NativeWidgetSnapshotReader {
    private const val KEY_PAYLOAD = "widget_snapshot_payload"
    private const val KEY_VERSION = "widget_snapshot_version"
    private const val VERSION = 2

    // Compatibilidad con los valores publicados por la versión anterior.
    private const val LEGACY_VERSION = 1
    private const val KEY_USD = "widget_usd_rate"
    private const val KEY_EUR = "widget_eur_rate"
    private const val KEY_EFFECTIVE_DATE = "widget_effective_date"
    private const val KEY_VALIDATED_AT = "widget_validated_at"
    private const val KEY_SOURCE = "widget_source"
    private const val KEY_STATUS = "widget_status"

    fun read(data: android.content.SharedPreferences): NativeWidgetSnapshot? {
        val payload = stringPreference(data, KEY_PAYLOAD)
        if (!payload.isNullOrBlank()) {
            val json = runCatching { JSONObject(payload) }.getOrNull()
            if (json != null && json.optInt("version", 0) == VERSION) {
                val usd = jsonString(json, "usd")
                val eur = jsonString(json, "eur")
                if (usd != null && eur != null) {
                    return NativeWidgetSnapshot(
                        usd = usd,
                        eur = eur,
                        effectiveDate = jsonString(json, "effectiveDate").orEmpty(),
                        validatedAt = jsonString(json, "validatedAt").orEmpty(),
                        source = jsonString(json, "source").orEmpty(),
                        status = jsonString(json, "status").orEmpty(),
                        validatedAtUtc = jsonString(json, "validatedAtUtc"),
                    )
                }
            }
        }

        if (intPreference(data, KEY_VERSION) != LEGACY_VERSION) return null
        val usd = stringPreference(data, KEY_USD) ?: return null
        val eur = stringPreference(data, KEY_EUR) ?: return null
        return NativeWidgetSnapshot(
            usd = usd,
            eur = eur,
            effectiveDate = stringPreference(data, KEY_EFFECTIVE_DATE).orEmpty(),
            validatedAt = stringPreference(data, KEY_VALIDATED_AT).orEmpty(),
            source = stringPreference(data, KEY_SOURCE).orEmpty(),
            status = stringPreference(data, KEY_STATUS).orEmpty(),
            validatedAtUtc = null,
        )
    }

    private fun jsonString(json: JSONObject, key: String): String? =
        json.optString(key, "").takeIf { it.isNotBlank() }

    private fun stringPreference(
        data: android.content.SharedPreferences,
        key: String,
    ): String? = runCatching { data.getString(key, null) }.getOrNull()

    private fun intPreference(
        data: android.content.SharedPreferences,
        key: String,
    ): Int = runCatching { data.getInt(key, 0) }.getOrDefault(0)
}

class BcvWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        val snapshot = NativeWidgetSnapshotReader.read(widgetData)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_bcv)
            val usd = snapshot?.usd
            val eur = snapshot?.eur

            views.setTextViewText(R.id.widget_usd_rate, usd?.let { "Bs. $it" } ?: "—")
            views.setTextViewText(R.id.widget_eur_rate, eur?.let { "Bs. $it" } ?: "—")
            views.setTextViewText(
                R.id.widget_effective_date,
                snapshot?.effectiveDate?.takeIf { it.isNotBlank() }
                    ?.let { "Fecha efectiva · $it" } ?: "Abre Cuantoes para cargar tasas",
            )
            views.setTextViewText(
                R.id.widget_source,
                snapshot?.source?.takeIf { it.isNotBlank() }?.let { "Fuente · $it" }
                    ?: "BCV · USD / EUR",
            )
            views.setTextViewText(
                R.id.widget_status,
                snapshot?.status?.takeIf { it.isNotBlank() }
                    ?: snapshot?.validatedAt?.takeIf { it.isNotBlank() }
                    ?: "Toca para consultar",
            )
            val validacion = snapshot?.validatedAtUtc?.let {
                "Última validación UTC: $it. "
            }.orEmpty()
            views.setContentDescription(
                R.id.widget_root,
                "Tasas BCV. Dólar: ${usd ?: "sin dato"} bolívares. " +
                    "Euro: ${eur ?: "sin dato"} bolívares. " +
                    (snapshot?.effectiveDate ?: "Sin fecha efectiva") + ". " + validacion,
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
}

class BcvCompactWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        val snapshot = NativeWidgetSnapshotReader.read(widgetData)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_bcv_compact)
            val currency = runCatching {
                widgetData.getString(KEY_COMPACT_CURRENCY, "USD")
            }.getOrNull()?.takeIf { it == "EUR" } ?: "USD"
            val rate = if (currency == "EUR") snapshot?.eur else snapshot?.usd
            val effectiveDate = snapshot?.effectiveDate?.takeIf { it.isNotBlank() }
            val source = snapshot?.source?.takeIf { it.isNotBlank() } ?: "BCV"

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
        const val KEY_COMPACT_CURRENCY = "widget_compact_currency"
        const val REQUEST_CODE_OFFSET = 100_000
    }
}
