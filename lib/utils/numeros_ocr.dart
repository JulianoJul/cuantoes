class NumeroDetectado {
  final String texto;
  final double valor;
  final int inicio;
  final int fin;
  final String? monedaSugerida;
  final bool separadorAmbiguo;

  const NumeroDetectado({
    required this.texto,
    required this.valor,
    this.inicio = 0,
    this.fin = 0,
    this.monedaSugerida,
    this.separadorAmbiguo = false,
  });
}

// La separación por espacios es intencional: "10 20" son dos candidatos,
// nunca una sola cantidad 1020.
final _tokenNumerico = RegExp(r'(?<![0-9.,])[-+]?\d+(?:[.,]\d+)*(?![0-9.,])');

/// Formatea un monto confirmado con dos decimales y separador venezolano.
String formatearMonto(double valor) =>
    valor.toStringAsFixed(2).replaceAll('.', ',');

/// Extrae apariciones monetarias válidas en orden de lectura.
/// No elimina candidatos con el mismo valor: pueden estar en lugares distintos.
List<NumeroDetectado> extraerNumeros(String texto) {
  final resultado = <NumeroDetectado>[];
  for (final match in _tokenNumerico.allMatches(texto)) {
    final token = match.group(0)!;
    final valor = parsearNumero(token);
    if (valor == null || !valor.isFinite || valor <= 0) continue;
    resultado.add(
      NumeroDetectado(
        texto: token,
        valor: valor,
        inicio: match.start,
        fin: match.end,
        monedaSugerida: _monedaCercana(texto, match.start, match.end),
        separadorAmbiguo: _separadorEsAmbiguo(token),
      ),
    );
  }
  return resultado;
}

/// Parsea formatos venezolanos e ingleses, rechazando agrupaciones inválidas.
/// Ejemplos: `1.234,56`, `1,234.56`, `848,5458`, `10.50` y `0,125`.
double? parsearNumero(String token) {
  var valor = token.trim();
  if (valor.isEmpty || valor.startsWith('-')) return null;
  if (valor.startsWith('+')) valor = valor.substring(1);
  if (valor.isEmpty || !RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(valor)) {
    return null;
  }

  final tieneComa = valor.contains(',');
  final tienePunto = valor.contains('.');
  if (tieneComa && tienePunto) {
    final separadorDecimal = valor.lastIndexOf(',') > valor.lastIndexOf('.')
        ? ','
        : '.';
    final separadorGrupo = separadorDecimal == ',' ? '.' : ',';
    final partes = valor.split(separadorDecimal);
    if (partes.length != 2 ||
        !_esAgrupacionMiles(partes.first, separadorGrupo)) {
      return null;
    }
    final decimales = partes.last;
    if (decimales.isEmpty || decimales.length > 4) return null;
    final normalizado =
        '${partes.first.replaceAll(separadorGrupo, '')}.$decimales';
    return double.tryParse(normalizado);
  }

  final separador = tieneComa ? ',' : (tienePunto ? '.' : null);
  if (separador == null) return double.tryParse(valor);

  final partes = valor.split(separador);
  if (partes.length > 2) {
    if (!_esAgrupacionMiles(valor, separador)) return null;
    return double.tryParse(valor.replaceAll(separador, ''));
  }

  final entero = partes[0];
  final decimales = partes[1];
  if (entero.isEmpty || decimales.isEmpty || decimales.length > 4) return null;

  // `1.234` suele ser miles; `0,125` es un decimal plausible. Los candidatos
  // con tres cifras decimales se marcan para revisión en la interfaz.
  if (decimales.length == 3 && entero != '0' && entero.length <= 3) {
    return double.tryParse('$entero$decimales');
  }
  return double.tryParse('$entero.$decimales');
}

bool _esAgrupacionMiles(String texto, String separador) {
  final expresion = r'^\d{1,3}(?:' + RegExp.escape(separador) + r'\d{3})+$';
  return RegExp(expresion).hasMatch(texto);
}

bool _separadorEsAmbiguo(String token) {
  final tieneUnSoloSeparador =
      ','.allMatches(token).length + '.'.allMatches(token).length == 1;
  if (!tieneUnSoloSeparador) return false;
  final partes = token.split(RegExp('[,.]'));
  return partes.length == 2 &&
      partes.last.length == 3 &&
      partes.first != '0' &&
      partes.first.length <= 3;
}

String? _monedaCercana(String texto, int inicio, int fin) {
  const ventana = 16;
  final antes = texto.substring(
    inicio > ventana ? inicio - ventana : 0,
    inicio,
  );
  final despues = texto.substring(
    fin,
    fin + ventana < texto.length ? fin + ventana : texto.length,
  );
  final etiquetaAntes = RegExp(
    r'(USDT|US\$|USD|EUR|€|VES|Bs\.?|Bs|Bolívares)\s*[:=]?\s*$',
    caseSensitive: false,
  ).firstMatch(antes);
  final etiquetaDespues = RegExp(
    r'^\s*(USDT|US\$|USD|EUR|€|VES|Bs\.?|Bs|Bolívares)\b',
    caseSensitive: false,
  ).firstMatch(despues);
  final etiqueta = etiquetaAntes?.group(1) ?? etiquetaDespues?.group(1);
  if (etiqueta == null) return null;
  final normalizada = etiqueta.toUpperCase();
  if (normalizada.startsWith('BS') || normalizada == 'BOLÍVARES') return 'VES';
  if (normalizada == r'US$') return 'USD';
  if (normalizada == '€') return 'EUR';
  return normalizada;
}
