import 'package:flutter/material.dart';

import '../login/login_page.dart';
import '../stock/stock_page.dart';
import '../sync/sync_page.dart';
import '../usuarios/usuarios_page.dart';
import '../../services/sesion.dart';
import '../perfil/mi_perfil_page.dart';
import '../../models/dashboard/dashboard_summary.dart';
import '../../services/supabase/dashboard_service.dart';
import '../../widgets/dashboard/kpi_card.dart';
import '../../models/dashboard/cliente_top.dart';
import '../../widgets/dashboard/top_clientes_card.dart';
import 'package:intl/intl.dart';
import '../../widgets/dashboard/cliente_hover.dart';
import '../../widgets/dashboard/clase_pie_chart.dart';
import '../../models/dashboard/clase_resumen.dart';
import '../../models/dashboard/producto_top.dart';
import '../../widgets/dashboard/top_productos_card.dart';
import '../produccion/produccion_dashboard.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {

  final DashboardService dashboardService =
      DashboardService();

  final ScrollController _scrollController =
      ScrollController();

late Future<DashboardSummary> _resumenFuture;
late Future<List<ClienteTop>> _clientesFuture;
late Future<List<ClaseResumen>> _clasesFuture;
late Future<List<ProductoTop>> _productosFuture;
@override
void initState() {
  super.initState();
_resumenFuture = dashboardService.obtenerResumen();
_clientesFuture = dashboardService.obtenerTopClientes();
_clasesFuture = dashboardService.obtenerResumenClases();
_productosFuture = dashboardService.obtenerTopProductos();
  _scrollController.addListener(() {
    ClienteHover.cerrarPopup();
  });

}

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final entero = NumberFormat("#,##0", "en_US");
final decimal = NumberFormat("#,##0.00", "en_US");


 return GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () {
    ClienteHover.cerrarPopup();
    FocusScope.of(context).unfocus();
  },
  child: Scaffold(


      appBar: AppBar(
        title: const Text("CONTROL DE STOCK ELCOPE"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.indigo,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                 Image.asset(
  'assets/images/logo_mr.png',
  width: 70,
  height: 70,
),
                    SizedBox(height: 10),
                    Text(
                     Sesion.nombre,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                       Sesion.rol,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: const Text("Dashboard"),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),

                    ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: const Text("Control de Stock"),
                      onTap: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StockPage(),
                          ),
                        );
                      },
                    ),

              ListTile(
  leading: const Icon(Icons.factory),
  title: const Text("Producción Pendiente"),
  onTap: () {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProduccionDashboard(),
      ),
    );
  },
),
                  ListTile(
  leading: const Icon(Icons.person),
  title: const Text("Mi Perfil"),
  onTap: () {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MiPerfilPage(),
      ),
    );
  },
),
                    
if (Sesion.esAdministrador)
  ListTile(
    leading: const Icon(Icons.sync),
    title: const Text("Sincronizar Excel"),
    onTap: () async {
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SyncPage(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _resumenFuture =
            dashboardService.obtenerResumen();

        _clientesFuture =
            dashboardService.obtenerTopClientes();

        _clasesFuture =
            dashboardService.obtenerResumenClases();

        _productosFuture =
            dashboardService.obtenerTopProductos();
      });
    },
  ),

                    if (Sesion.esAdministrador)
  ListTile(
    leading: const Icon(Icons.people),
    title: const Text("Usuarios"),
    onTap: () {
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UsuariosPage(),
        ),
      );
    },
  ),

                    
       if (Sesion.esAdministrador)
  ListTile(
    leading: const Icon(Icons.settings),
    title: const Text("Configuración"),
    onTap: () {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Módulo en desarrollo"),
        ),
      );
    },
  ),
                  ],
                ),
              ),

              const Divider(height: 1),

              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
  Sesion.cerrarSesion();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginPage(),
    ),
    (route) => false,
  );
},
              
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
  
body: FutureBuilder<DashboardSummary>(
  future: _resumenFuture,
  builder: (context, snapshot) {

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Text(
          "Error: ${snapshot.error}",
        ),
      );
    }

   

    return FutureBuilder<List<ClienteTop>>(
      future: _clientesFuture,
      builder: (context, topSnapshot) {
        if (topSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (topSnapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${topSnapshot.error}",
            ),
          );
        }

       final topClientes = topSnapshot.data ?? [];

debugPrint("================================");
debugPrint("Cantidad de clientes: ${topClientes.length}");

for (final c in topClientes) {
  debugPrint("${c.cliente} -> ${c.valorStock}");
}

debugPrint("================================");

final resumen = snapshot.data!;

return SingleChildScrollView(
  controller: _scrollController,
  padding: const EdgeInsets.all(20),
  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "Bienvenido ${Sesion.nombre}",
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                Sesion.rol,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),
GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 3,
  crossAxisSpacing: 20,
  mainAxisSpacing: 20,
  
  childAspectRatio:
    MediaQuery.of(context).size.width < 700
        ? 0.95
        : 2.3,

  children: [

    KpiCard(
      titulo: "Peso Total",
      valor: "${decimal.format(resumen.pesoTotal)} Kg",
      icono: Icons.scale,
      color: Colors.orange,
    ),

    KpiCard(
      titulo: "Valor Stock",
      valor: "US\$ ${decimal.format(resumen.valorStock)}",
      icono: Icons.attach_money,
      color: Colors.green,
    ),

    KpiCard(
      titulo: "Clientes",
      valor: entero.format(resumen.clientes),
      icono: Icons.people,
      color: Colors.purple,
    ),

  ],
),

const SizedBox(height: 30),
FutureBuilder<List<ClaseResumen>>(
  future: _clasesFuture,
  builder: (context, claseSnapshot) {
    if (claseSnapshot.connectionState ==
        ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (claseSnapshot.hasError) {
      return Center(
        child: Text(
          "Error: ${claseSnapshot.error}",
        ),
      );
    }

    final clases = claseSnapshot.data ?? [];

    return FutureBuilder<List<ProductoTop>>(
      future: _productosFuture,
      builder: (context, productoSnapshot) {

        if (productoSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (productoSnapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${productoSnapshot.error}",
            ),
          );
        }

        final productos =
            productoSnapshot.data ?? [];

        return Column(
          children: [

            LayoutBuilder(
              builder: (context, constraints) {

                if (constraints.maxWidth < 950) {

                  return Column(
                    children: [

                      ClasePieChart(
                        datos: clases,
                      ),

                      const SizedBox(height: 20),

                      TopClientesCard(
                        clientes: topClientes,
                      ),

                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Expanded(
                      flex: 5,
                      child: ClasePieChart(
                        datos: clases,
                      ),
                    ),

                    const SizedBox(width: 20),

                    Expanded(
                      flex: 5,
                      child: TopClientesCard(
                        clientes: topClientes,
                      ),
                    ),

                  ],
                );
              },
            ),

            const SizedBox(height: 25),

           TopProductosCard(
              productos: productos,
            ),

          ],
        );
      },
    );
  },
),

const SizedBox(height: 20),

          ],
        ),
      );
    },
  );
},
),

    ),
  );
}
}