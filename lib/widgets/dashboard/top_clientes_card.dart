import 'package:flutter/material.dart';

import '../../models/dashboard/cliente_top.dart';

class TopClientesCard extends StatelessWidget {
  final List<ClienteTop> clientes;

  const TopClientesCard({
    super.key,
    required this.clientes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                ),
                SizedBox(width: 8),
                Text(
                  "Top 10 Clientes",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clientes.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final cliente = clientes[index];

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Text(
                    cliente.cliente,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    "US\$ ${cliente.valorStock.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}