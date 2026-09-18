class NumeroDetectado {
  final String texto;
  final double valor;

  const NumeroDetectado({required this.texto, required this.valor});
}

final _tokenNumerico = RegExp(r'\d[\d.,]*\d|\d');

/// Extrae los números de un texto OCR, sin repetidos y en orden de aparición.
List<NumeroDetectado> extraerNumeros(String texto) {
  final vistos = <double>{};
  final resultado = <NumeroDetectado>[];

  for (final match in _tokenNumerico.allMatches(texto)) {
    final token = match.group(0)!;
    final valor = parsearNumero(token);
    if (valor == null || valor <= 0) continue;
    if (!vistos.add(valor)) continue;
    resultado.add(NumeroDetectado(texto: token, valor: valor));
  }

  return resultado;
}

/// Parsea un token numérico en formato venezolano o inglés:
/// `1.234,56` → 1234.56, `848,5458` → 848.5458, `10.50` → 10.5.
double? parsearNumero(String token) {
  var t = token.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
  if (t.isEmpty) return null;

  final ultimaComa = t.lastIndexOf(',');
  final ultimoPunto = t.lastIndexOf('.');

  if (ultimaComa >= 0 && ultimoPunto >= 0) {
    if (ultimaComa > ultimoPunto) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else if (ultimaComa >= 0) {
    t = _resolverSeparadorUnico(t, ',');
  } else if (ultimoPunto >= 0) {
    t = _resolverSeparadorUnico(t, '.');
  }

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
  return double.tryParse(t);
}

String _resolverSeparadorUnico(String token, String separador) {
  final partes = token.split(separador);
  if (partes.length == 2) {
    final decimales = partes[1].length;
    // Con 3 dígitos exactos se asume separador de miles ("1.234" = 1234).
    if (decimales <= 4 && decimales != 3) {
      return '${partes[0]}.${partes[1]}';
    }
  }
  return partes.join();
}
