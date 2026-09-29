import 'package:flutter/material.dart';

import '../utils/feriados_ve.dart';
import '../viewmodels/conversor_viewmodel.dart';

Future<void> mostrarCalendarioTasa(
  BuildContext context,
  ConversorViewmodel viewModel,
) async {
  final ahora = ahoraVenezuela();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final primera = DateTime(2016, 1, 1);
  final maxima = viewModel.fechaMaximaSeleccionable;
  final siguiente = viewModel.fechaTasaSiguiente;
  final solicitada =
      viewModel.fechaSeleccionada ?? viewModel.tasa?.fechaEfectiva ?? hoy;
  final limitada = _limitarFecha(solicitada, primera, maxima);
  final inicial = esFechaDisponibleTasa(limitada, hoy, siguiente)
      ? limitada
      : hoy;
  final elegida = await showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: primera,
    lastDate: maxima,
    selectableDayPredicate: (dia) => esFechaDisponibleTasa(dia, hoy, siguiente),
    locale: const Locale('es'),
    helpText: 'Consultar tasa BCV',
  );
  if (elegida != null) await viewModel.seleccionarFecha(elegida);
}

/// El pasado admite la última tasa aplicable; en el futuro solo se permite
/// consultar un día cuya tasa ya fue publicada.
bool esFechaDisponibleTasa(DateTime fecha, DateTime hoy, DateTime? siguiente) {
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final actual = DateTime(hoy.year, hoy.month, hoy.day);
  return !dia.isAfter(actual) ||
      (siguiente != null &&
          dia == DateTime(siguiente.year, siguiente.month, siguiente.day));
}

DateTime _limitarFecha(DateTime fecha, DateTime primera, DateTime maxima) {
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  if (dia.isBefore(primera)) return primera;
  if (dia.isAfter(maxima)) return maxima;
  return dia;
}
