import 'package:flutter/material.dart';

class CrmOportunidadesPage extends StatefulWidget {
  const CrmOportunidadesPage({super.key});

  @override
  State<CrmOportunidadesPage> createState() => _CrmOportunidadesPageState();
}

class _CrmOportunidadesPageState extends State<CrmOportunidadesPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3B63),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Oportunidades',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final mobile = c.maxWidth < 800;
          return SingleChildScrollView(
            padding: EdgeInsets.all(mobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(mobile ? 20 : 28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B3B63), Color(0xFF0A79B8)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.business_center_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Oportunidades',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Gestiona oportunidades comerciales por etapa, monto y fecha estimada de cierre.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _estadoChip('Prospección', Icons.circle_outlined),
_estadoChip('Cotización', Icons.circle_outlined),
_estadoChip('Negociación', Icons.circle_outlined),
_estadoChip('Cierre', Icons.circle_outlined),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE0E7EF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: 'Buscar oportunidades...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFFF4F7FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Icon(
                          Icons.inbox_outlined,
                          size: 54,
                          color: Color(0xFF9AA8B5),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No hay registros para mostrar todavía.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B3B63),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'La pantalla ya está disponible. La integración de registros del módulo se incorpora en la siguiente etapa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _estadoChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 17, color: const Color(0xFF0B3B63)),
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFDDE5EC)),
    );
  }
}
