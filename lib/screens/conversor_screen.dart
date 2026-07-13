import 'package:flutter/material.dart';
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
              _buildSelectorFuente(vm),
              const SizedBox(height: 8),
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
              _buildEstadoTasas(context, vm, formatter),
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
          'Tasas',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSelectorFuente(ConversorViewmodel vm) {
    return SegmentedButton<FuenteTasa>(
      segments: const [
        ButtonSegment(value: FuenteTasa.bcv, label: Text('BCV')),
        ButtonSegment(value: FuenteTasa.usdt, label: Text('Binance P2P')),
      ],
      selected: {vm.fuente},
      onSelectionChanged: (selected) => vm.setFuente(selected.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }

  Widget _buildSelectorMoneda(BuildContext context, ConversorViewmodel vm) {
    if (!vm.esBcv) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chipMoneda(context, vm, 'USD'),
        const SizedBox(width: 12),
        _chipMoneda(context, vm, 'EUR'),
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
    if (!vm.esBcv) return const SizedBox.shrink();

    final label =
        vm.esFechaHoy ? 'Hoy' : formatter.format(vm.fechaSeleccionada!);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!vm.esFechaHoy)
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
      initialDate: vm.fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2016, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) {
      await vm.seleccionarFecha(picked);
    }
  }

  Widget _buildEntrada(ConversorViewmodel vm) {
    return TextField(
      controller: vm.entradaController,
      onChanged: vm.setEntrada,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: vm.labelOrigen,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSwapButton(ConversorViewmodel vm) {
    return IconButton.filled(
      onPressed:
          (vm.tasa != null || vm.tasaUsdt != null) ? vm.toggleDireccion : null,
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

  Widget _buildEstadoTasas(
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
        return Column(
          children: [
            if (vm.tasa != null)
              _cardTasa(
                context,
                label: 'BCV',
                contenido:
                    'USD 1 = Bs. ${formatter.format(vm.tasa!.usd)}  ·  EUR 1 = Bs. ${formatter.format(vm.tasa!.eur)}',
                fecha: dateFormatter.format(vm.tasa!.fecha),
                selected: vm.esBcv,
              ),
            if (vm.tasaUsdt != null) ...[
              const SizedBox(height: 8),
              _cardTasa(
                context,
                label: 'Binance P2P',
                contenido:
                    'USDT 1 = Bs. ${formatter.format(vm.tasaUsdt!.usdt)}',
                fecha: dateFormatter.format(vm.tasaUsdt!.fecha),
                selected: !vm.esBcv,
              ),
            ],
          ],
        );
    }
  }

  Widget _cardTasa(BuildContext context,
      {required String label,
      required String contenido,
      required String fecha,
      required bool selected}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(
                color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contenido,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500)),
                Text(fecha,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
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
      onPressed: () => vm.cargarTasa(),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Actualizar tasas'),
    );
  }
}
