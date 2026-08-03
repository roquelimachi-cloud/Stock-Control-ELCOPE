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

  static void cerrarPopup() {
    _ClienteHoverState._cerrarPopupGlobal();
  }

  @override
  State<ClienteHover> createState() => _ClienteHoverState();
}

class _ClienteHoverState extends State<ClienteHover> {
  final DashboardService service = DashboardService();

  static OverlayEntry? _overlayActual;
  static Timer? _timerCerrar;
static int _token = 0;
  static void _cerrarPopupGlobal() {
    _timerCerrar?.cancel();

    if (_overlayActual != null) {
      _overlayActual!.remove();
      _overlayActual = null;
    }
  }

  void _programarCerrar() {
    _timerCerrar?.cancel();

    final overlay = _overlayActual;

    _timerCerrar = Timer(
      const Duration(milliseconds: 180),
      () {
        if (_overlayActual == overlay) {
          _cerrarPopupGlobal();
        }
      },
    );
  }

Future<void> mostrar() async {
    _timerCerrar?.cancel();

    final int miToken = ++_token;

    _cerrarPopupGlobal();
    if (!mounted) return;

    final RenderBox box =
        context.findRenderObject() as RenderBox;

    final Offset posicion =
        box.localToGlobal(Offset.zero);

   final productos =
    await service.obtenerProductosCliente(
  widget.cliente,
);

if (!mounted) return;

// Si mientras esperaba ya se abrió otro popup,
// este ya no debe mostrarse.
if (miToken != _token) {
  return;
}

    const double popupWidth = 420;
    const double popupHeight = 430;
    const double margen = 12;

    final pantalla = MediaQuery.of(context).size;

    double left =
        posicion.dx + box.size.width + margen;

    if (left + popupWidth > pantalla.width) {
      left = posicion.dx - popupWidth - margen;
    }

    if (left < margen) {
      left = margen;
    }

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

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: left,
          top: top,
          child: MouseRegion(
            onEnter: (_) {
              _timerCerrar?.cancel();
            },
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

   
   if (miToken != _token) {
  return;
}

_overlayActual = entry;

Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        mostrar();
      },
      onExit: (_) {
        _programarCerrar();
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _programarCerrar();
    super.dispose();
  }
}