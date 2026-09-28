import '../models/tasa_bcv.dart';
import '../models/cotizacion_usdt.dart';
import '../utils/feriados_ve.dart';

/// Fuente de datos compatible con la tasa oficial del BCV.
///
/// Los proveedores no conocen la caché ni la UI. El repositorio los consulta
/// en orden y decide cuándo debe usar el siguiente proveedor.
abstract class BcvProvider {
  String get nombre;

  Future<TasaBcv> obtenerTasa();

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha);

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite);

  Future<TasaBcv?> obtenerTasaSiguiente() async => null;

  /// No todos los proveedores ofrecen USDT. El repositorio prueba el
  /// siguiente proveedor cuando este método retorna null.
  Future<double?> obtenerUsdt() async => null;

  Future<CotizacionUsdt?> obtenerCotizacionUsdt() async {
    final valor = await obtenerUsdt();
    if (valor == null || !valor.isFinite || valor <= 0) return null;
    final ahora = DateTime.now().toUtc();
    return CotizacionUsdt(
      valor: valor,
      fechaEfectiva: fechaEfectivaActual(),
      obtenidaEnUtc: ahora,
      origen: nombre,
    );
  }
}
