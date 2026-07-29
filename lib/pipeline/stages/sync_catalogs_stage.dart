import '../../core/sync/sync_session.dart';
import '../../core/sync/sync_stage.dart';
import '../../services/supabase/catalog_service.dart';

class SyncCatalogsStage implements SyncStage {
  final CatalogService _catalogService = CatalogService();

  @override
  String get name => "Sincronizar Catálogos";

  @override
  Future<void> execute(SyncSession session) async {
    session.cambiarEstado("Sincronizando catálogos");

    final context = session.context;

    //==========================
    // FAMILIAS
    //==========================

    for (final familia in context.familias.values) {
      if (!context.familiasDB.containsKey(familia.nombre)) {
        final id = await _catalogService.insertarSiNoExiste(
          tabla: 'familias',
          campo: 'nombre',
          valor: familia.nombre,
        );

        context.familiasDB[familia.nombre] = id;
        session.result.familiasCreadas++;
      }
    }

    //==========================
    // CLASES
    //==========================

    for (final clase in context.clases.values) {
      if (!context.clasesDB.containsKey(clase.nombre)) {
        final id = await _catalogService.insertarSiNoExiste(
          tabla: 'clases',
          campo: 'nombre',
          valor: clase.nombre,
        );

        context.clasesDB[clase.nombre] = id;
        session.result.clasesCreadas++;
      }
    }

    //==========================
    // COLORES
    //==========================

    for (final color in context.colores.values) {
      if (!context.coloresDB.containsKey(color.nombre)) {
        final id = await _catalogService.insertarSiNoExiste(
          tabla: 'colores',
          campo: 'nombre',
          valor: color.nombre,
        );

        context.coloresDB[color.nombre] = id;
        session.result.coloresCreados++;
      }
    }

    //==========================
    // PRESENTACIONES
    //==========================

    for (final presentacion in context.presentaciones.values) {
      if (!context.presentacionesDB.containsKey(presentacion.nombre)) {
        final id = await _catalogService.insertarSiNoExiste(
          tabla: 'presentaciones',
          campo: 'nombre',
          valor: presentacion.nombre,
        );

        context.presentacionesDB[presentacion.nombre] = id;
        session.result.presentacionesCreadas++;
      }
    }

    //==========================
    // ALMACENES
    //==========================

    for (final almacen in context.almacenes.values) {
      if (!context.almacenesDB.containsKey(almacen.codigo)) {
        final id = await _catalogService.insertarAlmacen(
          codigo: almacen.codigo,
          descripcion: almacen.nombre,
        );

        context.almacenesDB[almacen.codigo] = id;
        session.result.almacenesCreados++;
      }
    }

    session.log("Catálogos sincronizados correctamente.");
  }
}