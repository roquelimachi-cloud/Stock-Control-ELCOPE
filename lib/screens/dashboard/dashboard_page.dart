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
class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});
  final DashboardService dashboardService = DashboardService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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


                      onTap: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SyncPage(),
                          ),
                        );
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
  future: dashboardService.obtenerResumen(),
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

    final resumen = snapshot.data!;

    return FutureBuilder<List<ClienteTop>>(
      future: dashboardService.obtenerTopClientes(),
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

        return SingleChildScrollView(
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
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 2.8,
                children: [

                  KpiCard(
                    titulo: "Stock Total",
                    valor: resumen.stockTotal.toStringAsFixed(0),
                    icono: Icons.inventory,
                    color: Colors.blue,
                  ),

                  KpiCard(
                    titulo: "Peso Total",
                    valor:
                        "${resumen.pesoTotal.toStringAsFixed(2)} Kg",
                    icono: Icons.scale,
                    color: Colors.orange,
                  ),

                  KpiCard(
                    titulo: "Valor Stock",
                    valor:
                        "US\$ ${resumen.valorStock.toStringAsFixed(2)}",
                    icono: Icons.attach_money,
                    color: Colors.green,
                  ),

                  KpiCard(
                    titulo: "Clientes",
                    valor: resumen.clientes.toString(),
                    icono: Icons.people,
                    color: Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 30),

              TopClientesCard(
                clientes: topClientes,
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  },
),

    );
  }
}
