import '../../core/sync/sync_session.dart';
import '../../core/sync/sync_stage.dart';
import '../../services/supabase/supabase_cache_service.dart';

class LoadDatabaseCacheStage implements SyncStage {
  final SupabaseCacheService _service = SupabaseCacheService();

  @override
  String get name => "Cargar Caché de Base de Datos";

  @override
  Future<void> execute(SyncSession session) async {
    session.cambiarEstado("Cargando información desde Supabase");

    final context = session.context;

    context.productosDB.clear();
    context.clientesDB.clear();
    context.vendedoresDB.clear();
    context.familiasDB.clear();
    context.clasesDB.clear();
    context.coloresDB.clear();
    context.presentacionesDB.clear();
    context.almacenesDB.clear();

    context.productosDB.addAll(await _service.cargarProductos());
    context.clientesDB.addAll(await _service.cargarClientes());
    context.vendedoresDB.addAll(await _service.cargarVendedores());
    context.familiasDB.addAll(await _service.cargarFamilias());
    context.clasesDB.addAll(await _service.cargarClases());
    context.coloresDB.addAll(await _service.cargarColores());
    context.presentacionesDB.addAll(await _service.cargarPresentaciones());
    context.almacenesDB.addAll(await _service.cargarAlmacenes());

    session.log("Caché de Supabase cargada correctamente.");
  }
}