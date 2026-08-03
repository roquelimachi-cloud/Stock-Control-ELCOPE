class Formato {
  Formato._();

  static String entero(num valor) {
    return _agregarComas(valor.toStringAsFixed(0));
  }

  static String decimal(num valor, {int decimales = 2}) {
    final partes = valor.toStringAsFixed(decimales).split('.');

    return "${_agregarComas(partes[0])}.${partes[1]}";
  }

  static String moneda(num valor) {
    return "US\$ ${decimal(valor)}";
  }

  static String peso(num valor) {
    return "${decimal(valor)} Kg";
  }

  static String _agregarComas(String numero) {
    final buffer = StringBuffer();

    int contador = 0;

    for (int i = numero.length - 1; i >= 0; i--) {
      contador++;

      buffer.write(numero[i]);

      if (contador % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}