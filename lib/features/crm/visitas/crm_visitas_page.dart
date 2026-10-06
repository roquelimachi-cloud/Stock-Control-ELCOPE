import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../services/sesion.dart';
import '../../../services/supabase/supabase_service.dart';

class CrmVisitasNotificaciones {
  CrmVisitasNotificaciones._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Lima'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linux = LinuxInitializationSettings(
      defaultActionName: 'Abrir',
    );
    const windows = WindowsInitializationSettings(
      appName: 'Stock Control ELCOPE',
      appUserModelId: 'com.elcope.stockcontrol',
      guid: '8f9e3e1c-3a4d-4e1d-8f8e-0b6c7d2a4f11',
    );

    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {},
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _inicializado = true;
  }

  static int _id(int visitaId, int tipo) => visitaId * 10 + tipo;

  static Future<void> programar({
    required int visitaId,
    required String cliente,
    required DateTime fechaHora,
    int minutosRecordatorio = 30,
  }) async {
    await inicializar();

    final ahora = DateTime.now();
    if (!fechaHora.isAfter(ahora)) return;

    await cancelar(visitaId);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'crm_visitas',
        'Visitas comerciales',
        channelDescription: 'Recordatorios de visitas comerciales ELCOPE',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    final fechaLocal = tz.TZDateTime.from(fechaHora, tz.local);

    final aviso = fechaLocal.subtract(Duration(minutes: minutosRecordatorio));
    if (aviso.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        id: _id(visitaId, 1),
        title: '🔔 Visita en $minutosRecordatorio minutos',
        body: 'Cliente: $cliente',
        scheduledDate: aviso,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'visita:$visitaId',
      );
    }

    await _plugin.zonedSchedule(
      id: _id(visitaId, 2),
      title: '📍 Visita programada',
      body: 'Es hora de tu visita a $cliente',
      scheduledDate: fechaLocal,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'visita:$visitaId',
    );
  }

  static Future<void> cancelar(int visitaId) async {
    if (!_inicializado) return;
    await _plugin.cancel(id: _id(visitaId, 1));
    await _plugin.cancel(id: _id(visitaId, 2));
  }
}

class CrmVisitasPage extends StatefulWidget {
  const CrmVisitasPage({super.key});

  @override
  State<CrmVisitasPage> createState() => _CrmVisitasPageState();
}

class _CrmVisitasPageState extends State<CrmVisitasPage> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1468A8);
  static const _verde = Color(0xFF0A9B61);
  static const _naranja = Color(0xFFF59E0B);
  static const _rojo = Color(0xFFE5484D);
  static const _fondo = Color(0xFFF4F7FA);

  final _db = SupabaseService.client;
  final _buscarController = TextEditingController();
  final _fecha = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _visitas = [];
  List<Map<String, dynamic>> _clientes = [];
  final Map<String, String> _clientesVisitasPrivilegiados = {};
  List<String> _vendedoresPermitidos = [];

  String _vendedor = 'TODOS';
  String _estado = 'TODOS';
  DateTimeRange? _rango;

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';

  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }

  /// La geolocalización visible en la vista previa está restringida
  /// exclusivamente a Jefatura y Gerencia.
  bool get _puedeVerGeolocalizacion {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol.contains('gerencia') || rol.contains('jefe');
  }

  String get _vendedorActual =>
      Sesion.vendedor.trim().isNotEmpty
          ? Sesion.vendedor.trim()
          : Sesion.nombre.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inicializar();
    });
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  String _clienteCodigo(Map<String, dynamic> c) {
    for (final key in ['codigo', 'codigo_cliente', 'ruc', 'numero_documento', 'documento']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _clienteNombre(Map<String, dynamic> c) {
    for (final key in ['razon_social', 'nombre', 'cliente', 'nombre_cliente']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Cliente sin nombre';
  }

  bool _clienteCoincide(Map<String, dynamic> c, String identificador) {
    final buscado = identificador.trim().toLowerCase();
    if (buscado.isEmpty) return false;

    const campos = [
      'codigo',
      'codigo_cliente',
      'ruc',
      'numero_documento',
      'documento',
    ];

    for (final campo in campos) {
      final valor = _s(c[campo]).toLowerCase();
      if (valor.isNotEmpty && valor == buscado) return true;
    }

    return false;
  }

  String _normalizarIdentificador(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
        .toLowerCase();
  }

  String _nombreClientePorCodigo(String codigo) {
    final identificador = codigo.trim();
    if (identificador.isEmpty) return 'Cliente sin nombre';

    final directo = _clientesVisitasPrivilegiados[
      _normalizarIdentificador(identificador)
    ];
    if (directo != null && directo.isNotEmpty) return directo;

    final found = _clientes.where(
      (c) => _clienteCoincide(c, identificador),
    );

    if (found.isNotEmpty) return _clienteNombre(found.first);

    final normalizado = _normalizarIdentificador(identificador);
    final foundNormalizado = _clientes.where((c) {
      for (final campo in [
        'codigo',
        'codigo_cliente',
        'ruc',
        'numero_documento',
        'documento',
      ]) {
        if (_normalizarIdentificador(_s(c[campo])) == normalizado) return true;
      }
      return false;
    });

    return foundNormalizado.isNotEmpty
        ? _clienteNombre(foundNormalizado.first)
        : identificador;
  }

  String _nombreClienteDeVisita(Map<String, dynamic> visita) {
    final nombre = _s(visita['cliente_nombre']);
    if (nombre.isNotEmpty) return nombre;
    return _nombreClientePorCodigo(_s(visita['codigo_cliente']));
  }

  Future<void> _resolverNombresVisitas() async {
    if (_visitas.isEmpty) return;

    try {
      final codigos = _visitas
          .map((v) => _s(v['codigo_cliente']))
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();

      if (codigos.isEmpty) return;

      final nombres = <String, String>{};

      final porRuc = await _db
          .from('clientes')
          .select('codigo,ruc,razon_social,nombre')
          .inFilter('ruc', codigos);

      for (final row in (porRuc as List)) {
        final c = Map<String, dynamic>.from(row as Map);
        final nombre = _s(c['razon_social']).isNotEmpty
            ? _s(c['razon_social'])
            : _s(c['nombre']);
        if (nombre.isEmpty) continue;

        final ruc = _s(c['ruc']);
        final codigo = _s(c['codigo']);

        if (ruc.isNotEmpty) {
          nombres[_normalizarIdentificador(ruc)] = nombre;
        }
        if (codigo.isNotEmpty) {
          nombres[_normalizarIdentificador(codigo)] = nombre;
        }
      }

      final porCodigo = await _db
          .from('clientes')
          .select('codigo,ruc,razon_social,nombre')
          .inFilter('codigo', codigos);

      for (final row in (porCodigo as List)) {
        final c = Map<String, dynamic>.from(row as Map);
        final nombre = _s(c['razon_social']).isNotEmpty
            ? _s(c['razon_social'])
            : _s(c['nombre']);
        if (nombre.isEmpty) continue;

        final ruc = _s(c['ruc']);
        final codigo = _s(c['codigo']);

        if (ruc.isNotEmpty) {
          nombres[_normalizarIdentificador(ruc)] = nombre;
        }
        if (codigo.isNotEmpty) {
          nombres[_normalizarIdentificador(codigo)] = nombre;
        }
      }

      for (final visita in _visitas) {
        final nombreRpc = _s(visita['cliente_nombre']);
        if (nombreRpc.isNotEmpty) continue;

        final codigo = _s(visita['codigo_cliente']);
        final nombre = nombres[_normalizarIdentificador(codigo)];

        if (nombre != null && nombre.isNotEmpty) {
          visita['cliente_nombre'] = nombre;
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('No se pudieron resolver las razones sociales: $e');
    }
  }

  Future<void> _cargarPermisos() async {
    if (_esGerencia) {
      _vendedoresPermitidos = [];
      return;
    }

    if (_esJefatura) {
      final data = await _db
          .from('usuario_permisos')
          .select('vendedor, ver_produccion')
          .eq('usuario_jefe_id', Sesion.idUsuario)
          .eq('ver_produccion', true);

      final nombres = <String>{};
      for (final row in (data as List)) {
        final nombre = _s(row['vendedor']);
        if (nombre.isNotEmpty) nombres.add(nombre);
      }
      if (_vendedorActual.isNotEmpty) nombres.add(_vendedorActual);
      _vendedoresPermitidos = nombres.toList()..sort();
      return;
    }

    _vendedoresPermitidos =
        _vendedorActual.isEmpty ? [] : [_vendedorActual];
  }

  Future<void> _cargarClientes() async {
    final vendedores =
        _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos;

    final data = await _db.rpc('crm_obtener_clientes_pagina_v6', params: {
      'p_busqueda': '',
      'p_vendedor': 'TODOS',
      'p_sector': 'TODOS',
      'p_giro': 'TODOS',
      'p_departamento':
          _esJefatura && Sesion.rol.trim().toLowerCase() == 'jefe lima'
              ? 'LIMA'
              : 'TODOS',
      'p_solo_activos': false,
      'p_limit': 5000,
      'p_offset': 0,
      'p_orden': 'CLIENTE_ASC',
      'p_anio': null,
      'p_vendedores_permitidos': vendedores,
    });

    _clientes = List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> _cargarVisitas() async {
    final permitidos =
        _vendedoresPermitidos.isEmpty ? null : _vendedoresPermitidos;

    final data = await _db.rpc('crm_obtener_visitas_con_cliente', params: {
      'p_vendedores_permitidos': permitidos,
      'p_vendedor': _vendedor,
      'p_desde': _rango?.start.toIso8601String().substring(0, 10),
      'p_hasta': _rango?.end.toIso8601String().substring(0, 10),
      'p_estado': _estado,
      'p_busqueda': _buscarController.text.trim(),
    });

    _visitas = List<Map<String, dynamic>>.from(data as List);

    // Complementa la agenda con las coordenadas GPS guardadas en crm_visitas.
    // Se mantiene opcional para que la agenda siga cargando si la migración GPS
    // todavía no fue aplicada en Supabase.
    try {
      final ids = _visitas
          .map((v) => (v['id'] as num?)?.toInt())
          .whereType<int>()
          .toList();

      if (ids.isNotEmpty) {
        final gpsRows = await _db
            .from('crm_visitas')
            .select(
              'id,latitud_inicio,longitud_inicio,precision_inicio,latitud_fin,longitud_fin,precision_fin',
            )
            .inFilter('id', ids);

        final gpsById = <int, Map<String, dynamic>>{
          for (final row in (gpsRows as List))
            if (row['id'] != null)
              (row['id'] as num).toInt(): Map<String, dynamic>.from(row),
        };

        _visitas = _visitas.map((v) {
          final id = (v['id'] as num?)?.toInt();
          final gps = id == null ? null : gpsById[id];
          if (gps == null) return v;
          return {...v, ...gps};
        }).toList();
      }
    } catch (e) {
      debugPrint('No se pudieron cargar coordenadas GPS: $e');
    }
  }

  Future<void> _inicializar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await CrmVisitasNotificaciones.inicializar();
      await _cargarPermisos();
      await _cargarVisitas();
     // await _resolverNombresVisitas();
      await _programarRecordatorios();

      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  DateTime? _fechaHoraVisita(Map<String, dynamic> visita) {
    final fecha = _date(visita['fecha_visita']);
    final horaRaw = _s(visita['hora_programada']);
    if (fecha == null || horaRaw.isEmpty) return null;

    final partes = horaRaw.split(':');
    if (partes.length < 2) return null;

    final hora = int.tryParse(partes[0]) ?? 0;
    final minuto = int.tryParse(partes[1]) ?? 0;
    return DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora,
      minuto,
    );
  }

  Future<void> _programarRecordatorios() async {
    try {
      for (final visita in _visitas) {
        if (_s(visita['estado']) != 'PROGRAMADA') continue;
        final id = (visita['id'] as num?)?.toInt();
        final fechaHora = _fechaHoraVisita(visita);
        if (id == null || fechaHora == null) continue;
        if (!fechaHora.isAfter(DateTime.now())) continue;

        final cliente = _nombreClienteDeVisita(visita);
        await CrmVisitasNotificaciones.programar(
          visitaId: id,
          cliente: cliente,
          fechaHora: fechaHora,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar los recordatorios: $e');
    }
  }

  Future<Position?> _obtenerUbicacion() async {
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activa la ubicación del celular para registrar el GPS.'),
            ),
          );
        }
        return null;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se otorgó permiso de ubicación. La visita continuará sin GPS.'),
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('GPS no disponible: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener GPS: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _guardarGpsInicio(int id, Position position) async {
    await _db.from('crm_visitas').update({
      'latitud_inicio': position.latitude,
      'longitud_inicio': position.longitude,
      'precision_inicio': position.accuracy,
    }).eq('id', id);
  }

  Future<void> _guardarGpsFin(int id, Position position) async {
    await _db.from('crm_visitas').update({
      'latitud_fin': position.latitude,
      'longitud_fin': position.longitude,
      'precision_fin': position.accuracy,
    }).eq('id', id);
  }

  int get _recordatoriosPendientes => _visitas.where((v) {
    if (_s(v['estado']) != 'PROGRAMADA') return false;
    final fechaHora = _fechaHoraVisita(v);
    return fechaHora != null && fechaHora.isAfter(DateTime.now());
  }).length;

  Future<void> _mostrarRecordatorios() async {
    final pendientes = _visitas.where((v) {
      if (_s(v['estado']) != 'PROGRAMADA') return false;
      final fechaHora = _fechaHoraVisita(v);
      return fechaHora != null && fechaHora.isAfter(DateTime.now());
    }).toList()
      ..sort((a, b) {
        final fa = _fechaHoraVisita(a)!;
        final fb = _fechaHoraVisita(b)!;
        return fa.compareTo(fb);
      });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: _azul),
            SizedBox(width: 8),
            Text('Recordatorios de visitas'),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: pendientes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('No tienes visitas programadas pendientes.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: pendientes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final visita = pendientes[index];
                    final fechaHora = _fechaHoraVisita(visita)!;
                    final cliente = _nombreClienteDeVisita(visita);
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.notifications_none),
                      ),
                      title: Text(
                        cliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('dd/MM/yyyy HH:mm').format(fechaHora)} · ${_s(visita['vendedor'])}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _refrescar() async {
    setState(() => _cargando = true);
    try {
      await _cargarVisitas();
      await _resolverNombresVisitas();
      await _programarRecordatorios();
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _nuevaVisita() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NuevaVisitaDialog(
        db: _db,
        clientes: _clientes,
        vendedores: _vendedoresPermitidos,
        vendedorActual: _vendedorActual,
        usuarioId: Sesion.idUsuario,
      ),
    );

    if (resultado == true) await _refrescar();
  }

  Future<void> _iniciarVisita(Map<String, dynamic> visita) async {
        if (_esJefatura) return;
final id = (visita['id'] as num?)?.toInt();
    if (id == null) return;

    try {
      await _db.rpc('crm_iniciar_visita', params: {'p_id': id});

      final position = await _obtenerUbicacion();
      if (position != null) {
        try {
          await _guardarGpsInicio(id, position);
        } catch (e) {
          debugPrint('No se pudo guardar GPS de inicio: $e');
        }
      }

      await CrmVisitasNotificaciones.cancelar(id);
      await _refrescar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la visita: $e')),
      );
    }
  }

  Future<void> _finalizarVisita(Map<String, dynamic> visita) async {
        if (_esJefatura) return;
final id = (visita['id'] as num?)?.toInt();
    if (id == null) return;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FinalizarVisitaDialog(
        db: _db,
        visitaId: id,
      ),
    );

    if (resultado == true) {
      final position = await _obtenerUbicacion();
      if (position != null) {
        try {
          await _guardarGpsFin(id, position);
        } catch (e) {
          debugPrint('No se pudo guardar GPS de fin: $e');
        }
      }

      await CrmVisitasNotificaciones.cancelar(id);
      await _refrescar();
    }
  }

  Future<void> _cancelarVisita(Map<String, dynamic> visita) async {
        if (_esJefatura) return;
final id = (visita['id'] as num?)?.toInt();
    if (id == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cancelar visita',
          style: TextStyle(fontWeight: FontWeight.w900, color: _azul),
        ),
        content: const Text(
          '¿Deseas cancelar esta visita programada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _rojo),
            child: const Text('Cancelar visita'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _db.rpc('crm_cancelar_visita', params: {'p_id': id});
      await CrmVisitasNotificaciones.cancelar(id);
      await _refrescar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: $e')),
      );
    }
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _hora(dynamic value) {
    final raw = _s(value);
    if (raw.isEmpty) return '--:--';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  String _duracion(Map<String, dynamic> v) {
    final inicio = _date(v['inicio_at']);
    final fin = _date(v['fin_at']);

    if (inicio == null || fin == null) return '-';

    final minutos = fin.difference(inicio).inMinutes;
    if (minutos < 60) return '$minutos min';

    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '${horas}h' : '${horas}h ${resto}min';
  }

  int get _total => _visitas.length;

  int get _programadas =>
      _visitas.where((v) => _s(v['estado']) == 'PROGRAMADA').length;

  int get _enCurso =>
      _visitas.where((v) => _s(v['estado']) == 'EN CURSO').length;

  int get _realizadas =>
      _visitas.where((v) => _s(v['estado']) == 'REALIZADA').length;

  int get _canceladas =>
      _visitas.where((v) => _s(v['estado']) == 'CANCELADA').length;

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'REALIZADA':
        return _verde;
      case 'EN CURSO':
        return _azulClaro;
      case 'CANCELADA':
        return _rojo;
      default:
        return _naranja;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _azul,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Regresar',
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        titleSpacing: 4,
        title: const Text(
          'Visitas Comerciales',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Recordatorios',
                  onPressed: _cargando ? null : _mostrarRecordatorios,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (_recordatoriosPendientes > 0)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _rojo,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        _recordatoriosPendientes > 99
                            ? '99+'
                            : '$_recordatoriosPendientes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _refrescar,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _errorView()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  _topBar(),
                  const SizedBox(height: 18),
                  _kpis(),
                  const SizedBox(height: 18),
                  _filtros(),
                  const SizedBox(height: 18),
                  _cargando
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _lista(),
                ],
              ),
      ),
    );
  }

  bool get _puedeImprimirVisitas {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol.contains('gerencia') ||
        rol.contains('jefe') ||
        rol.contains('comercial');
  }

  String _tituloVendedorImpresion() {
    if (_vendedor != 'TODOS') return _vendedor;

    final rol = Sesion.rol.trim().toLowerCase();
    if (rol.contains('gerencia')) return 'Todos los asesores';
    if (rol.contains('jefe') || rol.contains('comercial')) {
      return 'Todos los asesores permitidos';
    }
    return _vendedorActual.isEmpty ? 'Asesor' : _vendedorActual;
  }

  Future<void> _imprimirVisitas() async {
    if (_visitas.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay visitas para imprimir con los filtros actuales.'),
        ),
      );
      return;
    }

    final pdf = pw.Document();
    final vendedorReporte = _tituloVendedorImpresion();
    final estadoReporte = _estado == 'TODOS' ? 'Todos' : _estado;
    final fechaReporte = _rango == null
        ? 'Todas las fechas'
        : '${_fecha.format(_rango!.start)} - ${_fecha.format(_rango!.end)}';

    final filas = _visitas.map((v) {
      final fecha = _date(v['fecha_visita']);
      final cliente = _nombreClienteDeVisita(v);
      return [
        fecha == null ? '-' : _fecha.format(fecha),
        _s(v['hora_programada']).isEmpty ? '-' : _hora(v['hora_programada']),
        cliente,
        _s(v['vendedor']),
        _s(v['motivo']).isEmpty ? '-' : _s(v['motivo']),
        _s(v['estado']),
        _s(v['resultado']).isEmpty ? '-' : _s(v['resultado']),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'ELCOPE — REPORTE DE VISITAS COMERCIALES',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0B3B63'),
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Asesor: $vendedorReporte    |    Estado: $estadoReporte    |    Periodo: $fechaReporte',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Row(
            children: [
              _pdfKpi('Total', '${_visitas.length}'),
              pw.SizedBox(width: 8),
              _pdfKpi('Programadas', '$_programadas'),
              pw.SizedBox(width: 8),
              _pdfKpi('En curso', '$_enCurso'),
              pw.SizedBox(width: 8),
              _pdfKpi('Realizadas', '$_realizadas'),
              pw.SizedBox(width: 8),
              _pdfKpi('Canceladas', '$_canceladas'),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Fecha',
              'Hora',
              'Cliente',
              'Asesor',
              'Motivo',
              'Estado',
              'Resultado',
            ],
            data: filas,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0B3B63'),
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#D9E1E8'),
              width: .5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(.8),
              2: const pw.FlexColumnWidth(2.8),
              3: const pw.FlexColumnWidth(1.8),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(2.5),
            },
          ),
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'ELCOPE_Visitas_${vendedorReporte.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo imprimir: $e')),
      );
    }
  }

  pw.Widget _pdfKpi(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F4F7FA'),
          border: pw.Border.all(
            color: PdfColor.fromHex('#DDE5EC'),
            width: .6,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#0B3B63'),
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Programa, registra y controla las visitas comerciales a tus clientes.',
                style: TextStyle(fontSize: 16, color: Color(0xFF52657A)),
              ),
              SizedBox(height: 4),
              Text(
                'Tu jefe puede revisar visitas por asesor, fecha y estado.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (_puedeImprimirVisitas)
          OutlinedButton.icon(
            onPressed: _cargando || _visitas.isEmpty ? null : _imprimirVisitas,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir'),
          ),
        if (_puedeImprimirVisitas) const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _cargando ? null : _nuevaVisita,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva visita'),
          style: ButtonStyle(
            backgroundColor:
                const WidgetStatePropertyAll(Color(0xFF0A9B61)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpis() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 900;
        final ancho = compacto
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Total visitas', _total, Icons.location_on_outlined,
                _azulClaro, ancho),
            _kpi('Programadas', _programadas, Icons.event_available_outlined,
                _naranja, ancho),
            _kpi('En curso', _enCurso, Icons.play_circle_outline, _azulClaro,
                ancho),
            _kpi('Realizadas', _realizadas, Icons.check_circle_outline,
                _verde, ancho),
          ],
        );
      },
    );
  }

  Widget _kpi(
    String title,
    int value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        height: 104,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E6EC)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71839A),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: _azul,
                      fontWeight: FontWeight.w900,
                      fontSize: 25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    final vendedores = ['TODOS', ..._vendedoresPermitidos];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E6EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _buscarController,
                onSubmitted: (_) => _refrescar(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar cliente, proyecto, motivo...',
                  filled: true,
                  fillColor: const Color(0xFFF4F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _dropdown(
              'Asesor',
              _vendedor,
              vendedores.isEmpty ? ['TODOS'] : vendedores,
              (v) {
                setState(() => _vendedor = v!);
                _refrescar();
              },
            ),
            _dropdown(
              'Estado',
              _estado,
              ['TODOS', 'PROGRAMADA', 'EN CURSO', 'REALIZADA', 'CANCELADA'],
              (v) {
                setState(() => _estado = v!);
                _refrescar();
              },
            ),
            OutlinedButton.icon(
              onPressed: _seleccionarRango,
              icon: const Icon(Icons.date_range),
              label: Text(
                _rango == null
                    ? 'Fecha'
                    : '${_fecha.format(_rango!.start)} - ${_fecha.format(_rango!.end)}',
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _vendedor = 'TODOS';
                  _estado = 'TODOS';
                  _rango = null;
                  _buscarController.clear();
                });
                _refrescar();
              },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Limpiar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final safe = items.contains(value) ? value : items.first;

    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: safe,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF4F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: items
            .toSet()
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
      initialDateRange: _rango,
      locale: const Locale('es'),
    );

    if (rango != null && mounted) {
      setState(() => _rango = rango);
      await _refrescar();
    }
  }

  Widget _lista() {
    if (_visitas.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE0E6EC)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(60),
          child: Column(
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 55,
                color: Colors.grey,
              ),
              SizedBox(height: 12),
              Text(
                'No hay visitas registradas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Programa la primera visita desde “Nueva visita”.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: _azulClaro,
                size: 25,
              ),
              const SizedBox(width: 10),
              const Text(
                'Agenda de visitas',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _azul,
                ),
              ),
              const Spacer(),
              Text(
                '${_visitas.length} registros',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._visitas.map(_tarjetaVisita),
        ],
      ),
    );
  }


  double? _gpsNumero(dynamic value) {
    return double.tryParse(value?.toString() ?? '');
  }

  String _gpsCoordenadas(Map<String, dynamic> v, String momento) {
    final lat = _gpsNumero(v['latitud_$momento']);
    final lon = _gpsNumero(v['longitud_$momento']);
    if (lat == null || lon == null) return 'No registrado';
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  Future<void> _abrirMapaGps(
    double latitud,
    double longitud,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud',
    );

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Google Maps.'),
        ),
      );
    }
  }

  String _texto(dynamic value) {
    final valueText = _s(value);
    return valueText.isEmpty ? 'No registrado' : valueText;
  }

  Widget _filaVistaPrevia(
    String titulo,
    String valor, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: _azulClaro),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 125,
            child: Text(
              titulo,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                color: _azul,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarVistaPrevia(Map<String, dynamic> v) async {
    final codigo = _s(v['codigo_cliente']);
    final cliente = _nombreClienteDeVisita(v);
    final estado = _s(v['estado']).isEmpty ? 'PROGRAMADA' : _s(v['estado']);
    final fecha = _date(v['fecha_visita']);
    final salida = _date(v['salida_at']);
    final fin = _date(v['fin_at']);

    final latInicio = _gpsNumero(v['latitud_inicio']);
    final lonInicio = _gpsNumero(v['longitud_inicio']);
    final latFin = _gpsNumero(v['latitud_fin']);
    final lonFin = _gpsNumero(v['longitud_fin']);

    Widget section(String title, IconData icon, List<Widget> children) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E7EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: _azulClaro),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: _azul,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            ...children,
          ],
        ),
      );
    }

    Widget infoTile(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: _azulClaro),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _azul,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 980,
              maxHeight: 820,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
                  decoration: const BoxDecoration(
                    color: _azul,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.business_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VISTA PREVIA DE VISITA COMERCIAL',
                              style: TextStyle(
                                color: Color(0xFFB9D9F1),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .7,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              cliente,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _chip(estado, _estadoColor(estado)),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF4F7FA),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          section(
                            'Resumen de la visita',
                            Icons.dashboard_outlined,
                            [
                              Row(
                                children: [
                                  infoTile(
                                    'RUC / CÓDIGO',
                                    codigo.isEmpty ? 'No registrado' : codigo,
                                    Icons.badge_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'ASESOR',
                                    _texto(v['vendedor']),
                                    Icons.person_outline,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'FECHA',
                                    fecha == null
                                        ? 'No registrada'
                                        : _fecha.format(fecha),
                                    Icons.calendar_today_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'HORA',
                                    _texto(v['hora_programada']),
                                    Icons.schedule_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          section(
                            'Información comercial',
                            Icons.business_center_outlined,
                            [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  infoTile(
                                    'MOTIVO',
                                    _texto(v['motivo']),
                                    Icons.flag_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'OBJETIVO',
                                    _texto(v['objetivo']),
                                    Icons.track_changes_outlined,
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  infoTile(
                                    'LUGAR / DIRECCIÓN',
                                    _texto(v['lugar']),
                                    Icons.place_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          section(
                            'Contacto',
                            Icons.contact_page_outlined,
                            [
                              Row(
                                children: [
                                  infoTile(
                                    'CONTACTO',
                                    _texto(v['contacto_nombre']),
                                    Icons.person_outline,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'CARGO',
                                    _texto(v['contacto_cargo']),
                                    Icons.badge_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'TELÉFONO',
                                    _texto(v['contacto_telefono']),
                                    Icons.phone_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'CORREO',
                                    _texto(v['contacto_email']),
                                    Icons.email_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          section(
                            'Resultado y seguimiento',
                            Icons.assignment_outlined,
                            [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  infoTile(
                                    'RESULTADO',
                                    _texto(v['resultado']),
                                    Icons.assignment_turned_in_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'PRÓXIMA ACCIÓN',
                                    _texto(v['proxima_accion']),
                                    Icons.next_plan_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'FECHA PRÓXIMA ACCIÓN',
                                    _date(v['fecha_proxima_accion']) == null
                                        ? 'No registrada'
                                        : _fecha.format(
                                            _date(v['fecha_proxima_accion'])!,
                                          ),
                                    Icons.event_outlined,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  infoTile(
                                    'INICIO',
                                    salida == null
                                        ? 'No iniciado'
                                        : DateFormat('dd/MM/yyyy HH:mm')
                                            .format(salida),
                                    Icons.play_circle_outline,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'FIN',
                                    fin == null
                                        ? 'No finalizado'
                                        : DateFormat('dd/MM/yyyy HH:mm')
                                            .format(fin),
                                    Icons.stop_circle_outlined,
                                  ),
                                  const SizedBox(width: 9),
                                  infoTile(
                                    'DURACIÓN',
                                    _duracion(v),
                                    Icons.timer_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_puedeVerGeolocalizacion)
                            section(
                              'Geolocalización de la visita',
                              Icons.location_on_outlined,
                              [
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F7FC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Visible exclusivamente para Jefatura y Gerencia. '
                                    'Las coordenadas corresponden al momento de inicio y finalización.',
                                    style: TextStyle(
                                      color: _azul,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _gpsPanel(
                                        titulo: 'GPS DE INICIO',
                                        coordenadas:
                                            _gpsCoordenadas(v, 'inicio'),
                                        latitud: latInicio,
                                        longitud: lonInicio,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _gpsPanel(
                                        titulo: 'GPS DE FIN',
                                        coordenadas: _gpsCoordenadas(v, 'fin'),
                                        latitud: latFin,
                                        longitud: lonFin,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE0E7EE)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Vista de consulta · Los datos se muestran según los permisos del usuario.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text('Cerrar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _azul,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gpsPanel({
    required String titulo,
    required String coordenadas,
    required double? latitud,
    required double? longitud,
  }) {
    final disponible = latitud != null && longitud != null;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: _azul,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            coordenadas,
            style: const TextStyle(
              color: Color(0xFF52657A),
              fontSize: 11,
            ),
          ),
          if (disponible) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _abrirMapaGps(latitud, longitud),
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('Abrir mapa'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaVisita(Map<String, dynamic> v) {
    final estado = _s(v['estado']).isEmpty ? 'PROGRAMADA' : _s(v['estado']);
    final estadoColor = _estadoColor(estado);
    final fecha = _date(v['fecha_visita']);
    final codigo = _s(v['codigo_cliente']);
    final cliente = _nombreClienteDeVisita(v);
    final vendedor = _s(v['vendedor']);
    final hora = _hora(v['hora_programada']);
    final motivo = _s(v['motivo']);
    final objetivo = _s(v['objetivo']);
    final lugar = _s(v['lugar']);
    final salida = _date(v['salida_at']);
    final fin = _date(v['fin_at']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE1E8EF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 850;

          final fechaBox = Container(
            width: 82,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  fecha == null ? '--' : DateFormat('dd').format(fecha),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: _azul,
                  ),
                ),
                Text(
                  fecha == null ? '--' : DateFormat('MMM').format(fecha).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _azulClaro,
                  ),
                ),
                Text(
                  fecha == null ? '----' : DateFormat('yyyy').format(fecha),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );

          final contenido = Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        cliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _azul,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _chip(estado, estadoColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 18,
                    runSpacing: 5,
                    children: [
                      _dato(Icons.person_outline, vendedor),
                      _dato(Icons.schedule_outlined, hora),
                      if (motivo.isNotEmpty) _dato(Icons.flag_outlined, motivo),
                      if (lugar.isNotEmpty)
                        _dato(Icons.place_outlined, lugar),
                      if (_puedeVerGeolocalizacion &&
                          v['latitud_inicio'] != null)
                        _dato(Icons.gps_fixed, 'GPS inicio'),
                      if (_puedeVerGeolocalizacion &&
                          v['latitud_fin'] != null)
                        _dato(Icons.gps_fixed, 'GPS fin'),
                    ],
                  ),
                  if (objetivo.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Objetivo: $objetivo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF52657A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (salida != null || fin != null) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 16,
                      children: [
                        if (salida != null)
                          Text(
                            'Salida: ${DateFormat('HH:mm').format(salida)}',
                            style: const TextStyle(
                              color: _azulClaro,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (fin != null)
                          Text(
                            'Fin: ${DateFormat('HH:mm').format(fin)} · ${_duracion(v)}',
                            style: const TextStyle(
                              color: _verde,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );

          final acciones = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: [
              if (!_esJefatura && estado == 'PROGRAMADA')
                OutlinedButton.icon(
                  onPressed: () => _iniciarVisita(v),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Iniciar'),
                ),
              if (!_esJefatura && estado == 'EN CURSO')
                FilledButton.icon(
                  onPressed: () => _finalizarVisita(v),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Finalizar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _verde,
                  ),
                ),
              if (!_esJefatura && estado == 'PROGRAMADA')
                IconButton(
                  tooltip: 'Cancelar',
                  onPressed: () => _cancelarVisita(v),
                  icon: const Icon(Icons.close_rounded),
                  color: _rojo,
                ),
            ],
          );

          if (compacto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _mostrarVistaPrevia(v),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      fechaBox,
                      contenido,
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: acciones,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _mostrarVistaPrevia(v),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      fechaBox,
                      contenido,
                    ],
                  ),
                ),
              ),
              SizedBox(width: 240, child: acciones),
            ],
          );
        },
      ),
    );
  }

  Widget _dato(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _azulClaro),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF52657A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          elevation: 0,
          color: const Color(0xFFFFF7F7),
          child: Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: _rojo,
                  size: 55,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No se pudieron cargar las visitas',
                  style: TextStyle(
                    color: _azul,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Error desconocido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _inicializar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NuevaVisitaDialog extends StatefulWidget {
  final dynamic db;
  final List<Map<String, dynamic>> clientes;
  final List<String> vendedores;
  final String vendedorActual;
  final int usuarioId;

  const _NuevaVisitaDialog({
    required this.db,
    required this.clientes,
    required this.vendedores,
    required this.vendedorActual,
    required this.usuarioId,
  });

  @override
  State<_NuevaVisitaDialog> createState() => _NuevaVisitaDialogState();
}

class _NuevaVisitaDialogState extends State<_NuevaVisitaDialog> {
  static const _azul = Color(0xFF0B3B63);
  static const _azulClaro = Color(0xFF1677B8);
  static const _verde = Color(0xFF0A9B61);
  static const _borde = Color(0xFFDCE5ED);
  static const _fondo = Color(0xFFF6F8FB);

  final _buscarCliente = TextEditingController();
  final _motivo = TextEditingController();
  final _objetivo = TextEditingController();
  final _lugar = TextEditingController();
  final _contactoNombre = TextEditingController();
  final _contactoCargo = TextEditingController();
  final _contactoTelefono = TextEditingController();
  final _contactoEmail = TextEditingController();

  String _cliente = '';
  String _vendedor = '';
  String _estadoComercial = 'ACTIVO';
  Map<String, dynamic>? _clienteSeleccionado;
  DateTime _fecha = DateTime.now();
  TimeOfDay? _hora;
  bool _guardando = false;
  bool _buscandoClientes = false;
  int _busquedaVersion = 0;
  List<Map<String, dynamic>> _clientesBusqueda = [];

  final List<String> _estadosComerciales = const [
    'ACTIVO', 'PROSPECTO', 'POTENCIAL', 'INACTIVO', 'SUSPENDIDO',
  ];

  @override
  void initState() {
    super.initState();
    _vendedor = widget.vendedorActual.isNotEmpty
        ? widget.vendedorActual
        : (widget.vendedores.isNotEmpty ? widget.vendedores.first : '');

    // La búsqueda de clientes de visitas consulta TODO el maestro de clientes,
    // no la cartera restringida por vendedor.
    _buscarClientesServidor('');
  }

  Future<void> _buscarClientesServidor(String texto) async {
    final version = ++_busquedaVersion;
    if (mounted) setState(() => _buscandoClientes = true);

    try {
      final data = await widget.db.rpc(
        'crm_buscar_clientes_visita',
        params: {
          'p_busqueda': texto.trim(),
          'p_limit': 30,
        },
      );

      if (!mounted || version != _busquedaVersion) return;

      setState(() {
        _clientesBusqueda = List<Map<String, dynamic>>.from(
          (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _buscandoClientes = false;
      });
    } catch (e) {
      if (!mounted || version != _busquedaVersion) return;

      // Fallback visual con los clientes que ya cargó el padre.
      final q = texto.trim().toLowerCase();
      final fallback = widget.clientes.where((c) {
        if (q.isEmpty) return true;
        return _nombre(c).toLowerCase().contains(q) ||
            _codigo(c).toLowerCase().contains(q);
      }).take(30).toList();

      setState(() {
        _clientesBusqueda = fallback;
        _buscandoClientes = false;
      });
    }
  }

  Future<void> _registrarNuevoCliente() async {
    final nombre = TextEditingController(text: _buscarCliente.text.trim());
    final ruc = TextEditingController();
    final direccion = TextEditingController();
    final giro = TextEditingController();
    final sector = TextEditingController();
    String estado = 'PROSPECTO';

    try {
      final resultado = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              InputDecoration dec(String label, String hint, IconData icon) {
                return InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: _borde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: _borde),
                  ),
                );
              }

              return AlertDialog(
                title: const Text(
                  'Registrar nuevo cliente',
                  style: TextStyle(
                    color: _azul,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nombre,
                          decoration: dec(
                            'Razón social / nombre *',
                            'Ej.: SOLDEX S.A.',
                            Icons.business_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ruc,
                          keyboardType: TextInputType.number,
                          decoration: dec(
                            'RUC',
                            'Opcional',
                            Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: direccion,
                          decoration: dec(
                            'Dirección',
                            'Dirección del cliente',
                            Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: giro,
                                decoration: dec(
                                  'Giro',
                                  'Ej.: Industria',
                                  Icons.category_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: sector,
                                decoration: dec(
                                  'Sector',
                                  'Ej.: Construcción',
                                  Icons.work_outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: estado,
                          isExpanded: true,
                          decoration: dec(
                            'Estado comercial',
                            '',
                            Icons.track_changes_outlined,
                          ),
                          items: _estadosComerciales
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => estado = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _verde),
                    onPressed: () async {
                      if (nombre.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ingresa la razón social o nombre del cliente.',
                            ),
                          ),
                        );
                        return;
                      }

                      try {
                        final data = await widget.db.rpc(
                          'crm_registrar_cliente_visita',
                          params: {
                            'p_nombre': nombre.text.trim(),
                            'p_ruc': ruc.text.trim().isEmpty
                                ? null
                                : ruc.text.trim(),
                            'p_direccion': direccion.text.trim().isEmpty
                                ? null
                                : direccion.text.trim(),
                            'p_departamento': 'LIMA',
                            'p_giro': giro.text.trim().isEmpty
                                ? null
                                : giro.text.trim(),
                            'p_sector': sector.text.trim().isEmpty
                                ? null
                                : sector.text.trim(),
                            'p_estado_comercial': estado,
                            'p_vendedor': _vendedor,
                          },
                        );

                        if (data is List && data.isNotEmpty) {
                          Navigator.pop(
                            ctx,
                            Map<String, dynamic>.from(data.first as Map),
                          );
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'No se pudo registrar el cliente: $e',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Registrar cliente'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (resultado != null && mounted) {
        _seleccionarCliente(resultado);
        await _buscarClientesServidor('');
      }
    } finally {
      nombre.dispose();
      ruc.dispose();
      direccion.dispose();
      giro.dispose();
      sector.dispose();
    }
  }

  @override
  void dispose() {
    _buscarCliente.dispose(); _motivo.dispose(); _objetivo.dispose(); _lugar.dispose();
    _contactoNombre.dispose(); _contactoCargo.dispose(); _contactoTelefono.dispose(); _contactoEmail.dispose();
    super.dispose();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  String _codigo(Map<String, dynamic> c) {
    for (final key in ['codigo', 'codigo_cliente', 'ruc']) {
      final v = _s(c[key]); if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _nombre(Map<String, dynamic> c) {
    for (final key in ['razon_social', 'nombre', 'cliente']) {
      final v = _s(c[key]); if (v.isNotEmpty) return v;
    }
    return 'Cliente sin nombre';
  }

  String _estadoCliente(Map<String, dynamic> c) {
    final e = _s(c['estado_comercial']).toUpperCase();
    if (_estadosComerciales.contains(e)) return e;
    final a = c['activo'];
    if (a is bool) return a ? 'ACTIVO' : 'INACTIVO';
    return _s(a).toLowerCase() == 'false' ? 'INACTIVO' : 'ACTIVO';
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'PROSPECTO': return const Color(0xFF8B5CF6);
      case 'POTENCIAL': return const Color(0xFFF59E0B);
      case 'INACTIVO': return const Color(0xFF64748B);
      case 'SUSPENDIDO': return const Color(0xFFEF4444);
      default: return _verde;
    }
  }

  void _seleccionarCliente(Map<String, dynamic> c) {
    setState(() {
      _clienteSeleccionado = c;
      _cliente = _codigo(c);
      _buscarCliente.text = _nombre(c);
      _estadoComercial = _estadoCliente(c);
      final direccion = _s(c['direccion']);
      if (direccion.isNotEmpty) _lugar.text = direccion;
    });
  }

  InputDecoration _dec(String label, String hint, IconData icon) => InputDecoration(
    labelText: label, hintText: hint, prefixIcon: Icon(icon, size: 20),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _borde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _borde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _azulClaro, width: 1.4)),
  );

  Widget _campo({required String label, required TextEditingController controller, required String hint, required IconData icon, int maxLines=1, TextInputType? keyboardType}) =>
    TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, decoration: _dec(label, hint, icon));

  Widget _seccion(String titulo, IconData icon, Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: _fondo, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borde)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 19, color: _azulClaro), const SizedBox(width: 8), Text(titulo, style: const TextStyle(color: _azul, fontSize: 14, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 12), child,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final q = _buscarCliente.text.trim().toLowerCase();
    final clientes = _clientesBusqueda.isNotEmpty || q.isNotEmpty
        ? _clientesBusqueda.take(30).toList()
        : widget.clientes.take(30).toList();
    final coincidenciaExacta = q.isNotEmpty &&
        clientes.any((x) =>
            _nombre(x).toLowerCase() == q || _codigo(x).toLowerCase() == q);
    final c = _clienteSeleccionado;
    final direccion = c == null ? '' : _s(c['direccion']);
    final giro = c == null ? '' : _s(c['giro']);
    final sector = c == null ? '' : _s(c['sector']);
    final ruc = c == null ? '' : _s(c['ruc']);

    Widget step(int number, String label, IconData icon, bool active) {
      return Expanded(
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active ? _azul : const Color(0xFFE8EEF4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: active ? Colors.white : const Color(0xFF7890A5)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _azul : const Color(0xFF7890A5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (number < 4)
              Container(
                width: 24,
                height: 1,
                color: const Color(0xFFD8E1E9),
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
          ],
        ),
      );
    }

    Widget fieldHeader(String title, String subtitle, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _azulClaro.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _azulClaro, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _azul, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF71839A), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget dateCard({required String title, required String value, required IconData icon, required VoidCallback onTap}) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _borde),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _verde.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _verde, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Color(0xFF71839A), fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _azul, fontSize: 13, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined, size: 17, color: Color(0xFF8AA0B4)),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 820),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: _borde)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _azul,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nueva actividad comercial', style: TextStyle(color: _azul, fontSize: 20, fontWeight: FontWeight.w900)),
                            SizedBox(height: 3),
                            Text('Programa una visita con toda la información necesaria para el seguimiento.', style: TextStyle(color: Color(0xFF71839A), fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: _guardando ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF52657A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    step(1, 'Cliente', Icons.business_outlined, _cliente.isNotEmpty),
                    step(2, 'Agenda', Icons.calendar_month_outlined, _hora != null),
                    step(3, 'Contacto', Icons.contact_phone_outlined, _contactoNombre.text.trim().isNotEmpty),
                    step(4, 'Objetivo', Icons.flag_outlined, _objetivo.text.trim().isNotEmpty),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF5F8FB),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _borde),
                          boxShadow: const [BoxShadow(color: Color(0x0A0B3B63), blurRadius: 10, offset: Offset(0, 3))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fieldHeader('Cliente', 'Busca en todo el maestro de clientes por razón social, nombre, código o RUC.', Icons.business_outlined),
                            TextField(
                              controller: _buscarCliente,
                              onChanged: (value) {
                                setState(() {
                                  _cliente = '';
                                  _clienteSeleccionado = null;
                                });
                                _buscarClientesServidor(value);
                              },
                              decoration: _dec('Buscar cliente *', 'Ej.: STRACON, 20513230843 o razón social', Icons.search).copyWith(
                                suffixIcon: _buscandoClientes
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : (_buscarCliente.text.isNotEmpty
                                        ? IconButton(onPressed: () { _buscarCliente.clear(); setState(() { _cliente = ''; _clienteSeleccionado = null; }); _buscarClientesServidor(''); }, icon: const Icon(Icons.close_rounded))
                                        : null),
                              ),
                            ),
                            if (_cliente.isEmpty && q.isNotEmpty && clientes.isEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFF4D58D)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.person_search_outlined, color: Color(0xFFB7791F)),
                                  const SizedBox(width: 9),
                                  const Expanded(child: Text('No encontramos el cliente. Puedes registrarlo como nuevo prospecto.', style: TextStyle(color: Color(0xFF7A5715), fontWeight: FontWeight.w600, fontSize: 12))),
                                  OutlinedButton.icon(onPressed: _registrarNuevoCliente, icon: const Icon(Icons.person_add_alt_1), label: const Text('Nuevo cliente')),
                                ]),
                              ),
                            if (_cliente.isEmpty && q.isNotEmpty && clientes.isNotEmpty && !coincidenciaExacta)
                              Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(onPressed: _registrarNuevoCliente, icon: const Icon(Icons.person_add_alt_1, size: 18), label: Text('Registrar "$q" como nuevo cliente')))),
                            if (_cliente.isEmpty && clientes.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 190),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _borde), borderRadius: BorderRadius.circular(12)),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: clientes.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final x = clientes[i];
                                    final e = _estadoCliente(x);
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(radius: 17, backgroundColor: _azulClaro.withValues(alpha: .09), child: const Icon(Icons.business_outlined, color: _azulClaro, size: 18)),
                                      title: Text(_nombre(x), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _azul, fontWeight: FontWeight.w800)),
                                      subtitle: Text('${_codigo(x)}  •  $e', style: TextStyle(color: _colorEstado(e), fontWeight: FontWeight.w700, fontSize: 11)),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8AA0B4)),
                                      onTap: () => _seleccionarCliente(x),
                                    );
                                  },
                                ),
                              ),
                            if (c != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(color: const Color(0xFFF3F8FC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCFE0EC))),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.verified_outlined, color: _verde, size: 18), const SizedBox(width: 7), Text(_nombre(c), style: const TextStyle(color: _azul, fontSize: 14, fontWeight: FontWeight.w900))]),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _colorEstado(_estadoComercial).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(_estadoComercial, style: TextStyle(color: _colorEstado(_estadoComercial), fontSize: 10, fontWeight: FontWeight.w900))),
                                    if (ruc.isNotEmpty) Text('RUC $ruc', style: const TextStyle(color: Color(0xFF52657A), fontWeight: FontWeight.w700, fontSize: 11)),
                                    if (giro.isNotEmpty) Text(giro, style: const TextStyle(color: Color(0xFF52657A), fontSize: 11)),
                                    if (sector.isNotEmpty) Text(sector, style: const TextStyle(color: Color(0xFF52657A), fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borde)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                fieldHeader('Agenda', 'Define cuándo se realizará la actividad.', Icons.calendar_month_outlined),
                                Row(children: [
                                  dateCard(title: 'Fecha', value: DateFormat('dd/MM/yyyy').format(_fecha), icon: Icons.calendar_today_outlined, onTap: _seleccionarFecha),
                                  const SizedBox(width: 10),
                                  dateCard(title: 'Hora', value: _hora == null ? 'Seleccionar hora' : _hora!.format(context), icon: Icons.schedule_outlined, onTap: _seleccionarHora),
                                ]),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borde)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                fieldHeader('Responsable', 'Asesor que gestionará la actividad.', Icons.person_pin_outlined),
                                DropdownButtonFormField<String>(
                                  value: _vendedor.isEmpty ? null : _vendedor,
                                  isExpanded: true,
                                  decoration: _dec('Asesor responsable *', 'Selecciona un asesor', Icons.person_outline),
                                  items: (widget.vendedores.isEmpty ? [_vendedor] : widget.vendedores).where((e) => e.isNotEmpty).toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) { if (v != null) setState(() => _vendedor = v); },
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borde)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          fieldHeader('Contacto de la visita', 'Identifica a la persona que atenderá al asesor.', Icons.contact_phone_outlined),
                          LayoutBuilder(builder: (context, cs) {
                            final compact = cs.maxWidth < 700;
                            final n = _campo(label: 'Nombre del contacto *', controller: _contactoNombre, hint: 'Ej.: Juan Pérez', icon: Icons.person_outline);
                            final ca = _campo(label: 'Cargo', controller: _contactoCargo, hint: 'Compras, Ingeniería, Gerencia...', icon: Icons.badge_outlined);
                            final t = _campo(label: 'Teléfono', controller: _contactoTelefono, hint: 'Celular o teléfono', icon: Icons.phone_outlined, keyboardType: TextInputType.phone);
                            final e = _campo(label: 'Correo', controller: _contactoEmail, hint: 'correo@cliente.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress);
                            return compact
                                ? Column(children: [n, const SizedBox(height: 10), ca, const SizedBox(height: 10), t, const SizedBox(height: 10), e])
                                : Column(children: [Row(children: [Expanded(child: n), const SizedBox(width: 10), Expanded(child: ca)]), const SizedBox(height: 10), Row(children: [Expanded(child: t), const SizedBox(width: 10), Expanded(child: e)])]);
                          }),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borde)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          fieldHeader('Objetivo y detalle', 'Define claramente qué se busca conseguir y dónde se realizará.', Icons.flag_outlined),
                          LayoutBuilder(builder: (context, cs) {
                            final compact = cs.maxWidth < 700;
                            final motivo = _campo(label: 'Motivo', controller: _motivo, hint: 'Seguimiento de cotización, prospección, negociación...', icon: Icons.assignment_outlined);
                            final lugar = _campo(label: 'Lugar / dirección', controller: _lugar, hint: direccion.isEmpty ? 'Dirección donde se realizará la visita' : direccion, icon: Icons.place_outlined);
                            return compact
                                ? Column(children: [motivo, const SizedBox(height: 10), lugar])
                                : Row(children: [Expanded(child: motivo), const SizedBox(width: 10), Expanded(child: lugar)]);
                          }),
                          const SizedBox(height: 10),
                          _campo(label: 'Objetivo de la visita', controller: _objetivo, hint: '¿Qué deseas conseguir, revisar o acordar con el cliente?', icon: Icons.flag_circle_outlined, maxLines: 3),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borde)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          fieldHeader('Clasificación comercial', 'Actualiza el estado de la relación comercial del cliente.', Icons.track_changes_outlined),
                          DropdownButtonFormField<String>(
                            value: _estadoComercial,
                            isExpanded: true,
                            decoration: _dec('Estado comercial', 'Selecciona el estado', Icons.sell_outlined),
                            items: _estadosComerciales.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) { if (v != null) setState(() => _estadoComercial = v); },
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _borde)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 17, color: Color(0xFF7890A5)),
                  const SizedBox(width: 7),
                  const Expanded(child: Text('La actividad quedará registrada en el CRM y disponible para seguimiento.', style: TextStyle(color: Color(0xFF71839A), fontSize: 11))),
                  TextButton(onPressed: _guardando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(backgroundColor: _verde, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                    icon: _guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.event_available_outlined),
                    label: const Text('Programar actividad', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Future<void> _seleccionarFecha() async {
    final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime(2035),initialDate:_fecha,locale:const Locale('es'));
    if(d!=null&&mounted)setState(()=>_fecha=d);
  }

  Future<void> _seleccionarHora() async {
    final h=await showTimePicker(context:context,initialTime:_hora??const TimeOfDay(hour:9,minute:0));
    if(h!=null&&mounted)setState(()=>_hora=h);
  }

  Future<void> _guardar() async {
    if(_cliente.isEmpty||_vendedor.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Selecciona cliente y asesor.')));return;}
    if(_contactoNombre.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Registra el nombre del contacto de la visita.')));return;}
    setState(()=>_guardando=true);
    try {
      await widget.db.rpc('crm_actualizar_estado_comercial_cliente',params:{'p_codigo_cliente':_cliente,'p_estado_comercial':_estadoComercial});
      final data=await widget.db.rpc('crm_registrar_visita',params:{
        'p_codigo_cliente':_cliente,'p_vendedor':_vendedor,'p_usuario_id':widget.usuarioId,
        'p_fecha_visita':DateFormat('yyyy-MM-dd').format(_fecha),
        'p_hora_programada':_hora==null?null:'${_hora!.hour.toString().padLeft(2,'0')}:${_hora!.minute.toString().padLeft(2,'0')}:00',
        'p_motivo':_motivo.text.trim(),'p_objetivo':_objetivo.text.trim(),'p_lugar':_lugar.text.trim(),
        'p_contacto_nombre':_contactoNombre.text.trim(),'p_contacto_cargo':_contactoCargo.text.trim(),
        'p_contacto_telefono':_contactoTelefono.text.trim(),'p_contacto_email':_contactoEmail.text.trim(),
      });
      int? visitaId;
      if(data is num) visitaId=data.toInt(); else if(data is List&&data.isNotEmpty){final first=data.first;if(first is num)visitaId=first.toInt();else if(first is Map)visitaId=int.tryParse(first['id']?.toString()??'');} else if(data is Map) visitaId=int.tryParse(data['id']?.toString()??'');
      if(visitaId!=null&&_hora!=null){final fechaHora=DateTime(_fecha.year,_fecha.month,_fecha.day,_hora!.hour,_hora!.minute);await CrmVisitasNotificaciones.programar(visitaId:visitaId,cliente:_buscarCliente.text.trim(),fechaHora:fechaHora);}
      if(mounted)Navigator.pop(context,true);
    } catch(e){if(!mounted)return;setState(()=>_guardando=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se pudo programar la visita: $e')));}
  }
}

class _FinalizarVisitaDialog extends StatefulWidget {
  final dynamic db;
  final int visitaId;

  const _FinalizarVisitaDialog({
    required this.db,
    required this.visitaId,
  });

  @override
  State<_FinalizarVisitaDialog> createState() => _FinalizarVisitaDialogState();
}

class _FinalizarVisitaDialogState extends State<_FinalizarVisitaDialog> {
  final _resultado = TextEditingController();
  final _proxima = TextEditingController();

  DateTime? _fechaProxima;
  bool _guardando = false;

  @override
  void dispose() {
    _resultado.dispose();
    _proxima.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Finalizar visita',
        style: TextStyle(
          color: Color(0xFF0B3B63),
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _resultado,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Resultado de la visita',
                  hintText: '¿Qué ocurrió? ¿Qué acordó el cliente?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proxima,
                decoration: const InputDecoration(
                  labelText: 'Próxima acción',
                  hintText: 'Ej.: Enviar nueva cotización',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fechaProxima == null
                          ? 'Sin fecha de próxima acción'
                          : 'Próxima acción: ${DateFormat('dd/MM/yyyy').format(_fechaProxima!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _seleccionarFecha,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Fecha'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0A9B61),
          ),
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Finalizar visita'),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _fechaProxima ?? DateTime.now(),
      locale: const Locale('es'),
    );
    if (d != null && mounted) setState(() => _fechaProxima = d);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);

    try {
      await widget.db.rpc('crm_finalizar_visita', params: {
        'p_id': widget.visitaId,
        'p_resultado': _resultado.text.trim(),
        'p_proxima_accion': _proxima.text.trim(),
        'p_fecha_proxima_accion':
            _fechaProxima == null
                ? null
                : DateFormat('yyyy-MM-dd').format(_fechaProxima!),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo finalizar la visita: $e')),
      );
    }
  }
}
