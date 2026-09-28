import 'tasa_bcv.dart';

enum ModoObtencionTasa { red, cache }

enum EstadoFrescuraTasa { vigente, antigua, desconocida }

/// Metadata from the repository about how a usable official rate was obtained.
class ResultadoTasa {
  final TasaBcv tasa;
  final ModoObtencionTasa modoObtencion;
  final DateTime? ultimaValidacionExitosaUtc;
  final DateTime? ultimoIntentoUtc;
  final EstadoFrescuraTasa frescura;
  final String? errorActualizacion;

  const ResultadoTasa({
    required this.tasa,
    required this.modoObtencion,
    required this.ultimaValidacionExitosaUtc,
    required this.ultimoIntentoUtc,
    required this.frescura,
    this.errorActualizacion,
  });

  bool get vieneDeCache => modoObtencion == ModoObtencionTasa.cache;
}
