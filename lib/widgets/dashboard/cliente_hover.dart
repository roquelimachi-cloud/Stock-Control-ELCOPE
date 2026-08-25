import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/supabase/dashboard_service.dart';
import 'cliente_popup.dart';

class ClienteHover extends StatefulWidget {
  final String cliente;
  final Widget child;

  const ClienteHover({
    super.key,
    required this.cliente,
    required this.child,
  });

  // =========================================================
  // CERRAR POPUP GLOBAL
  // =========================================================

  static void cerrarPopup() {
    _ClienteHoverState._cerrarPopupGlobal();
  }

  @override
  State<ClienteHover> createState() => _ClienteHoverState();
}

class _ClienteHoverState extends State<ClienteHover> {
  final DashboardService service = DashboardService();

  // =========================================================
  // POPUP ACTUAL
  // =========================================================

  static OverlayEntry? _overlayActual;

  // =========================================================
  // TIMER PARA CIERRE
  // =========================================================

  static Timer? _timerCerrar;

  // =========================================================
  // CONTROL DE SOLICITUDES ASÍNCRONAS
  //
  // Evita que una consulta vieja muestre el popup después
  // de que el mouse ya se fue.
  // =========================================================

  static int _hoverVersion = 0;

  // =========================================================
  // SABER SI EL MOUSE SIGUE SOBRE EL CLIENTE
  // =========================================================

  bool _mouseDentro = false;

  // =========================================================
  // CERRAR POPUP GLOBAL
  // =========================================================

  static void _cerrarPopupGlobal() {
    _timerCerrar?.cancel();
    _timerCerrar = null;

    if (_overlayActual != null) {
      _overlayActual!.remove();
      _overlayActual = null;
    }
  }

  // =========================================================
  // PROGRAMAR CIERRE
  // =========================================================

  void _programarCerrar() {
    _timerCerrar?.cancel();

    final overlay = _overlayActual;

    _timerCerrar = Timer(
      const Duration(milliseconds: 150),
      () {
        if (_overlayActual == overlay) {
          _cerrarPopupGlobal();
        }
      },
    );
  }

  // =========================================================
  // MOSTRAR POPUP
  // =========================================================

  Future<void> mostrar() async {
    // -------------------------------------------------------
    // NUEVA VERSIÓN DEL HOVER
    // -------------------------------------------------------

    final int versionActual = ++_hoverVersion;

    _timerCerrar?.cancel();

    _cerrarPopupGlobal();

    if (!mounted) {
      return;
    }

    // -------------------------------------------------------
    // OBTENER POSICIÓN DEL CLIENTE
    // -------------------------------------------------------

    final RenderObject? renderObject =
        context.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final RenderBox box = renderObject;

    final Offset posicion =
        box.localToGlobal(Offset.zero);

    // -------------------------------------------------------
    // OBTENER PRODUCTOS
    // -------------------------------------------------------

    final productos =
        await service.obtenerProductosCliente(
      widget.cliente,
    );

    // =======================================================
    // IMPORTANTE
    //
    // Después del await verificamos nuevamente:
    //
    // 1. Que el widget siga montado.
    // 2. Que esta siga siendo la solicitud vigente.
    // 3. Que el mouse todavía esté sobre el cliente.
    //
    // Si cualquiera falla, NO mostramos el popup.
    // =======================================================

    if (!mounted) {
      return;
    }

    if (versionActual != _hoverVersion) {
      return;
    }

    if (!_mouseDentro) {
      return;
    }

    // -------------------------------------------------------
    // DIMENSIONES DEL POPUP
    // -------------------------------------------------------

    const double popupWidth = 420;
    const double popupHeight = 430;
    const double margen = 12;

    final pantalla =
        MediaQuery.of(context).size;

    // -------------------------------------------------------
    // POSICIÓN HORIZONTAL
    // -------------------------------------------------------

    double left =
        posicion.dx +
        box.size.width +
        margen;

    // Si no entra a la derecha,
    // mostrar a la izquierda.

    if (left + popupWidth > pantalla.width) {
      left =
          posicion.dx -
          popupWidth -
          margen;
    }

    // Nunca salir de la pantalla.

    if (left < margen) {
      left = margen;
    }

    // -------------------------------------------------------
    // POSICIÓN VERTICAL
    // -------------------------------------------------------

    double top = posicion.dy;

    if (top + popupHeight > pantalla.height) {
      top =
          pantalla.height -
          popupHeight -
          margen;
    }

    if (top < margen) {
      top = margen;
    }

    // -------------------------------------------------------
    // CREAR OVERLAY
    // -------------------------------------------------------

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: left,
          top: top,

          child: MouseRegion(
            // -------------------------------------------------
            // ENTRA AL POPUP
            // -------------------------------------------------

            onEnter: (_) {
              _timerCerrar?.cancel();
            },

            // -------------------------------------------------
            // SALE DEL POPUP
            // -------------------------------------------------

            onExit: (_) {
              _programarCerrar();
            },

            child: Material(
              color: Colors.transparent,
              elevation: 12,

              borderRadius:
                  BorderRadius.circular(16),

              child: ClientePopup(
                cliente: widget.cliente,
                productos: productos,
              ),
            ),
          ),
        );
      },
    );

    // -------------------------------------------------------
    // ASEGURAR QUE NO HAYA OTRO POPUP
    // -------------------------------------------------------

    _cerrarPopupGlobal();

    _overlayActual = entry;

    Overlay.of(context).insert(entry);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // -------------------------------------------------------
      // ENTRA AL CLIENTE
      // -------------------------------------------------------

      onEnter: (_) {
        _mouseDentro = true;

        mostrar();
      },

      // -------------------------------------------------------
      // SALE DEL CLIENTE
      // -------------------------------------------------------

      onExit: (_) {
        _mouseDentro = false;

        // Invalidamos cualquier consulta pendiente.
        _hoverVersion++;

        _programarCerrar();
      },

      child: widget.child,
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _mouseDentro = false;

    _hoverVersion++;

    _programarCerrar();

    super.dispose();
  }
}