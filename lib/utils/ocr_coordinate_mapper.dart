import 'dart:math' as math;

import '../models/documento_ocr.dart';

class PuntoVistaOcr {
  final double x;
  final double y;

  const PuntoVistaOcr(this.x, this.y);
}

class RectVistaOcr {
  final double izquierda;
  final double arriba;
  final double ancho;
  final double alto;

  const RectVistaOcr(this.izquierda, this.arriba, this.ancho, this.alto);
}

/// Mapea entre píxeles de la imagen y el canvas BoxFit.contain del visor.
class OcrCoordinateMapper {
  final double anchoImagen;
  final double altoImagen;
  final double anchoVista;
  final double altoVista;

  const OcrCoordinateMapper({
    required this.anchoImagen,
    required this.altoImagen,
    required this.anchoVista,
    required this.altoVista,
  });

  double get escala =>
      math.min(anchoVista / anchoImagen, altoVista / altoImagen);

  double get desplazamientoX => (anchoVista - anchoImagen * escala) / 2;
  double get desplazamientoY => (altoVista - altoImagen * escala) / 2;

  RectVistaOcr mapearRectangulo(RegionOcr region) => RectVistaOcr(
    desplazamientoX + region.izquierda * escala,
    desplazamientoY + region.arriba * escala,
    region.ancho * escala,
    region.alto * escala,
  );

  PuntoOcr aCoordenadasImagen(PuntoVistaOcr punto) => PuntoOcr(
    (punto.x - desplazamientoX) / escala,
    (punto.y - desplazamientoY) / escala,
  );
}
