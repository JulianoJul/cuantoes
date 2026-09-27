import '../models/tasa_bcv.dart';

/// Fuente de datos compatible con la tasa oficial del BCV.
///
/// Los proveedores no conocen la caché ni la UI. El repositorio los consulta
/// en orden y decide cuándo debe usar el siguiente proveedor.
abstract class BcvProvider {
  String get nombre;

  Future<TasaBcv> obtenerTasa();

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha);

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite);

  /// No todos los proveedores ofrecen USDT. El repositorio prueba el
  /// siguiente proveedor cuando este método retorna null.
  Future<double?> obtenerUsdt() async => null;
}
