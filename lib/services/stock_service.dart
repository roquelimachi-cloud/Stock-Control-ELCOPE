import '../models/stock_model.dart';

class StockService {
  static List<StockModel> obtenerStock() {
    return [
      StockModel(
        vendedor: "Michael",
        cliente: "Delcrosa",
        codigo: "N2XOH150",
        descripcion: "Cable N2XOH 1x150 CL2 Negro",
        lote: "L00125",
        produccion: "OP1202500377",
        fechaIngreso: DateTime(2026, 6, 15),
        stock: 350,
        peso: 525,
        estado: "Disponible",
        almacen: "Principal",
      ),
      StockModel(
        vendedor: "Michael",
        cliente: "Quimpac",
        codigo: "N2XOH150",
        descripcion: "Cable N2XOH 1x150 CL2 Rojo",
        lote: "L00126",
        produccion: "OP1202500380",
        fechaIngreso: DateTime(2026, 6, 16),
        stock: 120,
        peso: 180,
        estado: "Disponible",
        almacen: "Principal",
      ),
      StockModel(
        vendedor: "Daniela",
        cliente: "SPARQ",
        codigo: "LSOH25",
        descripcion: "Cable LSOH 2x25 CL5 Blanco",
        lote: "L00127",
        produccion: "OP1202500395",
        fechaIngreso: DateTime(2026, 6, 17),
        stock: 500,
        peso: 740,
        estado: "Comprometido",
        almacen: "Ate",
      ),
    ];
  }
}