package ve.cuantoes.cuantoes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

private data class NativeWidgetSnapshot(
    val usd: String,
    val eur: String,
    val usdValue: Double,
    val eurValue: Double,
    val effectiveDate: String,
    val validatedAt: String,
    val source: String,
    val status: String,
    val validatedAtUtc: String?,
)

private object NativeWidgetSnapshotReader {
    private const val KEY_PAYLOAD = "widget_snapshot_payload"
    private const val KEY_VERSION = "widget_snapshot_version"
    private const val VERSION = 3
    private const val PREVIOUS_VERSION = 2

    // Compatibilidad con los valores publicados antes del payload JSON.
    private const val LEGACY_VERSION = 1
    private const val KEY_USD = "widget_usd_rate"
    private const val KEY_EUR = "widget_eur_rate"
    private const val KEY_EFFECTIVE_DATE = "widget_effective_date"
    private const val KEY_VALIDATED_AT = "widget_validated_at"
    private const val KEY_SOURCE = "widget_source"
    private const val KEY_STATUS = "widget_status"

    fun read(data: SharedPreferences): NativeWidgetSnapshot? {
        val payload = stringPreference(data, KEY_PAYLOAD)
        if (!payload.isNullOrBlank()) {
            val json = runCatching { JSONObject(payload) }.getOrNull()
            val version = json?.optInt("version", 0)
            if (json != null && (version == VERSION || version == PREVIOUS_VERSION)) {
                val usd = jsonString(json, "usd")
                val eur = jsonString(json, "eur")
                val usdValue = jsonRate(json, "usdValue") ?: parseLocalizedRate(usd)
                val eurValue = jsonRate(json, "eurValue") ?: parseLocalizedRate(eur)
                if (usd != null && eur != null && usdValue != null && eurValue != null) {
                    return NativeWidgetSnapshot(
                        usd = usd,
                        eur = eur,
                        usdValue = usdValue,
                        eurValue = eurValue,
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
        val usdValue = parseLocalizedRate(usd) ?: return null
        val eurValue = parseLocalizedRate(eur) ?: return null
        return NativeWidgetSnapshot(
            usd = usd,
            eur = eur,
            usdValue = usdValue,
            eurValue = eurValue,
            effectiveDate = stringPreference(data, KEY_EFFECTIVE_DATE).orEmpty(),
            validatedAt = stringPreference(data, KEY_VALIDATED_AT).orEmpty(),
            source = stringPreference(data, KEY_SOURCE).orEmpty(),
            status = stringPreference(data, KEY_STATUS).orEmpty(),
            validatedAtUtc = null,
        )
    }

    private fun jsonString(json: JSONObject, key: String): String? =
        json.optString(key, "").takeIf { it.isNotBlank() }

    private fun jsonRate(json: JSONObject, key: String): Double? =
        json.optDouble(key, Double.NaN).takeIf { it.isFinite() && it > 0 }

    private fun stringPreference(
        data: SharedPreferences,
        key: String,
    ): String? = runCatching { data.getString(key, null) }.getOrNull()

    private fun intPreference(
        data: SharedPreferences,
        key: String,
    ): Int = runCatching { data.getInt(key, 0) }.getOrDefault(0)
}

private fun parseLocalizedRate(value: String?): Double? {
    if (value.isNullOrBlank()) return null
    return value.replace(".", "").replace(',', '.').toDoubleOrNull()
        ?.takeIf { it.isFinite() && it > 0 }
}

private fun formatAmount(value: Double): String {
    val symbols = DecimalFormatSymbols(Locale.forLanguageTag("es-VE"))
    return DecimalFormat("#,##0.00", symbols).format(value)
}

private fun readPresetAmounts(data: SharedPreferences): List<Int> {
    val encoded = runCatching { data.getString(KEY_PRESET_AMOUNTS, null) }.getOrNull()
        ?: return DEFAULT_PRESET_AMOUNTS
    val values = runCatching {
        val array = JSONArray(encoded)
        List(array.length()) { index -> array.getInt(index) }
    }.getOrNull()
    return values?.takeIf {
        it.size == PRESET_BUTTON_IDS.size &&
            it.toSet().size == it.size &&
            it.all { amount -> amount in 1..MAX_PRESET_AMOUNT }
    } ?: DEFAULT_PRESET_AMOUNTS
}

private const val KEY_PRESET_AMOUNTS = "widget_converter_presets"
private const val MAX_PRESET_AMOUNT = 999_999
private val DEFAULT_PRESET_AMOUNTS = listOf(1, 10, 50, 100)
private val PRESET_BUTTON_IDS = listOf(
    R.id.widget_amount_1,
    R.id.widget_amount_10,
    R.id.widget_amount_50,
    R.id.widget_amount_100,
)

private fun launchApp(context: Context, requestCode: Int): PendingIntent {
    val intent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra("focus_amount", true)
    }
    return PendingIntent.getActivity(
        context,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

class BcvWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = NativeWidgetSnapshotReader.read(widgetData)
        appWidgetIds.forEach { widgetId ->
            renderWidget(context, appWidgetManager, widgetId, widgetData, snapshot)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action !in CONVERTER_ACTIONS) {
            super.onReceive(context, intent)
            return
        }

        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val data = context.getSharedPreferences(HOME_WIDGET_PREFERENCES, Context.MODE_PRIVATE)
        val presets = readPresetAmounts(data)
        val editor = data.edit()
        when (action) {
            ACTION_SET_AMOUNT -> {
                val amount = intent.getIntExtra(EXTRA_AMOUNT, DEFAULT_AMOUNT)
                if (amount in presets) editor.putInt(amountKey(widgetId), amount)
            }
            ACTION_TOGGLE_CURRENCY -> {
                val current = data.getString(currencyKey(widgetId), DEFAULT_CURRENCY)
                editor.putString(currencyKey(widgetId), if (current == "EUR") "USD" else "EUR")
            }
            ACTION_SWAP_DIRECTION -> {
                val current = data.getBoolean(directionKey(widgetId), true)
                editor.putBoolean(directionKey(widgetId), !current)
            }
        }
        editor.apply()
        renderWidget(
            context,
            AppWidgetManager.getInstance(context),
            widgetId,
            data,
            NativeWidgetSnapshotReader.read(data),
        )
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val data = context.getSharedPreferences(HOME_WIDGET_PREFERENCES, Context.MODE_PRIVATE)
        data.edit().apply {
            appWidgetIds.forEach { widgetId ->
                remove(amountKey(widgetId))
                remove(currencyKey(widgetId))
                remove(directionKey(widgetId))
            }
        }.apply()
        super.onDeleted(context, appWidgetIds)
    }

    private fun renderWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
        snapshot: NativeWidgetSnapshot?,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_bcv)
        val currency = data.getString(currencyKey(widgetId), DEFAULT_CURRENCY)
            ?.takeIf { it == "EUR" } ?: DEFAULT_CURRENCY
        val currencyToVes = data.getBoolean(directionKey(widgetId), true)
        val presets = readPresetAmounts(data)
        val amount = data.getInt(amountKey(widgetId), DEFAULT_AMOUNT)
            .takeIf { it in presets } ?: presets.first()
        val rate = if (currency == "EUR") snapshot?.eurValue else snapshot?.usdValue
        val currencySymbol = if (currency == "EUR") "€" else "\$"

        val sourceUnit = if (currencyToVes) currency else "Bs."
        val destinationUnit = if (currencyToVes) "Bs." else currency
        val result = rate?.let {
            if (currencyToVes) amount * it else amount / it
        }
        views.setTextViewText(
            R.id.widget_pair_button,
            if (currencyToVes) "$currency ($currencySymbol) ▾  →  VES (Bs.)"
            else "VES (Bs.)  →  $currency ($currencySymbol) ▾",
        )
        views.setTextViewText(R.id.widget_amount, "${formatAmount(amount.toDouble())} $sourceUnit")
        views.setTextViewText(
            R.id.widget_result,
            result?.let { "${formatAmount(it)} $destinationUnit" } ?: "Abre la app",
        )

        views.setOnClickPendingIntent(
            R.id.widget_pair_button,
            converterAction(context, widgetId, ACTION_TOGGLE_CURRENCY),
        )
        views.setOnClickPendingIntent(
            R.id.widget_swap_button,
            converterAction(context, widgetId, ACTION_SWAP_DIRECTION),
        )
        PRESET_BUTTON_IDS.zip(presets).forEach { (viewId, preset) ->
            views.setTextViewText(viewId, preset.toString())
            views.setOnClickPendingIntent(
                viewId,
                converterAction(context, widgetId, ACTION_SET_AMOUNT, preset),
            )
        }
        views.setOnClickPendingIntent(R.id.widget_root, launchApp(context, widgetId))
        views.setContentDescription(
            R.id.widget_root,
            if (result == null) {
                "Conversor sin tasa. Toca para abrir Cuantoes."
            } else {
                "${formatAmount(amount.toDouble())} $sourceUnit equivalen a " +
                    "${formatAmount(result)} $destinationUnit."
            },
        )
        manager.updateAppWidget(widgetId, views)
    }

    private fun converterAction(
        context: Context,
        widgetId: Int,
        action: String,
        amount: Int? = null,
    ): PendingIntent {
        val intent = Intent(context, BcvWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            if (amount != null) putExtra(EXTRA_AMOUNT, amount)
        }
        val requestCode = "$widgetId:$action:${amount ?: 0}".hashCode()
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val HOME_WIDGET_PREFERENCES = "HomeWidgetPreferences"
        const val DEFAULT_CURRENCY = "USD"
        const val DEFAULT_AMOUNT = 1
        const val EXTRA_AMOUNT = "converter_amount"
        const val ACTION_SET_AMOUNT = "ve.cuantoes.widget.SET_AMOUNT"
        const val ACTION_TOGGLE_CURRENCY = "ve.cuantoes.widget.TOGGLE_CURRENCY"
        const val ACTION_SWAP_DIRECTION = "ve.cuantoes.widget.SWAP_DIRECTION"
        val CONVERTER_ACTIONS = setOf(
            ACTION_SET_AMOUNT,
            ACTION_TOGGLE_CURRENCY,
            ACTION_SWAP_DIRECTION,
        )
        fun amountKey(widgetId: Int) = "widget_converter_amount_$widgetId"
        fun currencyKey(widgetId: Int) = "widget_converter_currency_$widgetId"
        fun directionKey(widgetId: Int) = "widget_converter_direction_$widgetId"
    }
}

class BcvCompactWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = NativeWidgetSnapshotReader.read(widgetData)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_bcv_compact)
            val currency = runCatching {
                widgetData.getString(KEY_COMPACT_CURRENCY, "USD")
            }.getOrNull()?.takeIf { it == "EUR" } ?: "USD"
            val rate = if (currency == "EUR") snapshot?.eurValue else snapshot?.usdValue
            val symbol = if (currency == "EUR") "€" else "\$"

            views.setTextViewText(R.id.widget_compact_currency, "1,00 $currency ($symbol)")
            views.setTextViewText(
                R.id.widget_compact_rate,
                rate?.let { "${formatAmount(it)} Bs." } ?: "Sin tasa",
            )
            views.setTextViewText(R.id.widget_compact_footer, "$currency → VES")
            views.setContentDescription(
                R.id.widget_compact_root,
                rate?.let { "1 $currency equivale a ${formatAmount(it)} bolívares." }
                    ?: "Conversor sin tasa. Toca para abrir Cuantoes.",
            )
            views.setOnClickPendingIntent(
                R.id.widget_compact_root,
                launchApp(context, widgetId + REQUEST_CODE_OFFSET),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private companion object {
        const val KEY_COMPACT_CURRENCY = "widget_compact_currency"
        const val REQUEST_CODE_OFFSET = 100_000
    }
}
