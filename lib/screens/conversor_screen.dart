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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildEntrada(vm, formatter),
              const SizedBox(height: 32),
              _buildSwapButton(vm),
              const SizedBox(height: 24),
              _buildResultado(vm, formatter),
              const SizedBox(height: 20),
              _buildEstadoBcv(context, vm, formatter),
              const Spacer(),
              _buildOrigen(vm),
              _buildBotonRecargar(context, vm),
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
        Icon(Icons.currency_exchange, size: 48),
        SizedBox(height: 8),
        Text(
          'Tasa BCV',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEstadoBcv(
      BuildContext context, ConversorViewmodel vm, NumberFormat formatter) {
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
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'USD 1 = Bs. ${formatter.format(vm.tasa!.usd)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'EUR 1 = Bs. ${formatter.format(vm.tasa!.eur)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(vm.tasa!.fecha),
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

  Widget _buildSwapButton(ConversorViewmodel vm) {
    return IconButton.filled(
      onPressed: vm.tasa != null ? vm.toggleDireccion : null,
      icon: const Icon(Icons.swap_vert),
    );
  }

  Widget _buildEntrada(ConversorViewmodel vm, NumberFormat formatter) {
    return TextField(
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
          'Bs. ',
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

  Widget _buildBotonRecargar(
      BuildContext context, ConversorViewmodel vm) {
    return TextButton.icon(
      onPressed: () => vm.cargarTasa(),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Actualizar tasa'),
    );
  }
}
