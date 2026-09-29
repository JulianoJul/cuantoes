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
  final solicitada =
      viewModel.fechaSeleccionada ?? viewModel.tasa?.fechaEfectiva ?? hoy;
  final inicial = _limitarFecha(solicitada, primera, maxima);
  final elegida = await showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: primera,
    lastDate: maxima,
    locale: const Locale('es'),
    helpText: 'Consultar tasa BCV',
  );
  if (elegida != null) await viewModel.seleccionarFecha(elegida);
}

DateTime _limitarFecha(DateTime fecha, DateTime primera, DateTime maxima) {
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  if (dia.isBefore(primera)) return primera;
  if (dia.isAfter(maxima)) return maxima;
  return dia;
}
