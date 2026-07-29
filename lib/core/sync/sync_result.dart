class SyncResult {
  bool success;

  int registrosLeidos;

  //=========================
  // PRODUCTOS
  //=========================

  int productosCreados;
  int productosActualizados;

  //=========================
  // CLIENTES
  //=========================

  int clientesCreados;
  int clientesActualizados;

  //=========================
  // VENDEDORES
  //=========================

  int vendedoresCreados;
  int vendedoresActualizados;

  //=========================
  // CATÁLOGOS
  //=========================

  int familiasCreadas;
  int coloresCreados;
  int clasesCreadas;
  int presentacionesCreadas;
  int almacenesCreados;

  //=========================
  // STOCK
  //=========================

  int lotesInsertados;
  int lotesActualizados;

  //=========================
  // RESUMEN
  //=========================

  int advertencias;
  int errores;

  Duration duracion;

  //=========================
  // DETALLE
  //=========================

  final List<String> mensajes;
  final List<String> listaAdvertencias;
  final List<String> listaErrores;

  SyncResult({
    this.success = false,
    this.registrosLeidos = 0,
    this.productosCreados = 0,
    this.productosActualizados = 0,
    this.clientesCreados = 0,
    this.clientesActualizados = 0,
    this.vendedoresCreados = 0,
    this.vendedoresActualizados = 0,
    this.familiasCreadas = 0,
    this.coloresCreados = 0,
    this.clasesCreadas = 0,
    this.presentacionesCreadas = 0,
    this.almacenesCreados = 0,
    this.lotesInsertados = 0,
    this.lotesActualizados = 0,
    this.advertencias = 0,
    this.errores = 0,
    this.duracion = Duration.zero,
    List<String>? mensajes,
    List<String>? listaAdvertencias,
    List<String>? listaErrores,
  })  : mensajes = mensajes ?? [],
        listaAdvertencias = listaAdvertencias ?? [],
        listaErrores = listaErrores ?? [];

  //=========================================================
  // MENSAJES
  //=========================================================

  void addMensaje(String mensaje) {
    mensajes.add(mensaje);
  }

  //=========================================================
  // ADVERTENCIAS
  //=========================================================

  void addAdvertencia(String mensaje) {
    advertencias++;
    listaAdvertencias.add(mensaje);
    mensajes.add("⚠ $mensaje");
  }

  //=========================================================
  // ERRORES
  //=========================================================

  void addError(String mensaje) {
    errores++;
    listaErrores.add(mensaje);
    mensajes.add("❌ $mensaje");
  }

  //=========================================================
  // FINALIZAR
  //=========================================================

  void finalizar(Duration tiempo) {
    duracion = tiempo;
    success = errores == 0;
  }

  //=========================================================
  // LIMPIAR
  //=========================================================

  void clear() {
    success = false;

    registrosLeidos = 0;

    productosCreados = 0;
    productosActualizados = 0;

    clientesCreados = 0;
    clientesActualizados = 0;

    vendedoresCreados = 0;
    vendedoresActualizados = 0;

    familiasCreadas = 0;
    coloresCreados = 0;
    clasesCreadas = 0;
    presentacionesCreadas = 0;
    almacenesCreados = 0;

    lotesInsertados = 0;
    lotesActualizados = 0;

    advertencias = 0;
    errores = 0;

    duracion = Duration.zero;

    mensajes.clear();
    listaAdvertencias.clear();
    listaErrores.clear();
  }

  @override
  String toString() {
    return '''
===============================
SINCRONIZACIÓN
===============================

Correcta: $success

Registros leídos: $registrosLeidos

Productos creados: $productosCreados
Productos actualizados: $productosActualizados

Clientes creados: $clientesCreados
Clientes actualizados: $clientesActualizados

Vendedores creados: $vendedoresCreados
Vendedores actualizados: $vendedoresActualizados

Familias creadas: $familiasCreadas
Colores creados: $coloresCreados
Clases creadas: $clasesCreadas
Presentaciones creadas: $presentacionesCreadas
Almacenes creados: $almacenesCreados

Lotes insertados: $lotesInsertados
Lotes actualizados: $lotesActualizados

Advertencias: $advertencias
Errores: $errores

Tiempo: ${duracion.inSeconds} segundos

===============================
''';
  }
}