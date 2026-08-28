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
  // CONTROL DE SOLICITUDES
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
  //
  // mantenerAbierto:
  //
  // true  = celular / toque
  // false = mouse / hover
  // =========================================================

  Future<void> mostrar({
    bool mantenerAbierto = false,
  }) async {
    final int versionActual = ++_hoverVersion;

    _timerCerrar?.cancel();

    _cerrarPopupGlobal();

    if (!mounted) {
      return;
    }

    // =======================================================
    // OBTENER POSICIÓN
    // =======================================================

    final RenderObject? renderObject =
        context.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final RenderBox box = renderObject;

    final Offset posicion =
        box.localToGlobal(Offset.zero);

    // =======================================================
    // OBTENER PRODUCTOS
    // =======================================================

    final productos =
        await service.obtenerProductosCliente(
      widget.cliente,
    );

    // =======================================================
    // VALIDACIONES DESPUÉS DEL AWAIT
    // =======================================================

    if (!mounted) {
      return;
    }

    if (versionActual != _hoverVersion) {
      return;
    }

    // En PC necesitamos que el mouse siga encima.
    //
    // En celular mantenerAbierto = true,
    // por lo tanto no dependemos del hover.
    if (!mantenerAbierto && !_mouseDentro) {
      return;
    }

    // =======================================================
    // DIMENSIONES DEL POPUP
    // =======================================================

    final pantalla =
        MediaQuery.of(context).size;

    const double popupWidth = 420;
    const double popupHeight = 430;
    const double margen = 12;

    // =======================================================
    // POSICIÓN HORIZONTAL
    // =======================================================

    double left =
        posicion.dx +
        box.size.width +
        margen;

    if (left + popupWidth > pantalla.width) {
      left =
          posicion.dx -
          popupWidth -
          margen;
    }

    if (left < margen) {
      left = margen;
    }

    // =======================================================
    // POSICIÓN VERTICAL
    // =======================================================

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

    // =======================================================
    // AJUSTE PARA CELULAR
    //
    // En pantallas pequeñas el popup ocupa casi todo
    // el ancho disponible.
    // =======================================================

    final bool esMovil =
        pantalla.width < 700;

    if (esMovil) {
      const double margenMovil = 10;

      left = margenMovil;

      top = 70;

      // No permitir que salga por abajo.
      if (top + popupHeight >
          pantalla.height - margenMovil) {
        top =
            pantalla.height -
            popupHeight -
            margenMovil;
      }

      if (top < margenMovil) {
        top = margenMovil;
      }
    }

    // =======================================================
    // ANCHO FINAL
    // =======================================================

    final double anchoPopup =
        esMovil
            ? pantalla.width - 20
            : popupWidth;

    // =======================================================
    // CREAR OVERLAY
    // =======================================================

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [

            // =================================================
            // FONDO TRANSPARENTE
            //
            // Permite cerrar el popup tocando fuera.
            // Especialmente útil en celular.
            // =================================================

            Positioned.fill(
              child: GestureDetector(
                behavior:
                    HitTestBehavior.translucent,
                onTap: () {
                  _cerrarPopupGlobal();
                },
                child:
                    const SizedBox.expand(),
              ),
            ),

            // =================================================
            // POPUP
            // =================================================

            Positioned(
              left: esMovil ? 10 : left,
              top: top,
              width: anchoPopup,

              child: MouseRegion(
                // ---------------------------------------------
                // ENTRA AL POPUP
                // ---------------------------------------------

                onEnter: (_) {
                  _timerCerrar?.cancel();
                },

                // ---------------------------------------------
                // SALE DEL POPUP
                // ---------------------------------------------

                onExit: (_) {
                  if (!esMovil) {
                    _programarCerrar();
                  }
                },

                child: GestureDetector(
                  // Evita que el tap dentro del popup
                  // llegue al fondo transparente.
                  onTap: () {},

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
              ),
            ),
          ],
        );
      },
    );

    // =======================================================
    // ASEGURAR UN SOLO POPUP
    // =======================================================

    _cerrarPopupGlobal();

    _overlayActual = entry;

    Overlay.of(context).insert(entry);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // =======================================================
      // CELULAR
      //
      // Al tocar el cliente mostramos el popup y lo dejamos
      // abierto hasta que toque fuera.
      // =======================================================

      onTap: () {
        mostrar(
          mantenerAbierto: true,
        );
      },

      child: MouseRegion(
        // =====================================================
        // WINDOWS / PC
        //
        // Al pasar el mouse aparece el popup.
        // =====================================================

        onEnter: (_) {
          _mouseDentro = true;

          mostrar(
            mantenerAbierto: false,
          );
        },

        // =====================================================
        // WINDOWS / PC
        //
        // Al salir del cliente empieza el cierre.
        // =====================================================

        onExit: (_) {
          _mouseDentro = false;

          // Invalidamos consultas pendientes.
          _hoverVersion++;

          _programarCerrar();
        },

        child: widget.child,
      ),
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