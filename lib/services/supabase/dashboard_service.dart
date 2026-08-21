import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dashboard/dashboard_summary.dart';
import '../../models/dashboard/cliente_top.dart';
import '../../models/dashboard/clase_resumen.dart';
import '../../models/dashboard/producto_cliente.dart';
import '../../models/dashboard/producto_top.dart';
import '../sesion.dart';
import 'supabase_service.dart';
import '../../models/dashboard/stock_vendedor.dart';
class DashboardService {
  final SupabaseClient db = SupabaseService.client;

  // =========================================================
  // CONVERTIR VALORES A DOUBLE DE FORMA SEGURA
  // =========================================================

  double _toDouble(dynamic valor) {
    if (valor == null) {
      return 0;
    }

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(
          valor.toString().replaceAll(',', ''),
        ) ??
        0;
  }

  // =========================================================
  // OBTENER VENDEDORES QUE PUEDE VER EL USUARIO
  // =========================================================
  //
  // null:
  //     Administrador / Gerencia → todo.
  //
  // Set:
  //     Jefe → vendedores asignados mediante usuario_permisos.
  //
  // Vendedor:
  //     solamente su propio vendedor.
  //
  // IMPORTANTE:
  // NO existen nombres escritos manualmente.
  // Todo depende de usuario_permisos.
  // =========================================================

  Future<Set<String>?> _obtenerVendedoresPermitidos() async {
  // =========================================================
  // GERENCIA
  // =========================================================
  //
  // Gerencia sí puede ver TODO el stock.
  //
  // IMPORTANTE:
  // El Administrador NO entra aquí automáticamente.
  // =========================================================

  if (Sesion.rol == 'Gerencia') {
    return null;
  }

  // =========================================================
  // JEFE LIMA / JEFE PROVINCIA
  // =========================================================
  //
  // El jefe solamente puede ver los vendedores que tenga
  // habilitados en usuario_permisos.
  // =========================================================

  if (Sesion.rol == 'Jefe Lima' ||
      Sesion.rol == 'Jefe Provincia') {
    final respuesta = await db
        .from('usuario_permisos')
        .select('vendedor, ver_produccion')
        .eq(
          'usuario_jefe_id',
          Sesion.idUsuario,
        )
        .eq(
          'ver_produccion',
          true,
        );

    final vendedores = (respuesta as List)
        .map(
          (e) => e['vendedor']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '',
        )
        .where(
          (v) => v.isNotEmpty,
        )
        .toSet();

    return vendedores;
  }

  // =========================================================
  // ADMINISTRADOR CON VENDEDOR
  // =========================================================
  //
  // Si el administrador también tiene vendedor asignado,
  // se comporta como ese vendedor para el dashboard.
  //
  // Ejemplo:
  //
  // mroque
  // rol = Administrador
  // vendedor = Michael Roque
  //
  // Resultado:
  // solamente Michael Roque.
  // =========================================================

  final vendedor =
      Sesion.vendedor.trim().toLowerCase();

  if (vendedor.isNotEmpty) {
    return {vendedor};
  }

  // =========================================================
  // USUARIO SIN VENDEDOR
  // =========================================================

  return <String>{};
}

  // =========================================================
  // OBTENER STOCK COMPLETO POR PÁGINAS
  // =========================================================
  //
  // Esto evita depender del límite de filas que pueda devolver
  // Supabase en una sola consulta.
  //
  // Se cargan bloques de 1000 registros hasta terminar.
  // =========================================================

  Future<List<Map<String, dynamic>>> _obtenerTodoElStock() async {
    const int tamanoPagina = 1000;

    final List<Map<String, dynamic>> todosLosDatos = [];

    int inicio = 0;

    while (true) {
      final respuesta = await db
          .from('stock')
          .select()
          .range(
            inicio,
            inicio + tamanoPagina - 1,
          );

      final pagina = (respuesta as List)
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();

      todosLosDatos.addAll(pagina);

      // Si llegaron menos de 1000,
      // significa que ya llegamos al final.
      if (pagina.length < tamanoPagina) {
        break;
      }

      inicio += tamanoPagina;
    }

    return todosLosDatos;
  }

  // =========================================================
  // FILTRAR STOCK SEGÚN EL USUARIO
  // =========================================================

  Future<List<Map<String, dynamic>>> _obtenerStockFiltrado() async {
    final datos = await _obtenerTodoElStock();

    final vendedoresPermitidos =
        await _obtenerVendedoresPermitidos();

    // -------------------------------------------------------
    // ADMINISTRADOR / GERENCIA
    // -------------------------------------------------------
    //
    // null = puede ver todo.
    // -------------------------------------------------------

    if (vendedoresPermitidos == null) {
      return datos;
    }

    // -------------------------------------------------------
    // SIN PERMISOS
    // -------------------------------------------------------

    if (vendedoresPermitidos.isEmpty) {
      return [];
    }

    // -------------------------------------------------------
    // FILTRAR
    // -------------------------------------------------------

    return datos.where((fila) {
      final vendedor = fila['vendedor']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      return vendedoresPermitidos.contains(vendedor);
    }).toList();
  }

  // =========================================================
  // RESUMEN GENERAL
  // =========================================================

  Future<DashboardSummary> obtenerResumen() async {
    final datos = await _obtenerStockFiltrado();

    double stockTotal = 0;
    double pesoTotal = 0;
    double valorTotal = 0;

    final clientes = <String>{};

    for (final fila in datos) {
      stockTotal += _toDouble(fila['stock']);

      pesoTotal += _toDouble(fila['peso']);

      valorTotal += _toDouble(
        fila['valor_lista_precio_dolar'],
      );

      final cliente = fila['cliente'];

      if (cliente != null &&
          cliente.toString().trim().isNotEmpty) {
        clientes.add(
          cliente.toString().trim(),
        );
      }
    }

    return DashboardSummary(
      asesor: Sesion.nombre,
      stockTotal: stockTotal,
      pesoTotal: pesoTotal,
      valorStock: valorTotal,
      clientes: clientes.length,
    );
  }

 // =========================================================
// RESUMEN POR CLASE
// =========================================================
//
// CLASES VÁLIDAS:
//
// CL1
// CL2
// CL5
// CL6
//
// Primero intenta utilizar la columna "clase".
// Si la columna contiene otro dato, intenta obtener
// CL1 / CL2 / CL5 / CL6 desde la descripción.
//
// Esto evita que aparezcan familias como:
// LSOH 450/750V
// N2XOH 0.6/1kV
// THW 450/750V
// etc.
//
// =========================================================

Future<List<ClaseResumen>> obtenerResumenClases() async {
  final datos = await _obtenerStockFiltrado();

  final Map<String, double> clases = {
    'CL1': 0,
    'CL2': 0,
    'CL5': 0,
    'CL6': 0,
  };

  for (final fila in datos) {
    // -------------------------------------------------------
    // 1. LEER CLASE
    // -------------------------------------------------------

    String clase =
        fila['clase']?.toString().trim().toUpperCase() ?? '';

    // -------------------------------------------------------
    // 2. NORMALIZAR
    // -------------------------------------------------------

    clase = clase
        .replaceAll('CLASE ', 'CL')
        .replaceAll('CLASE', 'CL')
        .trim();

    // -------------------------------------------------------
    // 3. VALIDAR CLASE
    // -------------------------------------------------------

    String? claseEncontrada;

    if (clase == 'CL1' ||
        clase == 'CL2' ||
        clase == 'CL5' ||
        clase == 'CL6') {
      claseEncontrada = clase;
    }

    // -------------------------------------------------------
    // 4. SI NO ENCUENTRA LA CLASE,
    //    BUSCARLA EN LA DESCRIPCIÓN
    // -------------------------------------------------------

    if (claseEncontrada == null) {
      final descripcion =
          fila['descripcion']
                  ?.toString()
                  .toUpperCase() ??
              '';

      final coincidencia = RegExp(
        r'\bCL[1256]\b',
      ).firstMatch(descripcion);

      if (coincidencia != null) {
        claseEncontrada = coincidencia.group(0);
      }
    }

    // -------------------------------------------------------
    // 5. SI NO ES UNA CLASE VÁLIDA, IGNORAR
    // -------------------------------------------------------

    if (claseEncontrada == null) {
      continue;
    }

    // -------------------------------------------------------
    // 6. VALOR DEL STOCK
    // -------------------------------------------------------

    final monto = _toDouble(
      fila['valor_lista_precio_dolar'],
    );

    // -------------------------------------------------------
    // 7. ACUMULAR
    // -------------------------------------------------------

    clases[claseEncontrada] =
        (clases[claseEncontrada] ?? 0) + monto;
  }

  // =========================================================
  // CREAR RESULTADO
  // =========================================================

  final resultado = clases.entries
      .where((e) => e.value > 0)
      .map(
        (e) => ClaseResumen(
          clase: e.key,
          monto: e.value,
        ),
      )
      .toList();

  // =========================================================
  // ORDEN FIJO:
  //
  // CL1
  // CL2
  // CL5
  // CL6
  // =========================================================

  const orden = {
    'CL1': 1,
    'CL2': 2,
    'CL5': 3,
    'CL6': 4,
  };

  resultado.sort(
    (a, b) =>
        (orden[a.clase] ?? 99)
            .compareTo(orden[b.clase] ?? 99),
  );

  return resultado;
}
// =========================================================
// TOP CLIENTES
// =========================================================
//
// Devuelve TODOS los clientes.
//
// Cada cliente contiene:
// - Valor de stock
// - Peso de cobre
//
// Se mantiene el filtro de permisos actual.
// =========================================================

Future<List<ClienteTop>> obtenerTopClientes() async {
  final datos = await _obtenerStockFiltrado();

  // ---------------------------------------------------------
  // VALOR POR CLIENTE
  // ---------------------------------------------------------

  final Map<String, double> valores = {};

  // ---------------------------------------------------------
  // PESO POR CLIENTE
  // ---------------------------------------------------------

  final Map<String, double> pesos = {};

  // ---------------------------------------------------------
  // RECORRER STOCK
  // ---------------------------------------------------------

  for (final fila in datos) {
    final cliente =
        (fila['cliente'] ?? 'SIN CLIENTE')
            .toString()
            .trim();

    if (cliente.isEmpty) {
      continue;
    }

    // -------------------------------------------------------
    // VALOR
    // -------------------------------------------------------

    final valor = _toDouble(
      fila['valor_lista_precio_dolar'],
    );

    valores.update(
      cliente,
      (actual) => actual + valor,
      ifAbsent: () => valor,
    );

    // -------------------------------------------------------
    // PESO
    // -------------------------------------------------------

    final peso = _toDouble(
      fila['peso'],
    );

    pesos.update(
      cliente,
      (actual) => actual + peso,
      ifAbsent: () => peso,
    );
  }

  // ---------------------------------------------------------
  // CREAR LISTA TIPADA
  // ---------------------------------------------------------

  final List<ClienteTop> resultado = [];

  for (final entrada in valores.entries) {
    resultado.add(
      ClienteTop(
        cliente: entrada.key,
        valorStock: entrada.value,
        pesoCobre: pesos[entrada.key] ?? 0,
      ),
    );
  }

  // ---------------------------------------------------------
  // ORDENAR DE MAYOR A MENOR
  // ---------------------------------------------------------

  resultado.sort(
    (a, b) => b.valorStock.compareTo(
      a.valorStock,
    ),
  );

  // ---------------------------------------------------------
  // IMPORTANTE:
  // DEVOLVER TODOS LOS CLIENTES
  // ---------------------------------------------------------

  return resultado;
}
  
// =========================================================
// PRODUCTOS POR CLIENTE
// =========================================================

Future<List<ProductoCliente>> obtenerProductosCliente(
  String cliente,
) async {
  // ---------------------------------------------------------
  // OBTENER STOCK SEGÚN LOS PERMISOS DEL USUARIO
  // ---------------------------------------------------------

  final datos = await _obtenerStockFiltrado();

  // ---------------------------------------------------------
  // NORMALIZAR CLIENTE BUSCADO
  // ---------------------------------------------------------

  final clienteBuscado =
      cliente.trim().toLowerCase();

  // ---------------------------------------------------------
  // FILTRAR CLIENTE
  // ---------------------------------------------------------

  final datosCliente = datos.where((fila) {
    final nombreCliente =
        fila['cliente']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    return nombreCliente == clienteBuscado;
  }).toList();

  // ---------------------------------------------------------
  // MENSAJES DE CONTROL
  // ---------------------------------------------------------

  print(
    '==============================================',
  );

  print(
    'CLIENTE SELECCIONADO:',
  );

  print(
    '[$clienteBuscado]',
  );

  print(
    'TOTAL REGISTROS STOCK: ${datos.length}',
  );

  print(
    'TOTAL ARTICULOS CLIENTE: ${datosCliente.length}',
  );

  print(
    '==============================================',
  );

  // ---------------------------------------------------------
  // CONSTRUIR LISTA
  // ---------------------------------------------------------

  final List<ProductoCliente> productos = [];

  for (final fila in datosCliente) {
    final descripcion =
        fila['descripcion']
                ?.toString()
                .trim() ??
            '';

    final stock =
        _toDouble(
      fila['stock'],
    );

    final peso =
        _toDouble(
      fila['peso'],
    );

    final valor =
        _toDouble(
      fila['valor_lista_precio_dolar'],
    );

    final fecha =
        fila['fecha_ingreso']
                ?.toString()
                .trim() ??
            '';

    print(
      'ARTICULO: $descripcion | '
      'STOCK: $stock | '
      'VALOR: $valor | '
      'PESO: $peso | '
      'FECHA: $fecha',
    );

    productos.add(
      ProductoCliente(
        descripcion:
            descripcion.isEmpty
                ? 'SIN DESCRIPCIÓN'
                : descripcion,

        stock:
            stock,

        peso:
            peso,

        valor:
            valor,

        fechaIngreso:
            fecha,
      ),
    );
  }

  // ---------------------------------------------------------
  // ORDENAR POR MONTO
  // ---------------------------------------------------------

  productos.sort(
    (a, b) =>
        b.valor.compareTo(
      a.valor,
    ),
  );

  // ---------------------------------------------------------
  // RESULTADO
  // ---------------------------------------------------------

  print(
    'PRODUCTOS DEVUELTOS: ${productos.length}',
  );

  return productos;
}

  // =========================================================
  // TOP PRODUCTOS
  // =========================================================

  Future<List<ProductoTop>> obtenerTopProductos() async {

    final datos = await _obtenerStockFiltrado();

    final Map<String, double> productos = {};

    for (final fila in datos) {
      final descripcion =
          (fila['descripcion'] ?? 'SIN DESCRIPCIÓN')
              .toString();

      final valor = _toDouble(
        fila['valor_lista_precio_dolar'],
      );

      productos.update(
        descripcion,
        (actual) => actual + valor,
        ifAbsent: () => valor,
      );
    }

    final resultado = productos.entries
        .map(
          (e) => ProductoTop(
            descripcion: e.key,
            valor: e.value,
          ),
        )
        .toList();

    resultado.sort(
      (a, b) => b.valor.compareTo(a.valor),
    );

    return resultado.take(10).toList();
  }
  // =========================================================
// STOCK POR VENDEDOR
// =========================================================

Future<List<StockVendedor>> obtenerStockPorVendedor() async {
  final datos = await _obtenerStockFiltrado();

  final Map<String, double> vendedores = {};

  for (final fila in datos) {
    final nombre =
        fila['vendedor']?.toString().trim() ?? '';

    if (nombre.isEmpty) {
      continue;
    }

    final valor = _toDouble(
      fila['valor_lista_precio_dolar'],
    );

    vendedores.update(
      nombre,
      (actual) => actual + valor,
      ifAbsent: () => valor,
    );
  }

  final resultado = vendedores.entries
      .map(
        (e) => StockVendedor(
          vendedor: e.key,
          valorStock: e.value,
        ),
      )
      .where(
        (e) => e.valorStock > 0,
      )
      .toList();

  resultado.sort(
    (a, b) => b.valorStock.compareTo(a.valorStock),
  );

  return resultado;
}
}