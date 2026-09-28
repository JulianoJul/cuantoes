class PuntoOcr {
  final double x;
  final double y;

  const PuntoOcr(this.x, this.y);
}

class RegionOcr {
  final String id;
  final String texto;
  final int indice;
  final int bloque;
  final int linea;
  final int elemento;
  final double izquierda;
  final double arriba;
  final double ancho;
  final double alto;
  final List<PuntoOcr> poligono;
  final double? confianza;
  final String? monedaSugerida;

  RegionOcr({
    required this.id,
    required this.texto,
    required this.indice,
    required this.bloque,
    required this.linea,
    required this.elemento,
    required this.izquierda,
    required this.arriba,
    required this.ancho,
    required this.alto,
    required List<PuntoOcr> poligono,
    this.confianza,
    this.monedaSugerida,
  }) : poligono = List.unmodifiable(poligono);
}

class DocumentoOcr {
  final String id;
  final String rutaImagen;
  final int anchoImagen;
  final int altoImagen;
  final String textoCompleto;
  final List<RegionOcr> regiones;

  DocumentoOcr({
    required this.id,
    required this.rutaImagen,
    required this.anchoImagen,
    required this.altoImagen,
    required this.textoCompleto,
    required List<RegionOcr> regiones,
  }) : regiones = List.unmodifiable(regiones);
}

class TransferenciaOcr {
  final String monto;
  final String moneda;

  const TransferenciaOcr({required this.monto, required this.moneda});
}
