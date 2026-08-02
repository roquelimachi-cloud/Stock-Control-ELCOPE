import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const KpiCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;

    final bool esMovil = ancho < 700;

    final double padding = esMovil ? 12 : 18;
    final double radio = esMovil ? 18 : 24;
    final double iconoSize = esMovil ? 22 : 28;
    final double tituloSize = esMovil ? 12 : 14;
    final double valorSize = esMovil ? 18 : 24;

    return SizedBox(
      height: esMovil ? 95 : 115,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              CircleAvatar(
                radius: radio,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(
                  icono,
                  color: color,
                  size: iconoSize,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tituloSize,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        valor,
                        style: TextStyle(
                          fontSize: valorSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}