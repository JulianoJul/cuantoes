import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/conversor_viewmodel.dart';

class ConversorScreen extends StatelessWidget {
  const ConversorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConversorViewmodel()..cargarTasa(),
      child: const _ConversorBody(),
    );
  }
}

class _ConversorBody extends StatelessWidget {
  const _ConversorBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConversorViewmodel>();
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 12),
              _buildSelectorMoneda(context, vm),
              const SizedBox(height: 8),
              _buildSelectorFecha(context, vm, dateFormatter),
              const SizedBox(height: 20),
              _buildEntrada(vm),
              const SizedBox(height: 20),
              _buildSwapButton(vm),
              const SizedBox(height: 20),
              _buildResultado(vm, formatter),
              const SizedBox(height: 16),
              _buildEstadoBcv(context, vm, formatter),
              const Spacer(),
              _buildOrigen(vm),
              _buildBotonRecargar(vm),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(Icons.currency_exchange, size: 40),
        SizedBox(height: 6),
        Text(
          'Tasa BCV',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSelectorMoneda(BuildContext context, ConversorViewmodel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chipMoneda(context, vm, 'USD'),
        const SizedBox(width: 8),
        _chipMoneda(context, vm, 'EUR'),
        const SizedBox(width: 8),
        _chipMoneda(context, vm, 'USDT'),
      ],
    );
  }

  Widget _chipMoneda(
      BuildContext context, ConversorViewmodel vm, String moneda) {
    final selected = vm.moneda == moneda;
    return ChoiceChip(
      label: Text(moneda),
      selected: selected,
      onSelected: (_) => vm.setMoneda(moneda),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildSelectorFecha(
      BuildContext context, ConversorViewmodel vm, DateFormat formatter) {
    if (vm.moneda == 'USDT') return const SizedBox.shrink();

    final hoy = DateTime.now();
    final manana = hoy.add(const Duration(days: 1));

    String label;
    if (vm.fechaSeleccionada != null) {
      final sel = vm.fechaSeleccionada!;
      final esHoy =
          sel.year == hoy.year && sel.month == hoy.month && sel.day == hoy.day;
      final esManana = sel.year == manana.year &&
          sel.month == manana.month &&
          sel.day == manana.day;
      if (esHoy) {
        label = 'Hoy - ${formatter.format(sel)}';
      } else if (esManana) {
        label = 'Mañana - ${formatter.format(sel)}';
      } else {
        label = formatter.format(sel);
      }
    } else {
      final ef = vm.tasa?.fechaEfectiva;
      if (ef != null &&
          ef.year == manana.year &&
          ef.month == manana.month &&
          ef.day == manana.day) {
        label = 'Mañana';
      } else {
        label = 'Hoy';
      }
    }

    final esFechaDistintaAHoy = vm.fechaSeleccionada != null &&
        (vm.fechaSeleccionada!.day != hoy.day ||
            vm.fechaSeleccionada!.month != hoy.month ||
            vm.fechaSeleccionada!.year != hoy.year);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (esFechaDistintaAHoy)
          IconButton(
            onPressed: () => vm.volverAHoy(),
            icon: const Icon(Icons.today, size: 20),
            tooltip: 'Volver a hoy',
          ),
        TextButton.icon(
          onPressed: () => _abrirCalendario(context, vm),
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(label),
        ),
      ],
    );
  }

  Future<void> _abrirCalendario(
      BuildContext context, ConversorViewmodel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.fechaSeleccionada ?? vm.tasa?.fechaEfectiva ?? DateTime.now(),
      firstDate: DateTime(2016, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      selectableDayPredicate: (day) =>
          day.weekday != DateTime.saturday && day.weekday != DateTime.sunday,
      locale: const Locale('es'),
    );
    if (picked != null) {
      await vm.seleccionarFecha(picked);
    }
  }

  Widget _buildEntrada(ConversorViewmodel vm) {
    return IgnorePointer(
      ignoring: vm.entradaBloqueada,
      child: Opacity(
        opacity: vm.entradaBloqueada ? 0.5 : 1,
        child: TextField(
          controller: vm.entradaController,
          onChanged: vm.setEntrada,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              final text = newValue.text;
              if (text.isEmpty) return newValue;
              if (RegExp(r'^\d*([,.]\d{0,2})?$').hasMatch(text)) {
                return newValue;
              }
              return oldValue;
            }),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: vm.cargandoUsdt ? 'Cargando USDT...' : vm.labelOrigen,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapButton(ConversorViewmodel vm) {
    return IconButton.filled(
      onPressed: vm.tasa != null ? vm.toggleDireccion : null,
      icon: const Icon(Icons.swap_vert),
    );
  }

  Widget _buildResultado(ConversorViewmodel vm, NumberFormat formatter) {
    if (vm.resultado.isEmpty) {
      return Text(
        vm.labelDestino,
        style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          vm.esMonedaAVes ? 'Bs. ' : '${vm.moneda} ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
        Flexible(
          child: Text(
            formatter.format(double.parse(vm.resultado.replaceAll(',', '.'))),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoBcv(
      BuildContext context, ConversorViewmodel vm, NumberFormat formatter) {
    final dateFormatter = DateFormat('dd/MM/yyyy');

    switch (vm.estado) {
      case EstadoTasa.cargando:
        return const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        );
      case EstadoTasa.error:
        return SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(height: 4),
              Text(vm.error,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      case EstadoTasa.listo:
        final t = vm.tasa!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _rateLine(formatter, 'USD', t.usd),
              const SizedBox(height: 4),
              _rateLine(formatter, 'EUR', t.eur),
              if (t.usdt > 0) ...[
                const SizedBox(height: 4),
                _rateLine(formatter, 'USDT', t.usdt),
              ],
              const SizedBox(height: 6),
              Text(
                dateFormatter.format(t.fechaEfectiva),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        );
    }
  }

  Widget _rateLine(NumberFormat formatter, String moneda, double valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(moneda,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 4),
        Text('1 = Bs. ${formatter.format(valor)}'),
      ],
    );
  }

  Widget _buildOrigen(ConversorViewmodel vm) {
    final origen = vm.tasa?.origen ?? '';
    if (origen.isEmpty) return const SizedBox.shrink();

    final icono = origen == 'scraping' ? Icons.language : Icons.cloud;
    final etiqueta = origen == 'scraping' ? 'BCV directo' : 'API';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            'Datos desde $etiqueta',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonRecargar(ConversorViewmodel vm) {
    return TextButton.icon(
      onPressed: () => vm.refrescarTasa(),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Actualizar tasa'),
    );
  }
}
