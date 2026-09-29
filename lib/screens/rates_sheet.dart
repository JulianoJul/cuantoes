import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/resultado_tasa.dart';
import '../viewmodels/conversor_viewmodel.dart';
import 'rate_date_picker.dart';

class RatesSheet extends StatelessWidget {
  final ConversorViewmodel viewModel;

  const RatesSheet({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        final formatoTasa = NumberFormat('#,##0.00', 'es_VE');
        final formatoFecha = DateFormat('dd/MM/yyyy', 'es_VE');
        final alturaMaxima = MediaQuery.sizeOf(context).height * 0.9;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: alturaMaxima),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tasas y fecha',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (vm.moneda == 'USDT')
                    _buildUsdt(context, formatoTasa, formatoFecha)
                  else
                    _buildOficial(context, formatoTasa, formatoFecha),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: vm.moneda == 'USDT'
                        ? vm.refrescarUsdt
                        : vm.refrescarTasa,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      vm.moneda == 'USDT'
                          ? 'Actualizar referencia P2P'
                          : 'Actualizar tasas BCV',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOficial(
    BuildContext context,
    NumberFormat formatoTasa,
    DateFormat formatoFecha,
  ) {
    final vm = viewModel;
    final tasa = vm.tasa;
    final solicitada = vm.fechaSeleccionada;
    final aplicada = vm.fechaEfectivaAplicada ?? tasa?.fechaEfectiva;
    final resultado = vm.resultadoTasa;
    final esProxima = vm.esFechaProximaSeleccionada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Consultar fecha',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Elegir fecha histórica',
                  onPressed: () => mostrarCalendarioTasa(context, vm),
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
          ),
        ),
        if (solicitada != null) ...[
          const SizedBox(height: 8),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      aplicada == null
                          ? '${esProxima ? 'Próxima publicada' : 'Solicitada'} ${formatoFecha.format(solicitada)} · sin tasa aplicada'
                          : '${esProxima ? 'Próxima publicada' : 'Solicitada'} ${formatoFecha.format(solicitada)}\nAplicada ${formatoFecha.format(aplicada)}',
                    ),
                  ),
                  TextButton(
                    onPressed: vm.volverAHoy,
                    child: const Text('Actual'),
                  ),
                ],
              ),
            ),
          ),
        ] else if (vm.tasaSiguienteDisponible &&
            vm.fechaTasaSiguiente != null) ...[
          const SizedBox(height: 8),
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Próxima tasa publicada'),
              subtitle: Text(formatoFecha.format(vm.fechaTasaSiguiente!)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => vm.seleccionarFecha(vm.fechaTasaSiguiente!),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (tasa == null)
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                vm.estado == EstadoTasa.cargando
                    ? 'Cargando tasas…'
                    : vm.error.isNotEmpty
                    ? 'No hay una tasa disponible para este contexto.'
                    : 'No hay tasas disponibles.',
              ),
            ),
          )
        else
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    esProxima ? 'Próxima tasa BCV' : 'Tasa oficial BCV',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _filaTasa(context, formatoTasa, 'USD', tasa.usd),
                  const Divider(height: 24),
                  _filaTasa(context, formatoTasa, 'EUR', tasa.eur),
                  const SizedBox(height: 16),
                  Text('Fuente · ${_nombreFuente(tasa.origen)}'),
                  if (aplicada != null)
                    Text('Fecha efectiva · ${formatoFecha.format(aplicada)}'),
                  if (resultado != null) ...[
                    const SizedBox(height: 8),
                    Text(_estadoValidacion(resultado)),
                    if (resultado.ultimaValidacionExitosaUtc != null)
                      Text(
                        'Última validación · ${_fechaHoraVenezuela(resultado.ultimaValidacionExitosaUtc!)}',
                      ),
                    if (resultado.errorActualizacion != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No se pudo actualizar. Se conserva la tasa disponible.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                  if (vm.avisoActualizacion.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(vm.avisoActualizacion),
                  ],
                ],
              ),
            ),
          ),
        if (vm.error.isNotEmpty && tasa != null && resultado == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No se encontró una tasa para la fecha solicitada.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (vm.moneda != 'USDT' && vm.variacion != null) ...[
          const SizedBox(height: 8),
          Text(
            'Variación de ${vm.moneda} · ${vm.variacion! >= 0 ? '+' : ''}${vm.variacion!.toStringAsFixed(2)}%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _filaTasa(
    BuildContext context,
    NumberFormat formato,
    String moneda,
    double valor,
  ) => Row(
    children: [
      Expanded(
        child: Text(moneda, style: Theme.of(context).textTheme.titleMedium),
      ),
      Flexible(
        child: Text(
          '1 = Bs. ${formato.format(valor)}',
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ],
  );

  Widget _buildUsdt(
    BuildContext context,
    NumberFormat formatoTasa,
    DateFormat formatoFecha,
  ) {
    final cotizacion = viewModel.cotizacionUsdt;
    if (cotizacion == null) {
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            viewModel.cargandoUsdt
                ? 'Cargando referencia P2P…'
                : viewModel.errorUsdt.isEmpty
                ? 'No hay una referencia USDT disponible.'
                : 'No se pudo actualizar la referencia P2P.',
          ),
        ),
      );
    }

    final antiguedad = DateTime.now().toUtc().difference(
      cotizacion.obtenidaEnUtc,
    );
    final consultada = antiguedad.inMinutes < 1
        ? 'hace menos de 1 min'
        : antiguedad.inHours < 1
        ? 'hace ${antiguedad.inMinutes} min'
        : 'hace ${antiguedad.inHours} h';

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Referencia P2P',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '1 USDT = Bs. ${formatoTasa.format(cotizacion.valor)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Proveedor · ${cotizacion.origen}'),
            Text('Promedio · ${formatoFecha.format(cotizacion.fechaEfectiva)}'),
            Text('Consultada · $consultada'),
          ],
        ),
      ),
    );
  }

  String _estadoValidacion(ResultadoTasa resultado) {
    if (resultado.frescura == EstadoFrescuraTasa.antigua) {
      return 'Dato antiguo · verifica antes de usar';
    }
    if (resultado.vieneDeCache) return 'Tasa guardada en este dispositivo';
    return 'Tasa recibida por internet';
  }

  String _nombreFuente(String fuente) => switch (fuente) {
    'dolarapi' => 'DolarAPI',
    'bcv_today' => 'BCV Today',
    'chitty_bcv' => 'Chitty BCV',
    _ => fuente,
  };

  String _fechaHoraVenezuela(DateTime fechaUtc) {
    final venezuela = fechaUtc.toUtc().subtract(const Duration(hours: 4));
    return DateFormat('dd/MM/yyyy HH:mm', 'es_VE').format(venezuela);
  }
}
