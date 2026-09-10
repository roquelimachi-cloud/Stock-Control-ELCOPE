import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;


import '../../models/cotizaciones/cliente_cotizacion.dart';
import '../../services/cotizaciones/cliente_cotizacion_service.dart';
import '../../services/cotizaciones/producto_cotizacion_service.dart';
import 'importar_clientes_page.dart';
import 'importar_lista_precios_page.dart';
import '../../services/sesion.dart';

class CotizacionesPage extends StatefulWidget {
  const CotizacionesPage({super.key});

  @override
  State<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends State<CotizacionesPage> {
  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    final sufijo = ahora.millisecondsSinceEpoch.toString();
    _numeroCotizacionFijo = 'COT-${ahora.year}-${sufijo.substring(sufijo.length - 6)}';
  }

  final _clienteController = TextEditingController();
  final _rucController = TextEditingController();
  final _validezController = TextEditingController(text: '7');

  final ClienteCotizacionService _clienteService =
      ClienteCotizacionService();

  final ProductoCotizacionService _productoService =
      ProductoCotizacionService();

  final _productoController = TextEditingController();
  bool _buscandoProducto = false;
  List<ProductoCotizacionStock> _productosEncontrados = [];
  List<ProductoCotizacionStock> _todosProductosDisponibles = [];
  int _busquedaProductoSecuencia = 0;

  ClienteCotizacion? _clienteSeleccionado;
  bool _buscandoCliente = false;
  int _paso = 1;
  late final String _numeroCotizacionFijo;

  String _moneda = 'Dólares Americanos (USD)';
  String _formaPago = 'CONTADO';
  String _lugarEntrega = 'Según producto';
  String _plazoEntrega = 'Según producto';

  // Tipo de cambio manual cuando la cotización se emite en soles.
  final TextEditingController _tipoCambioController = TextEditingController();

  final List<_LineaCotizacion> _lineas = [];

  final TextEditingController _descuentoGlobalController =
      TextEditingController(text: '0');

  bool _descuentoEsGlobal = true;

  double get _descuentoGlobalPorcentaje =>
      _descuentoEsGlobal
          ? (double.tryParse(
                _descuentoGlobalController.text
                    .trim()
                    .replaceAll(',', '.'),
              ) ??
              0)
          : 0;


  String get _numeroCotizacion => _numeroCotizacionFijo;

  String get _fechaActual {
    final ahora = DateTime.now();
    final dd = ahora.day.toString().padLeft(2, '0');
    final mm = ahora.month.toString().padLeft(2, '0');
    return '$dd/$mm/${ahora.year}';
  }

  double get _tipoCambio {
    if (_moneda != 'Soles (PEN)') return 1;
    return double.tryParse(
          _tipoCambioController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
  }

  double get _factorMoneda => _moneda == 'Soles (PEN)' ? _tipoCambio : 1;

  double get _subtotal =>
      _lineas.fold<double>(
        0,
        (sum, item) => sum + item.brutoConFactor(_factorPresentacion(item)),
      ) *
      _factorMoneda;

  double get _descuento =>
      (_descuentoEsGlobal
          ? 0
          : _lineas.fold<double>(
              0,
              (sum, item) =>
                  sum + item.descuentoConFactor(_factorPresentacion(item)),
            )) *
      _factorMoneda;

  double get _subtotalConDescuentoItems =>
      _subtotal - _descuento;

  double get _descuentoGlobal {
    if (!_descuentoEsGlobal) return 0;

    final porcentaje = _descuentoGlobalPorcentaje.clamp(0, 100);
    return _subtotal * (porcentaje / 100);
  }

  double get _baseImponible =>
      _subtotalConDescuentoItems - _descuentoGlobal;

  double get _igv => _baseImponible * .18;
  double get _total => _baseImponible + _igv;

  @override
  void dispose() {
    _clienteController.dispose();
    _rucController.dispose();
    _validezController.dispose();
    _productoController.dispose();
    _descuentoGlobalController.dispose();
    _tipoCambioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final movil = ancho < 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF16803A),
        elevation: .5,
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(5),
              child: Image.asset(
                'assets/images/logo_elcope.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.business_outlined,
                  color: Color(0xFF16803A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'COTIZACIONES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
        actions: [
          if (!movil)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _botonPdf(),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            movil ? 12 : 22,
            movil ? 12 : 18,
            movil ? 12 : 22,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _encabezado(movil),
                  const SizedBox(height: 14),
                  _pasos(movil),
                  const SizedBox(height: 14),
                  _contenidoPaso(movil),
                  const SizedBox(height: 14),
                  _navegacionPasos(movil),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: movil ? _barraMovil() : null,
    );
  }


  Widget _contenidoPaso(bool movil) {
    switch (_paso) {
      case 1:
        return _datosCliente(movil);
      case 2:
        return _productos(movil);
      case 3:
        return _condiciones(movil);
      case 4:
        return _revisarCotizacion(movil);
      default:
        return _datosCliente(movil);
    }
  }

  Widget _navegacionPasos(bool movil) {
    final puedeAtras = _paso > 1;
    final esUltimo = _paso == 4;

    return _card(
      padding: EdgeInsets.all(movil ? 12 : 16),
      child: Row(
        children: [
          if (puedeAtras)
            OutlinedButton.icon(
              onPressed: () => setState(() => _paso--),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Anterior'),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          if (!esUltimo)
            ElevatedButton.icon(
              onPressed: _avanzarPaso,
              icon: const Icon(Icons.arrow_forward),
              label: Text(_paso == 3 ? 'Revisar cotización' : 'Continuar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16803A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _generarPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generar PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16803A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              ),
            ),
        ],
      ),
    );
  }

  void _avanzarPaso() {
    if (_paso == 1 && _clienteSeleccionado == null) {
      _mensaje('Primero seleccione un cliente.');
      return;
    }

    if (_paso == 2 && _lineas.isEmpty) {
      _mensaje('Agregue al menos un producto antes de continuar.');
      return;
    }

    if (_paso == 3 && _moneda == 'Soles (PEN)' && _tipoCambio <= 0) {
      _mensaje('Ingrese el tipo de cambio del día antes de revisar la cotización.');
      return;
    }

    setState(() {
      if (_paso < 4) _paso++;
    });
  }

  double _precioVisible(_LineaCotizacion linea) =>
      linea.precioPresentacion * _factorMoneda;

  double _totalVisible(_LineaCotizacion linea) =>
      linea.totalConFactor(_factorPresentacion(linea)) * _factorMoneda;

  String _montoVisible(double value, {int decimales = 2}) =>
      '$_simboloMoneda ${value.toStringAsFixed(decimales)}';

  Widget _revisarCotizacion(bool movil) {
    final cliente = _clienteSeleccionado;

    return Column(
      children: [
        _card(
          title: 'Revisar Cotización',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bloqueRevision(
                'Cliente',
                [
                  ['Razón social', cliente?.razonSocial ?? 'Sin seleccionar'],
                  ['RUC', cliente?.ruc ?? ''],
                  ['Vendedor', cliente?.vendedor ?? ''],
                  ['Dirección', cliente?.direccion ?? ''],
                ],
              ),
              const SizedBox(height: 14),
              _bloqueRevision(
                'Condiciones comerciales',
                [
                  ['Moneda', _moneda],
                  if (_moneda == 'Soles (PEN)')
                    ['Tipo de cambio del día', 'S/ ${_tipoCambio.toStringAsFixed(4)} por US\$ 1.00'],
                  ['Forma de pago', _formaPago],
                  ['Lugar de entrega', _lugarEntrega],
                  ['Plazo de entrega', _plazoEntrega],
                  ['Validez', '${_validezController.text.trim().isEmpty ? '7' : _validezController.text.trim()} días'],
                  [
                    'Descuento',
                    _descuentoEsGlobal
                        ? '${_descuentoGlobalPorcentaje.toStringAsFixed(2)} % global'
                        : 'Por ítem',
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _bloqueRevisionProductos(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _resumenFinal(movil),
      ],
    );
  }

  Widget _bloqueRevision(String titulo, List<List<String>> datos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172554),
            ),
          ),
          const SizedBox(height: 9),
          ...datos.map(
            (dato) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 145,
                    child: Text(
                      dato[0],
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      dato[1].isEmpty ? '-' : dato[1],
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueRevisionProductos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Productos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172554),
            ),
          ),
          const SizedBox(height: 10),
          if (_lineas.isEmpty)
            const Text('No hay productos agregados.')
          else
            ..._lineas.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final linea = entry.value;
              final factor = _factorPresentacion(linea);
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$i.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16803A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            linea.codigo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(linea.descripcion),
                          const SizedBox(height: 4),
                          Text(
                            'Cantidad: ${linea.cantidad.toStringAsFixed(linea.cantidad == linea.cantidad.roundToDouble() ? 0 : 2)}'
                            '  •  P. Unit.: ${_montoVisible(_precioVisible(linea))}'
                            '  •  Total: ${_montoVisible(_totalVisible(linea))}',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _encabezado(bool movil) {
    return _card(
      padding: EdgeInsets.all(movil ? 16 : 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: movil ? 46 : 52,
                height: movil ? 46 : 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F7EE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.request_quote_outlined,
                  color: Color(0xFF16803A),
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva Cotización',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172554),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Prepare una propuesta comercial para su cliente',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!movil) ...[
                _datoCabecera('N.º Cotización', _numeroCotizacion),
                const SizedBox(width: 12),
                _datoCabecera('Fecha', _fechaActual, icon: Icons.calendar_today),
                const SizedBox(width: 12),
                _estadoBorrador(),
              ],
            ],
          ),
          if (movil) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _datoCabecera('N.º Cotización', _numeroCotizacion)),
                const SizedBox(width: 8),
                Expanded(child: _datoCabecera('Fecha', _fechaActual, icon: Icons.calendar_today)),
              ],
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: _estadoBorrador()),
          ],
        ],
      ),
    );
  }

  Widget _datoCabecera(String titulo, String valor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 7),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF172554), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estadoBorrador() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EE),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        'Borrador',
        style: TextStyle(
          color: Color(0xFF16803A),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _pasos(bool movil) {
    final pasos = const [
      ('Cliente', Icons.business_outlined),
      ('Productos', Icons.inventory_2_outlined),
      ('Condiciones', Icons.assignment_outlined),
      ('Revisar', Icons.fact_check_outlined),
    ];

    return _card(
      padding: EdgeInsets.symmetric(horizontal: movil ? 10 : 24, vertical: 14),
      child: Row(
        children: pasos.asMap().entries.map((entry) {
          final index = entry.key;
          final paso = index + 1;
          final activo = paso <= _paso;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _paso = paso),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: paso <= _paso
                                ? const Color(0xFF16803A)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      Container(
                        width: movil ? 34 : 38,
                        height: movil ? 34 : 38,
                        decoration: BoxDecoration(
                          color: activo
                              ? const Color(0xFF16803A)
                              : const Color(0xFFE8EEF5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          paso == 1 ? Icons.business_outlined : paso == 2
                              ? Icons.inventory_2_outlined : paso == 3
                              ? Icons.assignment_outlined : Icons.fact_check_outlined,
                          color: activo ? Colors.white : const Color(0xFF64748B),
                          size: 18,
                        ),
                      ),
                      if (index < pasos.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: paso < _paso
                                ? const Color(0xFF16803A)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    paso == 1 ? 'Cliente' : paso == 2 ? 'Productos' : paso == 3 ? 'Condiciones' : 'Revisar',
                    style: TextStyle(
                      fontSize: movil ? 11 : 12,
                      fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                      color: activo ? const Color(0xFF16803A) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _datosCliente(bool movil) {
    return _card(
      title: 'Datos del Cliente',
      icon: Icons.business_outlined,
      trailing: _clienteSeleccionado == null
          ? TextButton.icon(
              onPressed: _abrirBusquedaCliente,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Buscar Cliente'),
            )
          : TextButton(
              onPressed: _abrirBusquedaCliente,
              child: const Text('Cambiar cliente'),
            ),
      child: _clienteSeleccionado == null
          ? _buscadorCliente(movil)
          : _clienteSeleccionadoCard(movil),
    );
  }

  Widget _buscadorCliente(bool movil) {
    return movil
        ? Column(
            children: [
              TextField(
                controller: _clienteController,
                decoration: _decoracion('Cliente / Razón Social', Icons.person_outline),
                onSubmitted: (_) => _buscarClientes(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rucController,
                decoration: _decoracion('RUC', Icons.badge_outlined),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _buscarClientes(),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: _botonBuscarCliente()),
              const SizedBox(height: 7),
              if (Sesion.esAdministrador)
                TextButton.icon(
                  onPressed: _abrirImportador,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Importar clientes'),
                ),
            ],
          )
        : Row(
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _clienteController,
                  decoration: _decoracion('Cliente / Razón Social', Icons.person_outline),
                  onSubmitted: (_) => _buscarClientes(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _rucController,
                  decoration: _decoracion('RUC', Icons.badge_outlined),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _buscarClientes(),
                ),
              ),
              const SizedBox(width: 12),
              _botonBuscarCliente(),
              const SizedBox(width: 8),
              if (Sesion.esAdministrador)
                OutlinedButton.icon(
                  onPressed: _abrirImportador,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Importar clientes'),
                ),
            ],
          );
  }

  Widget _botonBuscarCliente() {
    return ElevatedButton.icon(
      onPressed: _buscandoCliente ? null : _buscarClientes,
      icon: _buscandoCliente
          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.search, size: 18),
      label: Text(_buscandoCliente ? 'Buscando...' : 'Buscar cliente'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Future<void> _buscarClientes() async {
    final texto = _clienteController.text.trim().isNotEmpty
        ? _clienteController.text.trim()
        : _rucController.text.trim();

    if (texto.isEmpty) {
      _mensaje('Ingrese RUC o razón social para buscar.');
      return;
    }

    await _buscarClientesConTexto(texto);
  }

  Future<void> _abrirBusquedaCliente() async {
    // "Cambiar cliente" debe volver al buscador y NO volver a buscar
    // automáticamente al cliente que ya estaba seleccionado.
    if (_clienteSeleccionado != null) {
      setState(() {
        _clienteSeleccionado = null;
        _clienteController.clear();
        _rucController.clear();
        _paso = 1;
      });
      return;
    }

    final texto = _clienteController.text.trim().isNotEmpty
        ? _clienteController.text.trim()
        : _rucController.text.trim();
    if (texto.isEmpty) {
      _mensaje('Ingrese RUC o razón social para buscar.');
      return;
    }
    await _buscarClientesConTexto(texto);
  }

  Future<void> _buscarClientesConTexto(String texto) async {
    setState(() => _buscandoCliente = true);
    try {
      final clientes = await _clienteService.buscarClientes(texto);
      if (!mounted) return;
      if (clientes.isEmpty) {
        _mensaje('No se encontraron clientes.');
        return;
      }

      final seleccionado = await showDialog<ClienteCotizacion>(
        context: context,
        builder: (_) => _dialogoClientes(clientes),
      );

      if (!mounted || seleccionado == null) return;
      setState(() {
        _clienteSeleccionado = seleccionado;
        _clienteController.text = seleccionado.razonSocial;
        _rucController.text = seleccionado.ruc;
        _paso = 2;
      });
    } catch (_) {
      if (!mounted) return;
      _mensaje('No fue posible consultar los clientes. Verifique la tabla clientes en Supabase.');
    } finally {
      if (mounted) setState(() => _buscandoCliente = false);
    }
  }

  Widget _dialogoClientes(List<ClienteCotizacion> clientes) {
    return AlertDialog(
      title: const Text('Seleccionar cliente', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 700,
        height: 430,
        child: ListView.separated(
          itemCount: clientes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final cliente = clientes[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE9F7EE),
                child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF16803A), fontWeight: FontWeight.bold)),
              ),
              title: Text(cliente.razonSocial, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('RUC: ${cliente.ruc}  •  Vendedor: ${cliente.vendedor}\n${cliente.direccion}'),
              isThreeLine: true,
              onTap: () => Navigator.pop(context, cliente),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
      ],
    );
  }

  Widget _clienteSeleccionadoCard(bool movil) {
    final cliente = _clienteSeleccionado!;

    String limpio(String? valor) {
      final texto = (valor ?? '').trim();
      return texto.isEmpty ? '-' : texto;
    }

    final razonSocial = cliente.razonSocial.trim().isNotEmpty
        ? cliente.razonSocial.trim()
        : (_clienteController.text.trim().isNotEmpty
            ? _clienteController.text.trim()
            : '-');

    final ruc = cliente.ruc.trim().isNotEmpty
        ? cliente.ruc.trim()
        : (_rucController.text.trim().isNotEmpty
            ? _rucController.text.trim()
            : '-');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(movil ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: Color(0xFF16803A), size: 21),
              SizedBox(width: 8),
              Text(
                'Cliente seleccionado',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            razonSocial,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _datoCliente('RUC', ruc),
              _datoCliente('Vendedor', limpio(cliente.vendedor)),
              _datoCliente('Localidad', limpio(cliente.localidad)),
              _datoCliente('Departamento', limpio(cliente.departamento)),
              _datoCliente('Canal', limpio(cliente.canal)),
              _datoCliente('Giro', limpio(cliente.giro)),
              _datoCliente('Sector', limpio(cliente.sector)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF475569)),
              const SizedBox(width: 7),
              Expanded(
                child: SelectableText(
                  limpio(cliente.direccion),
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datoCliente(String titulo, String valor) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF475467), fontSize: 12.5),
        children: [
          TextSpan(text: '$titulo: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: valor.isEmpty ? '-' : valor),
        ],
      ),
    );
  }

  Widget _productos(bool movil) {
    // En móvil no ponemos los botones dentro del encabezado de la tarjeta.
    // Eso evita que "Productos" pierda ancho y termine dibujándose
    // verticalmente letra por letra.
    if (movil) {
      return _card(
        title: 'Productos',
        icon: Icons.inventory_2_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _botonesProductosMovil(),
            const SizedBox(height: 12),
            _campoBusquedaProducto(movil),
            if (_buscandoProducto) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF16803A),
              ),
            ],
            if (_productosEncontrados.isNotEmpty) ...[
              const SizedBox(height: 10),
              _resultadosProductos(movil),
            ],
            const SizedBox(height: 12),
            _contenidoLineasProductos(movil),
          ],
        ),
      );
    }

    return _card(
      title: 'Productos',
      icon: Icons.inventory_2_outlined,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (Sesion.esAdministrador)
            OutlinedButton.icon(
              onPressed: _abrirImportadorListaPrecios,
              icon: const Icon(Icons.price_change_outlined, size: 18),
              label: const Text('Lista de precios'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16803A),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _abrirSelectorProducto,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar producto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF93C5FD)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          _campoBusquedaProducto(movil),
          if (_buscandoProducto) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF16803A),
            ),
          ],
          if (_productosEncontrados.isNotEmpty) ...[
            const SizedBox(height: 10),
            _resultadosProductos(movil),
          ],
          const SizedBox(height: 12),
          _contenidoLineasProductos(movil),
        ],
      ),
    );
  }

  Widget _botonesProductosMovil() {
    return Row(
      children: [
        if (Sesion.esAdministrador)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _abrirImportadorListaPrecios,
              icon: const Icon(Icons.price_change_outlined, size: 17),
              label: const Text('Lista de precios'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16803A),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (Sesion.esAdministrador) const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _abrirSelectorProducto,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF93C5FD)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoBusquedaProducto(bool movil) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _productoController,
            decoration: _decoracion(
              'Buscar producto por código, modelo o descripción...',
              Icons.search,
            ),
            onChanged: _buscarProductos,
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Buscar producto',
          onPressed: _abrirSelectorProducto,
          icon: const Icon(
            Icons.search,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  Widget _contenidoLineasProductos(bool movil) {
    if (_lineas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 9),
            const Text(
              'No hay productos agregados',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Busque un producto y selecciónelo para comenzar',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!movil) ...[
          _cabeceraProductos(),
          const SizedBox(height: 6),
        ],
        ..._lineas.asMap().entries.map(
          (e) => _lineaProducto(e.key, e.value, movil),
        ),
      ],
    );
  }

  Widget _resultadosProductos(bool movil) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFDDE5EE),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _productosEncontrados.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: Color(0xFFE8EDF3),
        ),
        itemBuilder: (_, index) {
          final producto = _productosEncontrados[index];
          return _resultadoProductoItem(
            producto,
            movil,
          );
        },
      ),
    );
  }

  Widget _resultadoProductoItem(
    ProductoCotizacionStock producto,
    bool movil, {
    BuildContext? dialogContext,
  }) {
    final conStock = producto.stock > 0;
    final stockBajo = conStock && producto.stock <= 100;
    final estadoColor = conStock
        ? (stockBajo ? const Color(0xFFB45309) : const Color(0xFF16803A))
        : const Color(0xFFDC2626);
    final fondo = conStock
        ? (stockBajo ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4))
        : const Color(0xFFFEF2F2);
    final borde = conStock
        ? (stockBajo ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0))
        : const Color(0xFFFECACA);

    return Material(
      color: fondo,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          if (dialogContext != null) {
            Navigator.pop(dialogContext, producto);
          } else {
            _seleccionarProducto(producto);
          }
        },
        child: Container(
          padding: EdgeInsets.all(movil ? 12 : 13),
          decoration: BoxDecoration(
            border: Border.all(color: borde),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inventory_2_outlined, color: estadoColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.descripcion,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172554),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Código: ${producto.codigo}',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        producto.stockTexto,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: estadoColor,
                        ),
                      ),
                      Text(
                        producto.unidadVisible,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                      if (producto.peso > 0)
                        Text(
                          '${producto.pesoTexto} kg',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _chipProducto(
                    'UNIDAD: ${producto.unidadVisible}',
                    color: estadoColor,
                  ),
                  _chipProducto(
                    'PRESENTACIÓN: ${producto.presentacion}',
                  ),
                  _chipProducto(
                    conStock
                        ? 'STOCK: ${producto.stockTexto} ${producto.unidadVisible == 'ROLLO' ? 'ROLLOS' : 'MT'}'
                        : 'SIN STOCK',
                    color: estadoColor,
                  ),
                ],
              ),
              if (producto.cliente.trim().isNotEmpty && producto.cliente != 'SIN CLIENTE') ...[
                const SizedBox(height: 6),
                Text(
                  'Cliente: ${producto.cliente}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5),
                ),
              ],
              if (producto.lote.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Lote: ${producto.lote}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5),
                ),
              ],
              if (producto.vendedor.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Vendedor: ${producto.vendedor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Precio lista: US\$ ${producto.valorListaPrecioDolar.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF16803A),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF16803A)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipProducto(String texto, {Color? color}) {
    final textoColor = color ?? const Color(0xFF475569);
    final fondo = color == null ? const Color(0xFFF1F5F9) : color.withOpacity(.10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: textoColor,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }

  Widget _botonSeleccionarProducto(
    ProductoCotizacionStock producto,
  ) {
    return OutlinedButton(
      onPressed: () => _seleccionarProducto(producto),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(
          color: Color(0xFF93C5FD),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text('SELECCIONAR'),
    );
  }

  Future<void> _buscarProductos(String texto) async {
    final busqueda = _normalizarBusqueda(texto);
    final secuencia = ++_busquedaProductoSecuencia;

    if (busqueda.isEmpty) {
      if (!mounted) return;
      setState(() {
        _productosEncontrados = [];
        _buscandoProducto = false;
      });
      return;
    }

    setState(() => _buscandoProducto = true);

    try {
      final productos = _normalizarBusqueda(texto)
              .split(RegExp(r'\s+'))
              .contains('199000000000000')
          ? <ProductoCotizacionStock>[_productoComodin()]
          : await _productoService.buscarProductos(texto);
      if (!mounted || secuencia != _busquedaProductoSecuencia) return;

      setState(() {
        _productosEncontrados = productos;
        _buscandoProducto = false;
      });
    } catch (_) {
      if (!mounted || secuencia != _busquedaProductoSecuencia) return;
      setState(() {
        _productosEncontrados = [];
        _buscandoProducto = false;
      });
      _mensaje(
        'No fue posible buscar productos. Verifique la conexión con Supabase.',
      );
    }
  }

  String _normalizarBusqueda(String texto) {
    var resultado = texto.toLowerCase().trim();
    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    reemplazos.forEach((origen, destino) {
      resultado = resultado.replaceAll(origen, destino);
    });
    resultado = resultado.replaceAll(RegExp(r'(?<=\d),(?=\d)'), '.');
    resultado = resultado.replaceAll(RegExp(r'[^a-z0-9.]+'), ' ');
    resultado = resultado.replaceAll(RegExp(r'\s+'), ' ').trim();
    return resultado;
  }

  Future<void> _abrirSelectorProducto() async {
    // La ventana abre inmediatamente con una pequeña muestra de stock.
    // Ya no esperamos a cargar miles de filas para poder mostrar algo.
    ++_busquedaProductoSecuencia;
    if (mounted) {
      setState(() {
        _productosEncontrados = [];
        _buscandoProducto = true;
      });
    }

    try {
      final muestra = await _productoService.obtenerMuestraInicial(limite: 20);
      if (mounted) {
        setState(() {
          _productosEncontrados = muestra;
          _buscandoProducto = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _productosEncontrados = [];
          _buscandoProducto = false;
        });
      }
    }

    final seleccionado = await showDialog<ProductoCotizacionStock>(
      context: context,
      builder: (_) => _dialogoProductos(),
    );

    if (!mounted || seleccionado == null) return;
    _seleccionarProducto(seleccionado);
  }

  Widget _dialogoProductos() {
    final controller = TextEditingController(text: _productoController.text);

    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Color(0xFF16803A)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Buscar producto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 850,
            height: 500,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: _decoracion(
                    'Código, modelo o descripción',
                    Icons.search,
                  ),
                  onChanged: (texto) async {
                    final secuencia = ++_busquedaProductoSecuencia;
                    final busqueda = _normalizarBusqueda(texto);

                    if (busqueda.isEmpty) {
                      setDialogState(() => _buscandoProducto = true);
                      try {
                        final muestra = await _productoService.obtenerMuestraInicial(limite: 20);
                        if (!dialogContext.mounted || secuencia != _busquedaProductoSecuencia) return;
                        setDialogState(() {
                          _productosEncontrados = muestra;
                          _buscandoProducto = false;
                        });
                      } catch (_) {
                        if (!dialogContext.mounted || secuencia != _busquedaProductoSecuencia) return;
                        setDialogState(() {
                          _productosEncontrados = [];
                          _buscandoProducto = false;
                        });
                      }
                      return;
                    }

                    setDialogState(() => _buscandoProducto = true);
                    try {
                      final productos = _normalizarBusqueda(texto)
                              .split(RegExp(r'\s+'))
                              .contains('199000000000000')
                          ? <ProductoCotizacionStock>[_productoComodin()]
                          : await _productoService.buscarProductos(texto);
                      if (!dialogContext.mounted || secuencia != _busquedaProductoSecuencia) return;
                      setDialogState(() {
                        _productosEncontrados = productos;
                        _buscandoProducto = false;
                      });
                    } catch (_) {
                      if (!dialogContext.mounted || secuencia != _busquedaProductoSecuencia) return;
                      setDialogState(() {
                        _productosEncontrados = [];
                        _buscandoProducto = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (_buscandoProducto) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 8),
                Expanded(
                  child: _productosEncontrados.isEmpty
                      ? Center(
                          child: Text(
                            controller.text.trim().isEmpty
                                ? 'Cargando una muestra de stock disponible...'
                                : 'No se encontraron productos.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _productosEncontrados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 7),
                          itemBuilder: (_, index) => _resultadoProductoItem(
                            _productosEncontrados[index],
                            true,
                            dialogContext: dialogContext,
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  ProductoCotizacionStock _productoComodin() {
    return const ProductoCotizacionStock(
      codigo: '199000000000000',
      descripcion: 'COMODÍN',
      stock: 0,
      peso: 0,
      valorListaPrecioDolar: 0,
      cliente: '',
      almacen: '',
      condicion: 'COMODÍN',
      vendedor: '',
      lote: '',
      fechaIngreso: '',
      modelo: '',
      datosBusqueda: '199000000000000 comodin',
      unidadMedida: '',
      presentacionStock: '',
      cantidadEmpaque: 0,
    );
  }

  Future<void> _seleccionarProducto(
    ProductoCotizacionStock producto,
  ) async {
    String descripcion = producto.descripcion;

    // 199000000000000 es el código comodín:
    // el código permanece fijo y el usuario define la descripción.
    if (producto.esComodin) {
      final controller = TextEditingController(
        text: producto.descripcion == 'COMODÍN' ? '' : producto.descripcion,
      );

      final nuevaDescripcion = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'Producto comodín',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: _decoracion(
              'Descripción del artículo',
              Icons.edit_note_outlined,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                final valor = controller.text.trim();
                if (valor.isEmpty) return;
                Navigator.pop(dialogContext, valor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16803A),
                foregroundColor: Colors.white,
              ),
              child: const Text('AGREGAR'),
            ),
          ],
        ),
      );

      controller.dispose();

      if (!mounted || nuevaDescripcion == null || nuevaDescripcion.trim().isEmpty) {
        return;
      }

      descripcion = nuevaDescripcion.trim();
    }

    if (!mounted) return;

    setState(() {
      _lineas.add(
        _LineaCotizacion(
          codigo: producto.codigo.isEmpty
              ? 'SIN CÓDIGO'
              : producto.codigo,
          descripcion: descripcion,
          stock: producto.stock,
          cantidad: 1,
          presentacion: producto.presentacion,
          precio: producto.valorListaPrecioDolar,
          peso: producto.peso,
          factorPresentacion: producto.factorPresentacion,
          sinStock: producto.stock <= 0,
          tiempoFabricacion: producto.stock <= 0
              ? 'POR CONFIRMAR'
              : 'STOCK - ATENCIÓN INMEDIATA',
        ),
      );

      _productoController.clear();
      _productosEncontrados = [];
      _paso = 2;
    });

    if (producto.stock <= 0) {
      _mostrarTiempoFabricacion(_lineas.length - 1);
    }
  }

  double _factorPresentacion(_LineaCotizacion linea) {
    return linea.factorPresentacion > 0
        ? linea.factorPresentacion
        : 1;
  }

  Future<void> _editarDescripcionComodin(int index) async {
    if (index < 0 || index >= _lineas.length) return;
    if (_lineas[index].codigo.trim() != '199000000000000') return;

    final controller = TextEditingController(
      text: _lineas[index].descripcion,
    );

    final descripcion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Modificar descripción',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: _decoracion(
            'Descripción del artículo',
            Icons.edit_note_outlined,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = controller.text.trim();
              if (valor.isEmpty) return;
              Navigator.pop(dialogContext, valor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16803A),
              foregroundColor: Colors.white,
            ),
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || descripcion == null || descripcion.trim().isEmpty) return;

    setState(() {
      _lineas[index] = _lineas[index].copyWith(
        descripcion: descripcion.trim(),
      );
    });
  }

  Future<void> _editarPrecio(int index) async {
    if (index < 0 || index >= _lineas.length) return;

    final linea = _lineas[index];
    if (_moneda == 'Soles (PEN)' && _tipoCambio <= 0) {
      _mensaje('Ingrese primero el tipo de cambio del día para modificar precios en soles.');
      return;
    }
    final precioActual = linea.precioPresentacion * _factorMoneda;
    final controller = TextEditingController(
      text: precioActual.toStringAsFixed(4),
    );

    final valor = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? error;

        return StatefulBuilder(
          builder: (contextDialog, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.attach_money, color: Color(0xFF16803A)),
                  SizedBox(width: 8),
                  Text(
                    'Modificar precio unitario',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linea.descripcion,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Precio actual: ${_simboloMoneda} ${precioActual.toStringAsFixed(4)}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoracion(
                      'Nuevo precio unitario ($_simboloMoneda)',
                      Icons.price_change_outlined,
                    ).copyWith(
                      errorText: error,
                    ),
                    onChanged: (_) {
                      if (error != null) {
                        setDialogState(() => error = null);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    precioActual <= 0
                        ? 'Este producto no tiene precio. Puede establecer uno nuevo.'
                        : 'El precio puede aumentar, pero no puede disminuir del precio actual.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nuevoPrecio = double.tryParse(
                      controller.text.trim().replaceAll(',', '.'),
                    );

                    if (nuevoPrecio == null || nuevoPrecio <= 0) {
                      setDialogState(() {
                        error = 'Ingrese un precio mayor que 0.';
                      });
                      return;
                    }

                    if (precioActual > 0 && nuevoPrecio < precioActual) {
                      setDialogState(() {
                        error =
                            'No puede disminuir el precio. Mínimo: $_simboloMoneda ${precioActual.toStringAsFixed(4)}.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, nuevoPrecio);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16803A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('GUARDAR'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || valor == null) return;

    final factor = _factorPresentacion(linea);
    final valorEnUsd = _moneda == 'Soles (PEN)' ? valor / _factorMoneda : valor;
    final nuevoPrecioBase = factor > 0 ? valorEnUsd / factor : valorEnUsd;

    setState(() {
      _lineas[index] = _lineas[index].copyWith(
        precio: nuevoPrecioBase,
      );
    });
  }

  Future<void> _editarDescuento(int index) async {
    if (index < 0 || index >= _lineas.length) return;

    final controller = TextEditingController(
      text: _lineas[index].descuentoPorcentaje.toStringAsFixed(2),
    );

    final valor = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Descuento del producto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _decoracion('Descuento (%)', Icons.percent_outlined),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              final descuento = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (descuento == null || descuento < 0 || descuento > 100) {
                return;
              }
              Navigator.pop(dialogContext, descuento);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );


    if (!mounted || valor == null) return;
    setState(() {
      _lineas[index] = _lineas[index].copyWith(
        descuentoPorcentaje: valor,
      );
    });
  }

  void _aumentarCantidad(int index) {
    if (index < 0 || index >= _lineas.length) return;

    final linea = _lineas[index];

    setState(() {
      _lineas[index] = linea.copyWith(
        cantidad: linea.cantidad + 1,
      );
    });
  }

  void _disminuirCantidad(int index) {
    if (index < 0 || index >= _lineas.length) return;

    final linea = _lineas[index];

    if (linea.cantidad <= 1) {
      setState(() {
        _lineas.removeAt(index);
      });
      return;
    }

    setState(() {
      _lineas[index] = linea.copyWith(
        cantidad: linea.cantidad - 1,
      );
    });
  }

  Future<void> _editarCantidad(int index) async {
    if (index < 0 || index >= _lineas.length) return;

    final linea = _lineas[index];
    final controller = TextEditingController(
      text: linea.cantidad.toStringAsFixed(2),
    );

    final cantidad = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Modificar cantidad',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: _decoracion(
              'Cantidad',
              Icons.numbers_outlined,
            ),
            onSubmitted: (_) {
              final valor = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );

              if (valor != null && valor > 0) {
                Navigator.pop(dialogContext, valor);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                final valor = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );

                if (valor == null || valor <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ingrese una cantidad mayor que cero.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, valor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16803A),
                foregroundColor: Colors.white,
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );


    if (!mounted || cantidad == null) return;

    setState(() {
      _lineas[index] = _lineas[index].copyWith(
        cantidad: cantidad,
      );
    });
  }

  Future<void> _mostrarTiempoFabricacion(int index) async {
    String opcion = 'POR CONFIRMAR';
    final personalizadoController = TextEditingController();

    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.factory_outlined,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 9),
              Text(
                'Producto sin stock',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (_, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'El producto se puede cotizar igualmente.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tiempo de fabricación / entrega',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    initialValue: opcion,
                    items: const [
                      DropdownMenuItem(
                        value: 'POR CONFIRMAR',
                        child: Text('Por confirmar'),
                      ),
                      DropdownMenuItem(
                        value: '7 días',
                        child: Text('7 días'),
                      ),
                      DropdownMenuItem(
                        value: '15 días',
                        child: Text('15 días'),
                      ),
                      DropdownMenuItem(
                        value: '20 días',
                        child: Text('20 días'),
                      ),
                      DropdownMenuItem(
                        value: '20–25 días',
                        child: Text('20–25 días'),
                      ),
                      DropdownMenuItem(
                        value: '30 días',
                        child: Text('30 días'),
                      ),
                      DropdownMenuItem(
                        value: 'PERSONALIZADO',
                        child: Text('Personalizado'),
                      ),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;
                      setDialogState(() => opcion = valor);
                    },
                    decoration: _decoracion(
                      'Tiempo',
                      Icons.schedule_outlined,
                    ),
                  ),
                  if (opcion == 'PERSONALIZADO') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: personalizadoController,
                      decoration: _decoracion(
                        'Ejemplo: 35–40 días',
                        Icons.edit_calendar_outlined,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                final valor =
                    opcion == 'PERSONALIZADO'
                        ? personalizadoController.text.trim()
                        : opcion;

                Navigator.pop(
                  dialogContext,
                  valor.isEmpty
                      ? 'POR CONFIRMAR'
                      : valor,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16803A),
                foregroundColor: Colors.white,
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );


    if (!mounted || resultado == null) return;

    setState(() {
      _lineas[index] = _lineas[index].copyWith(
        tiempoFabricacion: resultado,
      );
    });
  }

  Widget _lineaProducto(int index, _LineaCotizacion linea, bool movil) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: movil
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _numeroItem(index + 1),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              linea.descripcion,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF172554),
                              ),
                            ),
                          ),
                          if (linea.codigo.trim() == '199000000000000')
                            IconButton(
                              tooltip: 'Modificar descripción',
                              onPressed: () => _editarDescripcionComodin(index),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: const Color(0xFF2563EB),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => setState(() => _lineas.removeAt(index)), icon: const Icon(Icons.more_vert)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(linea.codigo, style: const TextStyle(color: Color(0xFF475467), fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _etiqueta(
                      linea.stock > 0
                          ? 'Stock: ${linea.stockTexto}'
                          : 'SIN STOCK',
                      verde: linea.stock > 0,
                      rojo: linea.stock <= 0,
                    ),
                    _etiqueta(
                      'Presentación: ${linea.presentacion}',
                      verde: false,
                      rojo: false,
                    ),
                    _etiqueta(
                      'Entrega: ${linea.tiempoFabricacion}',
                      verde: linea.stock > 0,
                      rojo: linea.stock <= 0,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Disminuir cantidad',
                          onPressed: () => _disminuirCantidad(index),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: const Color(0xFF2563EB),
                        ),
                        InkWell(
                          onTap: () => _editarCantidad(index),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 58),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              linea.cantidad.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aumentar cantidad',
                          onPressed: () => _aumentarCantidad(index),
                          icon: const Icon(Icons.add_circle_outline),
                          color: const Color(0xFF16803A),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () => _editarPrecio(index),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _montoVisible(_precioVisible(linea), decimales: 4),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF172554),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _descuentoEsGlobal ? null : () => _editarDescuento(index),
                          child: Text(
                            'Dscto. ${linea.descuentoPorcentaje.toStringAsFixed(2)}%',
                            style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          _montoVisible(_totalVisible(linea)),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF172554)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _numeroItem(index + 1),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(linea.codigo, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF172554)))),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          linea.descripcion,
                          style: const TextStyle(color: Color(0xFF334155)),
                        ),
                      ),
                      if (linea.codigo.trim() == '199000000000000')
                        IconButton(
                          tooltip: 'Modificar descripción',
                          onPressed: () => _editarDescripcionComodin(index),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          color: const Color(0xFF2563EB),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 95,
                  child: Text(
                    linea.stock > 0
                        ? 'Stock\n${linea.stockTexto}'
                        : 'SIN STOCK\n0',
                    style: TextStyle(
                      fontSize: 12,
                      color: linea.stock > 0
                          ? const Color(0xFF16803A)
                          : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 128,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Disminuir cantidad',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        onPressed: () => _disminuirCantidad(index),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 19,
                        ),
                        color: const Color(0xFF2563EB),
                      ),
                      InkWell(
                        onTap: () => _editarCantidad(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 58,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            linea.cantidad.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Aumentar cantidad',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        onPressed: () => _aumentarCantidad(index),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 19,
                        ),
                        color: const Color(0xFF16803A),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 105,
                  child: Text(
                    linea.presentacion,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: InkWell(
                    onTap: () => _editarPrecio(index),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _montoVisible(_precioVisible(linea), decimales: 4),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: InkWell(
                    onTap: _descuentoEsGlobal ? null : () => _editarDescuento(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _descuentoEsGlobal
                            ? 'GLOBAL'
                            : '${linea.descuentoPorcentaje.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    _montoVisible(_totalVisible(linea)),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _lineas.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
    );
  }

  Widget _cabeceraProductos() {
    const estilo = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Color(0xFF475569),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 46, child: Text('Ítem', style: estilo)),
          Expanded(flex: 2, child: Text('Código', style: estilo)),
          Expanded(flex: 4, child: Text('Descripción', style: estilo)),
          SizedBox(width: 95, child: Text('Stock', style: estilo)),
          SizedBox(width: 128, child: Text('Cantidad', textAlign: TextAlign.center, style: estilo)),
          SizedBox(width: 105, child: Text('Presentación', style: estilo)),
          SizedBox(width: 100, child: Text('P. Unit.', style: estilo)),
          SizedBox(width: 82, child: Text('Dscto. ítem', textAlign: TextAlign.center, style: estilo)),
          SizedBox(width: 110, child: Text('Total', style: estilo)),
          SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _numeroItem(int numero) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Color(0xFFE5F7EC), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('$numero', style: const TextStyle(color: Color(0xFF16803A), fontWeight: FontWeight.bold)),
    );
  }

  Widget _etiqueta(
    String texto, {
    bool verde = false,
    bool rojo = false,
  }) {
    final color = rojo
        ? const Color(0xFFDC2626)
        : verde
            ? const Color(0xFF16803A)
            : const Color(0xFF475569);

    final fondo = rojo
        ? const Color(0xFFFEE2E2)
        : verde
            ? const Color(0xFFE8F7EE)
            : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _condiciones(bool movil) {
    final camposPrincipales = [
      _selector(
        'Moneda',
        _moneda,
        (v) {
          setState(() {
            _moneda = v;
            if (_moneda != 'Soles (PEN)') {
              _tipoCambioController.clear();
            }
          });
        },
        opciones: const [
          'Dólares Americanos (USD)',
          'Soles (PEN)',
        ],
      ),
      _selector(
        'Forma de Pago',
        _formaPago,
        (v) => setState(() => _formaPago = v),
        opciones: const [
          'CONTADO',
          'CRÉDITO',
        ],
      ),
      _selector(
        'Lugar de Entrega',
        _lugarEntrega,
        (v) => setState(() => _lugarEntrega = v),
        opciones: const [
          'Según producto',
          'Lima Metropolitana y Callao',
          'Por confirmar',
        ],
      ),
      _selector(
        'Plazo de Entrega',
        _plazoEntrega,
        (v) => setState(() => _plazoEntrega = v),
        opciones: const [
          'Según producto',
          'Inmediata',
          '7 días',
          'Por confirmar',
        ],
      ),
    ];

    return _card(
      title: 'Condiciones Comerciales',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (movil)
            ...[
              for (int i = 0; i < camposPrincipales.length; i++) ...[
                camposPrincipales[i],
                if (i < camposPrincipales.length - 1)
                  const SizedBox(height: 12),
              ],
            ]
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final campo in camposPrincipales)
                  SizedBox(
                    width: 250,
                    child: campo,
                  ),
              ],
            ),
          if (_moneda == 'Soles (PEN)') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: movil ? double.infinity : 250,
              child: _campoTipoCambio(),
            ),
          ],
          const SizedBox(height: 14),
          _selectorTipoDescuento(movil),
          const SizedBox(height: 12),
          if (_descuentoEsGlobal)
            SizedBox(
              width: movil ? double.infinity : 300,
              child: _campoDescuentoGlobal(),
            ),
        ],
      ),
    );
  }

  Widget _selectorTipoDescuento(bool movil) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de descuento',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              SizedBox(
                width: movil ? double.infinity : 330,
                child: RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  groupValue: _descuentoEsGlobal,
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() {
                      _descuentoEsGlobal = valor;
                    });
                  },
                  title: const Text('Descuento global'),
                  subtitle: const Text(
                    'Un mismo porcentaje para toda la cotización.',
                  ),
                ),
              ),
              SizedBox(
                width: movil ? double.infinity : 330,
                child: RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  groupValue: _descuentoEsGlobal,
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() {
                      _descuentoEsGlobal = valor;
                    });
                  },
                  title: const Text('Descuento por ítem'),
                  subtitle: const Text(
                    'Cada producto puede tener un porcentaje diferente.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _campoTipoCambio() {
    return TextField(
      controller: _tipoCambioController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _decoracion(
        'Tipo de cambio del día',
        Icons.currency_exchange_outlined,
      ).copyWith(
        hintText: 'Ej. 3.48',
        helperText: 'Ingrese manualmente el TC USD/PEN del día.',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _campoDescuentoGlobal() {
    if (!_descuentoEsGlobal) {
      return const SizedBox.shrink();
    }

    return TextField(
      controller: _descuentoGlobalController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _decoracion(
        'Descuento global (%)',
        Icons.percent_outlined,
      ).copyWith(
        helperText: 'Se aplica una sola vez a toda la cotización.',
        suffixText: '%',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _resumenFinal(bool movil) {
    return _card(
      child: movil
          ? Column(
              children: [
                _resumenValores(),
                const SizedBox(height: 12),
                _avisoCobre(),
                const SizedBox(height: 12),
                _botonesFinales(true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _resumenValores()),
                const SizedBox(width: 20),
                Expanded(child: _avisoCobre()),
                const SizedBox(width: 20),
                SizedBox(width: 300, child: _botonesFinales(false)),
              ],
            ),
    );
  }

  String get _simboloMoneda => _moneda == 'Soles (PEN)' ? 'S/' : 'US\$';

  String _monto(double value) => '$_simboloMoneda ${value.toStringAsFixed(2)}';

  Widget _resumenValores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Resumen', Icons.calculate_outlined),
        const SizedBox(height: 10),
        _filaResumen('Subtotal', _monto(_subtotal)),
        if (!_descuentoEsGlobal)
          _filaResumen(
            'Descuento por ítems',
            _monto(_descuento),
          ),
        if (_descuentoEsGlobal && _descuentoGlobalPorcentaje > 0)
          _filaResumen(
            'Descuento global (${_descuentoGlobalPorcentaje.toStringAsFixed(2)} %)',
            _monto(_descuentoGlobal),
          ),
        if ((_descuentoEsGlobal && _descuentoGlobal > 0) ||
            (!_descuentoEsGlobal && _descuento > 0))
          _filaResumen(
            'Descuento total',
            _monto(_descuento + _descuentoGlobal),
          ),
        _filaResumen('IGV (18.00 %)', _monto(_igv)),
        const Divider(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF172554)))),
              Text(_monto(_total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF16803A))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avisoCobre() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFFFF5DB), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
            child: const Icon(Icons.priority_high, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nuestros precios están sujetos al precio del cobre en el mercado internacional (LME), en caso este precio suba en 3% o más, habrá un reajuste en el valor de la cotización.',
              style: TextStyle(color: Color(0xFF5B4636), fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonesFinales(bool movil) {
    final botones = [
      OutlinedButton.icon(
        onPressed: () => _mensaje('La función de envío por correo se conectará junto con el PDF.'),
        icon: const Icon(Icons.email_outlined),
        label: const Text('Enviar por Email'),
      ),
      ElevatedButton.icon(
        onPressed: _generarPdf,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Generar PDF'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16803A), foregroundColor: Colors.white),
      ),
    ];

    if (movil) {
      return Column(children: [
        SizedBox(width: double.infinity, child: botones[0]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: botones[1]),
      ]);
    }

    return Column(children: [
      SizedBox(width: double.infinity, child: botones[0]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: botones[1]),
    ]);
  }

  Widget _tituloSeccion(String titulo, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF16803A), size: 22),
        const SizedBox(width: 9),
        Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF172554))),
      ],
    );
  }

  Widget _filaResumen(String etiqueta, String valor, {bool principal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: TextStyle(color: principal ? const Color(0xFF172554) : const Color(0xFF64748B), fontWeight: principal ? FontWeight.bold : FontWeight.normal))),
          Text(valor, style: TextStyle(color: principal ? const Color(0xFF16803A) : const Color(0xFF334155), fontWeight: principal ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    String? title,
    IconData? icon,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(icon, color: const Color(0xFF16803A), size: 22),
                const SizedBox(width: 9),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF172554)))),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  Widget _selector(String label, String value, ValueChanged<String> onChanged, {required List<String> opciones}) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: opciones.contains(value) ? value : opciones.first,
      decoration: _decoracion(label, Icons.tune_outlined),
      items: opciones.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }

  InputDecoration _decoracion(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFD7DCE2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF16803A), width: 1.5)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    );
  }

  Widget _barraMovil() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            _navMovil(Icons.home_outlined, 'Inicio'),
            _navMovil(Icons.request_quote_outlined, 'Cotizar', activo: true),
            _navMovil(Icons.people_outline, 'Clientes'),
            _navMovil(Icons.inventory_2_outlined, 'Productos'),
            _navMovil(Icons.menu, 'Más'),
          ],
        ),
      ),
    );
  }

  Widget _navMovil(IconData icon, String texto, {bool activo = false}) {
    return Expanded(
      child: InkWell(
        onTap: activo ? null : () => _mensaje('$texto: próximamente.'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activo ? const Color(0xFF16803A) : const Color(0xFF64748B), size: 22),
            const SizedBox(height: 2),
            Text(texto, style: TextStyle(fontSize: 10, color: activo ? const Color(0xFF16803A) : const Color(0xFF64748B), fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  void _abrirImportadorListaPrecios() {
    if (!Sesion.esAdministrador) {
      _mensaje('Solo el administrador puede importar la lista de precios.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportarListaPreciosPage(),
      ),
    ).then((_) {
      if (!mounted) return;
      _todosProductosDisponibles = [];
      _productosEncontrados = [];
      _busquedaProductoSecuencia++;
      setState(() {});
    });
  }

  void _abrirImportador() {
    if (!Sesion.esAdministrador) {
      _mensaje('Solo el administrador puede importar clientes.');
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportarClientesPage()));
  }

  Widget _botonPdf() {
    return ElevatedButton.icon(
      onPressed: _generarPdf,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      label: const Text('GENERAR PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16803A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }

  Future<void> _generarPdf() async {
    if (_clienteSeleccionado == null) {
      _mensaje('Seleccione un cliente antes de generar el PDF.');
      return;
    }
    if (_lineas.isEmpty) {
      _mensaje('Agregue al menos un producto antes de generar el PDF.');
      return;
    }

    if (_moneda == 'Soles (PEN)' && _tipoCambio <= 0) {
      _mensaje('Ingrese el tipo de cambio del día para cotizar en soles.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CotizacionPdfPreviewPage(
          numero: _numeroCotizacion,
          fecha: _fechaActual,
          cliente: _clienteSeleccionado!,
          moneda: _moneda,
          tipoCambio: _tipoCambio,
          formaPago: _formaPago,
          lugarEntrega: _lugarEntrega,
          plazoEntrega: _plazoEntrega,
          validez: _validezController.text.trim().isEmpty
              ? '7'
              : _validezController.text.trim(),
          lineas: _lineas.map((linea) {
            final factor = _factorPresentacion(linea);
            final precioPresentacion = linea.precio * factor * _factorMoneda;
            return <String, dynamic>{
              'codigo': linea.codigo,
              'descripcion': linea.descripcion,
              'cantidad': linea.cantidad,
              'presentacion': linea.presentacion,
              'precio_unitario': precioPresentacion,
              'descuento_porcentaje': _descuentoEsGlobal
                  ? _descuentoGlobalPorcentaje
                  : linea.descuentoPorcentaje,
              'total': linea.totalConFactor(factor) * _factorMoneda,
              'sin_stock': linea.sinStock,
              'tiempo_fabricacion': linea.tiempoFabricacion,
            };
          }).toList(),
          subtotal: _subtotal,
          descuento: _descuento + _descuentoGlobal,
          igv: _igv,
          total: _total,
        ),
      ),
    );
  }

  void _mensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class _LineaCotizacion {
  final String codigo;
  final String descripcion;
  final double stock;
  final double cantidad;
  final String presentacion;
  final double precio;
  final double peso;
  final double factorPresentacion;
  final double descuentoPorcentaje;
  final bool sinStock;

  String get stockTexto {
    if (stock <= 0) return '0';
    return stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 2);
  }
  final String tiempoFabricacion;

  const _LineaCotizacion({
    required this.codigo,
    required this.descripcion,
    required this.stock,
    required this.cantidad,
    required this.presentacion,
    required this.precio,
    required this.peso,
    this.factorPresentacion = 1,
    this.descuentoPorcentaje = 0,
    this.sinStock = false,
    this.tiempoFabricacion =
        'STOCK - ATENCIÓN INMEDIATA',
  });

  /// Precio unitario correspondiente a la presentación.
  ///
  /// Ejemplo:
  /// Código = precio base por metro US$ 0.5104
  /// Presentación = Rollos x 100
  /// Precio del rollo = US$ 51.04
  double get precioPresentacion => precio * factorPresentacion;

  /// Importe bruto de la línea según la presentación seleccionada.
  double get importeBruto =>
      cantidad * precioPresentacion;

  /// Descuento monetario de la línea.
  double get importeDescuento =>
      importeBruto * (descuentoPorcentaje / 100);

  /// Total neto de la línea.
  double get importeNeto =>
      importeBruto - importeDescuento;

  double brutoConFactor(double factor) =>
      cantidad * factor * precio;

  double descuentoConFactor(double factor) =>
      brutoConFactor(factor) * (descuentoPorcentaje / 100);

  double totalConFactor(double factor) =>
      brutoConFactor(factor) - descuentoConFactor(factor);

  double get total => importeNeto;

  double get descuento => importeDescuento;

  _LineaCotizacion copyWith({
    String? codigo,
    String? descripcion,
    double? stock,
    double? cantidad,
    String? presentacion,
    double? precio,
    double? peso,
    double? factorPresentacion,
    double? descuentoPorcentaje,
    bool? sinStock,
    String? tiempoFabricacion,
  }) {
    return _LineaCotizacion(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      stock: stock ?? this.stock,
      cantidad: cantidad ?? this.cantidad,
      presentacion: presentacion ?? this.presentacion,
      precio: precio ?? this.precio,
      peso: peso ?? this.peso,
      factorPresentacion:
          factorPresentacion ?? this.factorPresentacion,
      descuentoPorcentaje: descuentoPorcentaje ?? this.descuentoPorcentaje,
      sinStock: sinStock ?? this.sinStock,
      tiempoFabricacion:
          tiempoFabricacion ?? this.tiempoFabricacion,
    );
  }
}


class _CotizacionPdfPreviewPage extends StatelessWidget {
  final String numero;
  final String fecha;
  final ClienteCotizacion cliente;
  final String moneda;
  final double tipoCambio;
  final String formaPago;
  final String lugarEntrega;
  final String plazoEntrega;
  final String validez;
  final List<Map<String, dynamic>> lineas;
  final double subtotal;
  final double descuento;
  final double igv;
  final double total;

  const _CotizacionPdfPreviewPage({
    required this.numero,
    required this.fecha,
    required this.cliente,
    required this.moneda,
    required this.tipoCambio,
    required this.formaPago,
    required this.lugarEntrega,
    required this.plazoEntrega,
    required this.validez,
    required this.lineas,
    required this.subtotal,
    required this.descuento,
    required this.igv,
    required this.total,
  });

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/images/logo_elcope.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final pdf = pw.Document(
      title: 'Cotización $numero',
      author: 'ELCOPE',
      subject: 'Cotización comercial',
    );

    final simbolo = moneda == 'Soles (PEN)' ? 'S/' : 'US\$';
    final money = (double value) => '$simbolo ${value.toStringAsFixed(2)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 28),
        header: (_) => _pdfHeader(logo),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'ELCOPE • Cotización $numero • Página ${ctx.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 8),
          _pdfClientBlock(),
          pw.SizedBox(height: 12),
          _pdfConditionsBlock(),
          pw.SizedBox(height: 12),
          pw.Text(
            'DETALLE DE PRODUCTOS',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF075C36),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              '#',
              'Código',
              'Descripción',
              'Cant.',
              'P. Unit.',
              'Dscto.',
              'Total',
            ],
            data: lineas.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final p = entry.value;
              final cantidad = (p['cantidad'] as num?)?.toDouble() ?? 0;
              final precio = (p['precio_unitario'] as num?)?.toDouble() ?? 0;
              final dscto = (p['descuento_porcentaje'] as num?)?.toDouble() ?? 0;
              final totalLinea = (p['total'] as num?)?.toDouble() ?? 0;
              return [
                '$i',
                '${p['codigo'] ?? ''}',
                '${p['descripcion'] ?? ''}\n${p['presentacion'] ?? ''}',
                cantidad.toStringAsFixed(
                  cantidad == cantidad.roundToDouble() ? 0 : 2,
                ),
                money(precio),
                '${dscto.toStringAsFixed(2)} %',
                money(totalLinea),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF087A45),
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.2),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFD9E2DC),
              width: .5,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(20),
              1: pw.FixedColumnWidth(78),
              2: pw.FlexColumnWidth(5.0),
              3: pw.FixedColumnWidth(42),
              4: pw.FixedColumnWidth(68),
              5: pw.FixedColumnWidth(52),
              6: pw.FixedColumnWidth(70),
            },
            cellAlignments: const {
              0: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFF8E7),
                    border: pw.Border.all(
                      color: PdfColor.fromInt(0xFFE7C76A),
                    ),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFB45309),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'IMPORTANTE',
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 7),
                          pw.Text(
                            'Condición de precios',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(0xFF7C4A03),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Nuestros precios están sujetos al precio del cobre en el mercado '
                        'internacional (LME). La cotización puede presentar una variación '
                        'de ±5% de acuerdo con las condiciones del mercado.',
                        style: const pw.TextStyle(
                          fontSize: 7.4,
                          color: PdfColor.fromInt(0xFF5B4636),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.SizedBox(
                width: 185,
                child: pw.Column(
                  children: [
                    _pdfTotalRow('Subtotal', subtotal, money),
                    if (descuento > 0)
                      _pdfTotalRow('Descuento', descuento, money),
                    _pdfTotalRow('IGV (18%)', igv, money),
                    pw.Divider(color: PdfColors.grey400),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE8F7EE),
                        border: pw.Border.all(
                          color: PdfColor.fromInt(0xFFB9DEC9),
                        ),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.Text(
                            money(total),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              color: PdfColor.fromInt(0xFF087A45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Documento emitido por ELCOPE • Cotización comercial sujeta a las condiciones indicadas.',
            style: const pw.TextStyle(
              fontSize: 6.8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(30, 22, 30, 24),
        header: (_) => _pdfConditionsHeader(logo),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                color: PdfColor.fromInt(0xFFD9E2DC),
                width: .6,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Calle las Camelias Mz. D Lote 5 - Pachacamac - Lima - Perú',
                style: const pw.TextStyle(fontSize: 6.5),
              ),
              pw.Text(
                'Central: (511) 660-2652  •  ventas@elcope.com.pe',
                style: const pw.TextStyle(fontSize: 6.5),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 7),
          pw.SizedBox(height: 9),
          _condicionesSeccion('I. PRECIO', [
            'a. Precio ofertado es ${moneda == 'Soles (PEN)' ? 'soles' : 'dólares americanos'} y no incluyen IGV.',
            if (moneda == 'Soles (PEN)') 'Tipo de cambio aplicado: S/ ${tipoCambio.toStringAsFixed(4)} por US\$ 1.00 (ingresado manualmente para esta cotización).',
            'b. Los precios son válidos por la cantidad y productos indicados en la presente cotización, por el plazo de $validez días. Cualquier variación en la cantidad debe ser revisada por el asesor comercial para efectuar una nueva cotización.',
            'c. Los precios cotizados no consideran transporte fuera de Lima Metropolitana y Callao, certificado de calidad externa, pruebas adicionales a las ofrecidas, costo de inspectores, penalidades u otro tipo de costo que no esté claramente indicado en nuestra oferta.',
            if (moneda == 'Soles (PEN)') '* El tipo de cambio aplicado es manual y corresponde al valor ingresado para esta cotización.',
          ]),
          _condicionesSeccion('II. ORDEN DE COMPRA', [
            'a. La orden de compra debe ser emitida a nombre de ELECTRO CONDUCTORES PERUANOS S.A.C. R.U.C.: 20117330347.',
            'b. La descripción y cantidad del producto debe ser igual a la que aparece en la cotización.',
            'c. El monto mínimo para despacho dentro de Lima Metropolitana y Callao es de \$USD. 2,500.00 + IGV.',
            'd. La orden de compra es un contrato entre partes, no puede ser sujeto a anulación.',
            'e. Queda establecido que los metrajes solicitados tendrán una tolerancia de ±5% que será aceptada por el cliente.',
          ]),
          _condicionesSeccion('III. PLAZO DE ENTREGA', [
            'a. El plazo de entrega será confirmado y/o modificado dos (02) días después de recibir la OC, en función a la capacidad de la fábrica.',
            'b. Horario de atención para despacho en fábrica: Lunes a viernes: 9:00 a.m. a 01:00 p.m. y 2:00 p.m. a 6:00 p.m.',
          ]),
          _condicionesSeccion('IV. EMBALAJE', [
            'a. La presentación y empaque estándar es en carretes de madera y rollos de 100 metros (según características del producto).',
            'b. En el caso de solicitar productos en metros debe ser previamente confirmado por el asesor comercial, en la cotización.',
            'c. Si el cliente no expresa en la orden de compra presentación y empaque, nuestra empresa entregará el producto según su criterio.',
          ]),
          _condicionesSeccion('V. PRUEBAS Y CERTIFICADO', [
            'a. Nuestra empresa realiza regularmente pruebas de calidad que están incluidas en el precio, los cuales se entregarán junto con los productos, en la fecha de despacho confirmada.',
            'b. Pruebas de muestreo, inspecciones y certificaciones realizadas por laboratorios externos se cotizará aparte.',
            'c. Todos los requerimientos especiales deben ser solicitados al asesor comercial previo a la emisión de su orden de compra.',
          ]),
          _condicionesSeccion('VI. GARANTÍAS', [
            'a. La garantía de los cables fabricados por nosotros es de 5 años, desde la fecha de entrega del producto.',
            'b. Nuestra garantía solo cubre defectos de fabricación, previamente evaluados y en coordinación con el cliente. En el caso de ser devuelto, el lugar de entrega es el lugar pactado según la descripción de la orden de compra emitida por el cliente y confirmado por el asesor comercial.',
            'c. Nuestra empresa no es responsable por los costos de instalación, remoción, reemplazo y/o pérdidas de cualquier índole, como consecuencia del reemplazo de los cables.',
          ]),
          _condicionesSeccion('VII. LUGAR DE ENTREGA', [
            'a. Almacenes o agencia de transporte designada por el cliente dentro de Lima Metropolitana y Callao.',
          ]),
          pw.SizedBox(height: 4),
          _condicionesSeccion('ACUERDOS COMERCIALES', [
            'Nuestros precios están sujetos al precio del cobre en el mercado internacional (LME), en caso este precio suba en 3% o más, habrá un reajuste en el valor de la cotización.',
            'Tolerancia de metrajes solicitados: ±5%, aceptada por el cliente.',
          ]),
          pw.SizedBox(height: 8),
          _bancosBlock(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfHeader(pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 9),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFF087A45),
            width: 1.2,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 82,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 72,
                    height: 48,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(width: 72, height: 48),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ELABORACIÓN DE COBRE PERUANO',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.2),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 17),
                pw.Text(
                  'COTIZACIÓN COMERCIAL',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF087A45),
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                numero,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfConditionsHeader(pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 9),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFF087A45),
            width: 1.2,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 82,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 72,
                    height: 48,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(width: 72, height: 48),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ELABORACIÓN DE COBRE PERUANO',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.2),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 12),
                pw.Text(
                  'CONDICIONES COMERCIALES',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF075C36),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Cotización $numero',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  pw.Widget _condicionesSeccion(String titulo, List<String> items) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColor.fromInt(0xFFD9E2DC),
          width: .7,
        ),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEAF6EF),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 8.2,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF075C36),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          ...items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Text(
                item,
                style: const pw.TextStyle(
                  fontSize: 6.8,
                  color: PdfColors.grey800,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _bancosBlock() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD9E2DC)),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DATOS BANCARIOS',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF075C36),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  _banco('BCP', 'Dólares: 0011-0377-0100012562',
                      'CCI: 00110377-010001256293'),
                  _banco('BCP', 'Soles: 0011-0377-0100012570',
                      'CCI: 01137700010001257096'),
                  _banco('BBVA', 'Dólares: 193-0860175-1-45',
                      'CCI: 00219300086017514519'),
                ],
              ),
              pw.TableRow(
                children: [
                  _banco('BBVA', 'Soles: 193-0808938-0-89',
                      'CCI: 00219300080893808916'),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _banco(String banco, String cuenta, String cci) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            banco,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 1),
          pw.Text(cuenta, style: const pw.TextStyle(fontSize: 6.1)),
          pw.Text(cci, style: const pw.TextStyle(fontSize: 6.1)),
        ],
      ),
    );
  }

  pw.Widget _pdfClientBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF4FAF6),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD9E2DC)),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DATOS DEL CLIENTE',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF075C36),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            cliente.razonSocial,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'RUC: ${cliente.ruc}    •    Vendedor: ${cliente.vendedor}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            cliente.direccion.isEmpty ? 'Dirección: -' : cliente.direccion,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfConditionsBlock() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColor.fromInt(0xFFD4E0DA),
          width: .8,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CONDICIONES COMERCIALES',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF075C36),
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Row(
            children: [
              pw.Expanded(child: _pdfDato('Moneda', moneda)),
              if (moneda == 'Soles (PEN)') ...[
                pw.Container(
                  width: .7,
                  height: 28,
                  color: PdfColor.fromInt(0xFFD9E2DC),
                ),
                pw.Expanded(
                  child: _pdfDato('Tipo de cambio', 'S/ ${tipoCambio.toStringAsFixed(4)}'),
                ),
              ],
              pw.Container(
                width: .7,
                height: 28,
                color: PdfColor.fromInt(0xFFD9E2DC),
              ),
              pw.Expanded(child: _pdfDato('Forma de pago', formaPago)),
              pw.Container(
                width: .7,
                height: 28,
                color: PdfColor.fromInt(0xFFD9E2DC),
              ),
              pw.Expanded(child: _pdfDato('Lugar de entrega', lugarEntrega)),
              pw.Container(
                width: .7,
                height: 28,
                color: PdfColor.fromInt(0xFFD9E2DC),
              ),
              pw.Expanded(child: _pdfDato('Plazo de entrega', plazoEntrega)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfDato(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 6.8,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfTotalRow(
    String label,
    double value,
    String Function(double) money,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            money(value),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vista previa • $numero'),
        actions: [
          IconButton(
            tooltip: 'Imprimir',
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (format) => _buildPdf(format),
                name: '$numero.pdf',
              );
            },
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: PdfPreview(
        build: _buildPdf,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '$numero.pdf',
      ),
    );
  }
}
