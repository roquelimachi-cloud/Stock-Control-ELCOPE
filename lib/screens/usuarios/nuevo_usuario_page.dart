import 'package:flutter/material.dart';

import '../../services/supabase/usuario_service.dart';
import '../../services/supabase/vendedor_service.dart';

class NuevoUsuarioPage extends StatefulWidget {
  const NuevoUsuarioPage({super.key});

  @override
  State<NuevoUsuarioPage> createState() => _NuevoUsuarioPageState();
}

class _NuevoUsuarioPageState extends State<NuevoUsuarioPage> {
  final UsuarioService servicio = UsuarioService();
  final VendedorService vendedorService = VendedorService();

  final usuarioController = TextEditingController();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();

  List<String> vendedores = [];
  String? vendedorSeleccionado;
  String rol = "Comercial";

  bool guardando = false;
  bool ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    cargarVendedores();
  }

  Future<void> cargarVendedores() async {
    vendedores = await vendedorService.obtenerVendedores();

    if (vendedores.isNotEmpty) {
      vendedorSeleccionado = vendedores.first;
    }

    if (mounted) setState(() {});
  }

  Future<void> guardarUsuario() async {
    if (usuarioController.text.trim().isEmpty ||
        nombreController.text.trim().isEmpty ||
        correoController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        vendedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos.")),
      );
      return;
    }

    try {
      setState(() => guardando = true);

      await servicio.insertarUsuario(
        usuario: usuarioController.text.trim(),
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        password: passwordController.text.trim(),
        rol: rol,
        vendedor: vendedorSeleccionado!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario registrado correctamente.")),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  void dispose() {
    usuarioController.dispose();
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration deco(String t, IconData i)=>InputDecoration(
    labelText:t,
    border: const OutlineInputBorder(),
    prefixIcon: Icon(i),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NUEVO USUARIO"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(controller: usuarioController, decoration: deco("Usuario", Icons.person)),
            const SizedBox(height:15),
            TextField(controller: nombreController, decoration: deco("Nombre Completo", Icons.badge)),
            const SizedBox(height:15),
            TextField(controller: correoController, keyboardType: TextInputType.emailAddress, decoration: deco("Correo", Icons.email)),
            const SizedBox(height:15),
            TextField(
              controller: passwordController,
              obscureText: ocultarPassword,
              decoration: deco("Contraseña", Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(ocultarPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: ()=>setState(()=>ocultarPassword=!ocultarPassword),
                ),
              ),
            ),
            const SizedBox(height:15),
            DropdownButtonFormField<String>(
              value: rol,
              decoration: deco("Rol", Icons.admin_panel_settings),
              items: const [
                DropdownMenuItem(value:"Administrador",child:Text("Administrador")),
                DropdownMenuItem(value:"Comercial",child:Text("Comercial")),
                DropdownMenuItem(value:"Producción",child:Text("Producción")),
                DropdownMenuItem(value:"Logística",child:Text("Logística")),
                DropdownMenuItem(value:"Gerencia",child:Text("Gerencia")),
              ],
              onChanged:(v){ if(v!=null) setState(()=>rol=v);},
            ),
            const SizedBox(height:15),
            DropdownButtonFormField<String>(
              value: vendedorSeleccionado,
              decoration: deco("Vendedor", Icons.badge_outlined),
              items: vendedores.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
              onChanged:(v)=>setState(()=>vendedorSeleccionado=v),
            ),
            const SizedBox(height:30),
            SizedBox(
              height:50,
              child: ElevatedButton.icon(
                onPressed: guardando?null:guardarUsuario,
                icon: guardando
                  ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                  : const Icon(Icons.save),
                label: Text(guardando?"Guardando...":"GUARDAR USUARIO"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
