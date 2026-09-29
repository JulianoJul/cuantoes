import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../models/resultado_tasa.dart';
import '../models/widget_snapshot.dart';

class HomeWidgetService {
  static const providerName = 've.cuantoes.cuantoes.BcvWidgetProvider';
  static const compactProviderName =
      've.cuantoes.cuantoes.BcvCompactWidgetProvider';
  static const presetAmountsKey = 'widget_converter_presets';

  Future<void> publicar(ResultadoTasa resultado) async {
    if (!Platform.isAndroid) return;
    final snapshot = WidgetSnapshot.fromResultadoTasa(resultado);
    final guardado = await HomeWidget.saveWidgetData<String>(
      WidgetSnapshot.keyPayload,
      jsonEncode(snapshot.toJson()),
    );
    if (guardado != true) {
      throw StateError('No se pudo guardar el snapshot de los widgets');
    }
    await _actualizarProveedores();
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

  Future<void> actualizarValoresPredefinidos(List<int> valores) async {
    if (!Platform.isAndroid ||
        valores.length != 4 ||
        valores.toSet().length != 4 ||
        valores.any((valor) => valor <= 0 || valor > 999999)) {
      return;
    }
    try {
      await HomeWidget.saveWidgetData<String>(
        presetAmountsKey,
        jsonEncode(valores),
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
    } catch (_) {
      // La configuración se conserva aunque no haya un widget instalado.
    }
  }

  Future<void> _actualizarProveedores() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
    await HomeWidget.updateWidget(qualifiedAndroidName: compactProviderName);
  }
}
