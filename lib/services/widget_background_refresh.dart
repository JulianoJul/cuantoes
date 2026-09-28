import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import 'home_widget_service.dart';
import 'tasa_repository.dart';

const _tareaActualizarWidget = 'cuantoes.widget.refresh';
const _trabajoPeriodicoWidget = 'cuantoes.widget.periodic-refresh';

class WidgetBackgroundRefresh {
  static bool _inicializado = false;

  static Future<void> inicializarYProgramar() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(widgetCallbackDispatcher);
    _inicializado = true;
    await actualizarProgramacion();
  }

  static Future<void> actualizarProgramacion() async {
    if (!Platform.isAndroid || !_inicializado) return;
    final installed = await HomeWidget.getInstalledWidgets();
    final hasCuantoesWidget = installed.any(
      (widget) =>
          widget.androidClassName == HomeWidgetService.providerName ||
          widget.androidClassName == HomeWidgetService.compactProviderName,
    );
    if (!hasCuantoesWidget) {
      await Workmanager().cancelByUniqueName(_trabajoPeriodicoWidget);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _trabajoPeriodicoWidget,
      _tareaActualizarWidget,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _tareaActualizarWidget) return true;
    try {
      final repository = TasaRepository();
      final resultado = await repository.refrescarTasaConEstado();
      await HomeWidgetService().publicar(resultado);
      return true;
    } catch (_) {
      // Preserve the last shared snapshot; WorkManager will retry on failure.
      return false;
    }
  });
}
