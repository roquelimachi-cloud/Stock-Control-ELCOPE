import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

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
  List<String> _vendedoresPermitidos = [];

  String _vendedor = 'TODOS';
  String _estado = 'TODOS';
  DateTimeRange? _rango;

  bool get _esGerencia => Sesion.rol.trim().toLowerCase() == 'gerencia';

  bool get _esJefatura {
    final rol = Sesion.rol.trim().toLowerCase();
    return rol == 'jefe lima' || rol == 'jefe provincia';
  }

  String get _vendedorActual =>
      Sesion.vendedor.trim().isNotEmpty
          ? Sesion.vendedor.trim()
          : Sesion.nombre.trim();

  String _normalizarNombre(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Solo el asesor propietario de la visita puede ejecutarla.
  /// Jefatura y gerencia tienen permisos de supervisión, no de ejecución.
  bool _puedeGestionarVisita(Map<String, dynamic> visita) {
    if (_esGerencia || _esJefatura) return false;

    final usuarioVisita = (visita['usuario_id'] as num?)?.toInt();
    if (usuarioVisita != null && usuarioVisita > 0 && Sesion.idUsuario > 0) {
      return usuarioVisita == Sesion.idUsuario;
    }

    final vendedorVisita = _normalizarNombre(_s(visita['vendedor']));
    final vendedorActual = _normalizarNombre(_vendedorActual);
    return vendedorVisita.isNotEmpty &&
        vendedorActual.isNotEmpty &&
        vendedorVisita == vendedorActual;
  }

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
    for (final key in ['codigo', 'codigo_cliente', 'ruc']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _clienteNombre(Map<String, dynamic> c) {
    for (final key in ['razon_social', 'nombre', 'cliente']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Cliente sin nombre';
  }

  String _nombreClientePorCodigo(String codigo) {
    final found = _clientes.where(
      (c) => _clienteCodigo(c).toLowerCase() == codigo.toLowerCase(),
    );
    return found.isEmpty ? codigo : _clienteNombre(found.first);
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
      'p_solo_activos': true,
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

    final data = await _db.rpc('crm_obtener_visitas', params: {
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
      await _cargarClientes();
      await _cargarVisitas();
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

        final cliente = _nombreClientePorCodigo(_s(visita['codigo_cliente']));
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

  Future<Position?> _obtenerUbicacion({int reintentos = 2}) async {
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activa la ubicación del dispositivo para registrar el GPS.'),
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
              content: Text(
                'No se otorgó permiso de ubicación. La visita continuará sin GPS.',
              ),
            ),
          );
        }
        return null;
      }

      // Primero intentamos una ubicación reciente. Esto ayuda cuando el GPS
      // todavía está tomando señal al momento exacto de iniciar la visita.
      try {
        final ultima = await Geolocator.getLastKnownPosition();
        if (ultima != null && ultima.accuracy <= 100) {
          return ultima;
        }
      } catch (_) {}

      Object? ultimoError;
      for (var intento = 1; intento <= reintentos; intento++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            ),
          );

          if (position.accuracy <= 100 || intento == reintentos) {
            return position;
          }
        } catch (e) {
          ultimoError = e;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted && ultimoError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener GPS: $ultimoError')),
        );
      }
      return null;
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

  Future<void> _abrirGoogleMaps(double latitud, double longitud) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud',
    );

    try {
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!abierto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el mapa: $e')),
        );
      }
    }
  }

  Future<void> _verUbicacion(Map<String, dynamic> visita) async {
    final latInicio = _numeroDouble(visita['latitud_inicio']);
    final lonInicio = _numeroDouble(visita['longitud_inicio']);
    final precisionInicio = _numeroDouble(visita['precision_inicio']);
    final latFin = _numeroDouble(visita['latitud_fin']);
    final lonFin = _numeroDouble(visita['longitud_fin']);
    final precisionFin = _numeroDouble(visita['precision_fin']);

    final tieneInicio = latInicio != null && lonInicio != null;
    final tieneFin = latFin != null && lonFin != null;

    if (!tieneInicio && !tieneFin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta visita todavía no tiene coordenadas GPS.')),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.location_on_outlined, color: _azul),
              SizedBox(width: 8),
              Text('Ubicación de la visita'),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreClientePorCodigo(_s(visita['codigo_cliente'])),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _azul,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Asesor: ${_s(visita['vendedor'])}'),
                const SizedBox(height: 18),
                if (tieneInicio)
                  _filaUbicacion(
                    titulo: '📍 Inicio de visita',
                    latitud: latInicio!,
                    longitud: lonInicio!,
                    precision: precisionInicio,
                    onMap: () => _abrirGoogleMaps(latInicio, lonInicio),
                  ),
                if (tieneInicio && tieneFin) const Divider(height: 24),
                if (tieneFin)
                  _filaUbicacion(
                    titulo: '🏁 Fin de visita',
                    latitud: latFin!,
                    longitud: lonFin!,
                    precision: precisionFin,
                    onMap: () => _abrirGoogleMaps(latFin, lonFin),
                  ),
                if (!tieneInicio) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Inicio: GPS no registrado.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 18),
                if (tieneFin)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _abrirGoogleMaps(latFin!, lonFin!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Abrir ubicación final en Google Maps'),
                      style: FilledButton.styleFrom(backgroundColor: _azul),
                    ),
                  )
                else if (tieneInicio)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _abrirGoogleMaps(latInicio!, lonInicio!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Abrir ubicación inicial en Google Maps'),
                      style: FilledButton.styleFrom(backgroundColor: _azul),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _filaUbicacion({
    required String titulo,
    required double latitud,
    required double longitud,
    required double? precision,
    required VoidCallback onMap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE5ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _azul),
          ),
          const SizedBox(height: 6),
          Text('Latitud: ${latitud.toStringAsFixed(7)}'),
          Text('Longitud: ${longitud.toStringAsFixed(7)}'),
          Text(
            precision == null
                ? 'Precisión: no disponible'
                : 'Precisión: ${precision.toStringAsFixed(1)} m',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onMap,
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Ver en mapa'),
          ),
        ],
      ),
    );
  }

  double? _numeroDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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
                    final cliente = _nombreClientePorCodigo(
                      _s(visita['codigo_cliente']),
                    );
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
    if (!_puedeGestionarVisita(visita)) return;
    final id = (visita['id'] as num?)?.toInt();
    if (id == null) return;

    try {
      // Capturamos el GPS antes de cambiar el estado para aprovechar la primera
      // lectura disponible del dispositivo y evitar que el inicio quede en NULL.
      final position = await _obtenerUbicacion(reintentos: 2);

      await _db.rpc('crm_iniciar_visita', params: {'p_id': id});

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
    if (!_puedeGestionarVisita(visita)) return;
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
    if (!_puedeGestionarVisita(visita)) return;
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contenido = ListView(
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
            );

            if (_error != null) return _errorView();

            // Evita que el contenido se comprima hasta una columna de una sola
            // letra cuando la ventana/panel queda demasiado estrecho.
            // En pantallas normales ocupa todo el ancho disponible.
            if (constraints.maxWidth < 900) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1000,
                  height: constraints.maxHeight,
                  child: contenido,
                ),
              );
            }

            return contenido;
          },
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
      final cliente = _nombreClientePorCodigo(_s(v['codigo_cliente']));
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

  Widget _tarjetaVisita(Map<String, dynamic> v) {
    final estado = _s(v['estado']).isEmpty ? 'PROGRAMADA' : _s(v['estado']);
    final estadoColor = _estadoColor(estado);
    final fecha = _date(v['fecha_visita']);
    final codigo = _s(v['codigo_cliente']);
    final cliente = _nombreClientePorCodigo(codigo);
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
                      if (v['latitud_inicio'] != null || v['latitud_fin'] != null)
                        TextButton.icon(
                          onPressed: () => _verUbicacion(v),
                          icon: const Icon(Icons.location_on_outlined, size: 17),
                          label: const Text('Ver ubicación'),
                          style: TextButton.styleFrom(
                            foregroundColor: _azulClaro,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
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

          final puedeGestionar = _puedeGestionarVisita(v);

          final acciones = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: [
              if (puedeGestionar && estado == 'PROGRAMADA')
                OutlinedButton.icon(
                  onPressed: () => _iniciarVisita(v),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Iniciar'),
                ),
              if (puedeGestionar && estado == 'EN CURSO')
                FilledButton.icon(
                  onPressed: () => _finalizarVisita(v),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Finalizar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _verde,
                  ),
                ),
              if (puedeGestionar && estado == 'PROGRAMADA')
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fechaBox,
                    contenido,
                  ],
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
              fechaBox,
              contenido,
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
  static const _verde = Color(0xFF0A9B61);

  final _buscarCliente = TextEditingController();
  final _motivo = TextEditingController();
  final _objetivo = TextEditingController();
  final _lugar = TextEditingController();

  String _cliente = '';
  String _vendedor = '';
  DateTime _fecha = DateTime.now();
  TimeOfDay? _hora;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _vendedor = widget.vendedorActual.isNotEmpty
        ? widget.vendedorActual
        : (widget.vendedores.isNotEmpty ? widget.vendedores.first : '');
  }

  @override
  void dispose() {
    _buscarCliente.dispose();
    _motivo.dispose();
    _objetivo.dispose();
    _lugar.dispose();
    super.dispose();
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  String _codigo(Map<String, dynamic> c) {
    for (final key in ['codigo', 'codigo_cliente', 'ruc']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _nombre(Map<String, dynamic> c) {
    for (final key in ['razon_social', 'nombre', 'cliente']) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Cliente sin nombre';
  }

  String _direccion(Map<String, dynamic> c) {
    for (final key in [
      'direccion',
      'dirección',
      'domicilio',
      'direccion_fiscal',
      'direccion_cliente',
    ]) {
      final value = _s(c[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final q = _buscarCliente.text.trim().toLowerCase();

    final clientes = widget.clientes.where((c) {
      if (q.isEmpty) return true;
      return _nombre(c).toLowerCase().contains(q) ||
          _codigo(c).toLowerCase().contains(q);
    }).take(20).toList();

    return AlertDialog(
      title: const Text(
        'Nueva visita comercial',
        style: TextStyle(
          color: _azul,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _buscarCliente,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Buscar cliente *',
                  hintText: 'Razón social, nombre o RUC',
                  prefixIcon: const Icon(Icons.business_outlined),
                  suffixIcon: _cliente.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              _cliente = '';
                              _buscarCliente.clear();
                            });
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              ),
              if (_cliente.isEmpty && clientes.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 210),
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E6EC)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: clientes.length,
                    itemBuilder: (_, i) {
                      final c = clientes[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.business_outlined,
                          color: _azul,
                        ),
                        title: Text(
                          _nombre(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_codigo(c)),
                        onTap: () {
                          final direccion = _direccion(c);
                          setState(() {
                            _cliente = _codigo(c);
                            _buscarCliente.text = _nombre(c);
                            // Al seleccionar el cliente, cargamos automáticamente
                            // su dirección registrada en el campo Lugar.
                            _lugar.text = direccion;
                          });
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _vendedor.isEmpty ? null : _vendedor,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Asesor *',
                ),
                items: (widget.vendedores.isEmpty
                        ? [_vendedor]
                        : widget.vendedores)
                    .where((e) => e.isNotEmpty)
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
                onChanged: (v) {
                  if (v != null) setState(() => _vendedor = v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarFecha,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(_fecha),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarHora,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        _hora == null
                            ? 'Hora programada'
                            : _hora!.format(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _motivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la visita',
                  hintText: 'Ej.: Presentación de cotización',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _objetivo,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Objetivo',
                  hintText: '¿Qué deseas conseguir en la visita?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lugar,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Lugar / Dirección',
                  hintText: 'Se cargará automáticamente la dirección del cliente',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  helperText: _cliente.isEmpty
                      ? 'Selecciona primero un cliente'
                      : 'Puedes modificar la dirección si la visita será en otro lugar',
                ),
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
          style: FilledButton.styleFrom(backgroundColor: _verde),
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Programar visita'),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _fecha,
      locale: const Locale('es'),
    );
    if (d != null && mounted) setState(() => _fecha = d);
  }

  Future<void> _seleccionarHora() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (h != null && mounted) setState(() => _hora = h);
  }

  Future<void> _guardar() async {
    if (_cliente.isEmpty || _vendedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona cliente y asesor.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final data = await widget.db.rpc('crm_registrar_visita', params: {
        'p_codigo_cliente': _cliente,
        'p_vendedor': _vendedor,
        'p_usuario_id': widget.usuarioId,
        'p_fecha_visita': DateFormat('yyyy-MM-dd').format(_fecha),
        'p_hora_programada': _hora == null
            ? null
            : '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}:00',
        'p_motivo': _motivo.text.trim(),
        'p_objetivo': _objetivo.text.trim(),
        'p_lugar': _lugar.text.trim(),
      });

      int? visitaId;
      if (data is num) {
        visitaId = data.toInt();
      } else if (data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is num) {
          visitaId = first.toInt();
        } else if (first is Map) {
          visitaId = int.tryParse(first['id']?.toString() ?? '');
        }
      } else if (data is Map) {
        visitaId = int.tryParse(data['id']?.toString() ?? '');
      }

      if (visitaId != null) {
        final fechaHora = _hora == null
            ? null
            : DateTime(
                _fecha.year,
                _fecha.month,
                _fecha.day,
                _hora!.hour,
                _hora!.minute,
              );

        if (fechaHora != null) {
          await CrmVisitasNotificaciones.programar(
            visitaId: visitaId,
            cliente: _buscarCliente.text.trim(),
            fechaHora: fechaHora,
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo programar la visita: $e')),
      );
    }
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
