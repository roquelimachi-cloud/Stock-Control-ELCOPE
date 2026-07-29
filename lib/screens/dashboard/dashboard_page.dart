import 'package:flutter/material.dart';

import '../login/login_page.dart';
import '../stock/stock_page.dart';
import '../sync/sync_page.dart';
import '../usuarios/usuarios_page.dart';
import '../../services/sesion.dart';
import '../perfil/mi_perfil_page.dart';
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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
    body: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [

      Image.asset(
        'assets/images/logo_mr.png',
        width: 220,
      ),

      const SizedBox(height: 20),

      const Text(
        "Bienvenido a",
        style: TextStyle(
          fontSize: 22,
        ),
      ),

      const SizedBox(height: 10),

      const Text(
        "CONTROL DE STOCK ELCOPE",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),

      const SizedBox(height: 15),

      const Text(
         "Sistema Inteligente de Gestión de Ventas",
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey,
        ),
      ),
    ],
  ),
),


    );
  }
}