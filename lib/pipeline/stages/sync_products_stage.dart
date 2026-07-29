import '../../core/sync/sync_session.dart';
import '../../core/sync/sync_stage.dart';
import '../../services/supabase/product_service.dart';

class SyncProductsStage implements SyncStage {
  final ProductService _service = ProductService();

  @override
  String get name => "Sincronizar Productos";

  @override
  Future<void> execute(SyncSession session) async {
    session.cambiarEstado("Sincronizando productos");

    final context = session.context;

    for (final producto in context.productos.values) {
      final familiaId = context.familiasDB[producto.familia];
      final claseId = context.clasesDB[producto.clase];
      final colorId = context.coloresDB[producto.color];
      final presentacionId =
          context.presentacionesDB[producto.presentacion];

      if (familiaId == null ||
          claseId == null ||
          colorId == null ||
          presentacionId == null) {
        session.result.addError(
          "Catálogo faltante para el producto ${producto.codigo}",
        );
        continue;
      }

      if (context.productosDB.containsKey(producto.codigo)) {
        await _service.actualizarProducto(
          id: context.productosDB[producto.codigo]!,
          producto: producto,
          familiaId: familiaId,
          claseId: claseId,
          colorId: colorId,
          presentacionId: presentacionId,
        );

        session.result.productosActualizados++;
      } else {
        final id = await _service.insertarProducto(
          producto: producto,
          familiaId: familiaId,
          claseId: claseId,
          colorId: colorId,
          presentacionId: presentacionId,
        );

        context.productosDB[producto.codigo] = id;

        session.result.productosCreados++;
      }
    }

    session.log("Productos sincronizados correctamente.");
  }
}