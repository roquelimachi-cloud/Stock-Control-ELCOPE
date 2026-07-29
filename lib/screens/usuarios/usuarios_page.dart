import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/sesion.dart';
import '../../services/supabase/usuario_service.dart';
import 'editar_usuario_page.dart';
import 'nuevo_usuario_page.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final UsuarioService servicio = UsuarioService();

  final TextEditingController buscarController = TextEditingController();

  List<Usuario> usuarios = [];
  List<Usuario> filtro = [];

  bool cargando = true;

  @override
  void initState() {
    super.initState();

    if (!Sesion.esAdministrador) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No tiene permisos para acceder a este módulo."),
          ),
        );

        Navigator.pop(context);
      });

      return;
    }

    cargarUsuarios();
  }

  Future<void> cargarUsuarios() async {
    setState(() {
      cargando = true;
    });

    usuarios = await servicio.obtenerUsuarios();
    filtro = usuarios;

    setState(() {
      cargando = false;
    });
  }

  void buscar(String texto) {
    setState(() {
      filtro = usuarios.where((u) {
        return u.nombre.toLowerCase().contains(texto.toLowerCase()) ||
            u.usuario.toLowerCase().contains(texto.toLowerCase()) ||
            u.correo.toLowerCase().contains(texto.toLowerCase()) ||
            u.rol.toLowerCase().contains(texto.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADMINISTRACIÓN DE USUARIOS"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      floatingActionButton: Sesion.esAdministrador
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: const Text("Nuevo Usuario"),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NuevoUsuarioPage(),
                  ),
                );

                cargarUsuarios();
              },
            )
          : null,

      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: buscarController,
              decoration: InputDecoration(
                hintText: "Buscar usuario...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: buscar,
            ),

            const SizedBox(height: 20),

            Expanded(
              child: cargando
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : filtro.isEmpty
                      ? const Center(
                          child: Text(
                            "No existen usuarios registrados",
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtro.length,
                          itemBuilder: (context, index) {
                            final usuario = filtro[index];

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: usuario.activo
                                      ? Colors.green
                                      : Colors.red,
                                  child: Text(
                                    usuario.nombre
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                title: Text(
                                  usuario.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text("Usuario: ${usuario.usuario}"),
                                    Text("Correo: ${usuario.correo}"),
                                    Text("Rol: ${usuario.rol}"),
                                  ],
                                ),

                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [

                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          usuario.activo
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: usuario.activo
                                              ? Colors.green
                                              : Colors.red,
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          usuario.activo
                                              ? "Activo"
                                              : "Inactivo",
                                          style: TextStyle(
                                            color: usuario.activo
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(width: 10),

                                    if (Sesion.esAdministrador)
                                      IconButton(
                                        tooltip: "Editar",
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  EditarUsuarioPage(
                                                usuario: usuario,
                                              ),
                                            ),
                                          );

                                          cargarUsuarios();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}