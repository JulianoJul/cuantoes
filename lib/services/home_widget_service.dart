import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../models/resultado_tasa.dart';
import '../models/widget_snapshot.dart';

class HomeWidgetService {
  static const providerName = 've.cuantoes.cuantoes.BcvWidgetProvider';
  static const compactProviderName =
      've.cuantoes.cuantoes.BcvCompactWidgetProvider';

  Future<void> publicar(ResultadoTasa resultado) async {
    if (!Platform.isAndroid) return;
    final snapshot = WidgetSnapshot.fromResultadoTasa(resultado);
    try {
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keyUsd,
        snapshot.usd,
      );
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keyEur,
        snapshot.eur,
      );
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keyEffectiveDate,
        snapshot.effectiveDate,
      );
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keyValidatedAt,
        snapshot.validatedAt,
      );
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keySource,
        snapshot.source,
      );
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keyStatus,
        snapshot.status,
      );
      // Commit the version marker last so native receivers never accept a
      // partially written snapshot after process death.
      await HomeWidget.saveWidgetData<int>(
        WidgetSnapshot.keyVersion,
        WidgetSnapshot.version,
      );
      await _actualizarProveedores();
    } catch (_) {
      // The converter must remain usable if launcher/widget storage is absent.
    }
  }

  Future<void> actualizarMonedaCompacta(String moneda) async {
    if (!Platform.isAndroid || !const {'USD', 'EUR'}.contains(moneda)) return;
    try {
      await HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.keyCompactCurrency,
        moneda,
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: compactProviderName);
    } catch (_) {
      // Compact-widget preferences are optional on devices without a launcher widget.
    }
  }

  Future<void> _actualizarProveedores() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
    await HomeWidget.updateWidget(qualifiedAndroidName: compactProviderName);
  }
}
