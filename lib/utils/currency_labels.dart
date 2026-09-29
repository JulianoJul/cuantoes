const Map<String, String> etiquetasMoneda = {
  'USD': 'USD (\$)',
  'EUR': 'EUR (€)',
  'USDT': 'USDT',
  'VES': 'VES (Bs.)',
};

const List<String> monedasConversor = ['USD', 'EUR', 'USDT'];

const Map<String, String> contextosMoneda = {
  'USD': 'BCV',
  'EUR': 'BCV',
  'USDT': 'P2P',
};

String etiquetaMoneda(String moneda) => etiquetasMoneda[moneda] ?? moneda;

String etiquetaSelectorMoneda(String moneda) {
  final contexto = contextosMoneda[moneda];
  final etiqueta = etiquetaMoneda(moneda);
  return contexto == null ? etiqueta : '$etiqueta · $contexto';
}
