import 'package:flutter/material.dart';

class ProductCategory {
  ProductCategory._();

  static const String carnes = 'Carnes';
  static const String frutasVerduras = 'Frutas e verduras';
  static const String laticinios = 'Laticínios';
  static const String cereais = 'Cereais';
  static const String massas = 'Massas';
  static const String bebidas = 'Bebidas';
  static const String padaria = 'Padaria';
  static const String higienePessoal = 'Higiene pessoal';
  static const String limpeza = 'Limpeza';
  static const String congelados = 'Congelados';
  static const String outros = 'Outros';

  /// Ordem fixa de navegação no supermercado conforme o planejamento
  static const List<String> all = [
    carnes,
    frutasVerduras,
    laticinios,
    cereais,
    massas,
    bebidas,
    padaria,
    higienePessoal,
    limpeza,
    congelados,
    outros,
  ];

  static IconData iconFor(String? category) {
    switch (category) {
      case carnes:
        return Icons.set_meal;
      case frutasVerduras:
        return Icons.eco;
      case laticinios:
        return Icons.water_drop;
      case cereais:
        return Icons.grain;
      case massas:
        return Icons.dinner_dining;
      case bebidas:
        return Icons.local_drink;
      case padaria:
        return Icons.bakery_dining;
      case higienePessoal:
        return Icons.clean_hands;
      case limpeza:
        return Icons.cleaning_services;
      case congelados:
        return Icons.ac_unit;
      case outros:
      default:
        return Icons.category;
    }
  }

  static Color colorFor(String? category) {
    switch (category) {
      case carnes:
        return const Color(0xFFC62828);
      case frutasVerduras:
        return const Color(0xFF2E7D32);
      case laticinios:
        return const Color(0xFF0277BD);
      case cereais:
        return const Color(0xFFE65100);
      case massas:
        return const Color(0xFFD84315);
      case bebidas:
        return const Color(0xFF1565C0);
      case padaria:
        return const Color(0xFF8D6E63);
      case higienePessoal:
        return const Color(0xFF00838F);
      case limpeza:
        return const Color(0xFF00695C);
      case congelados:
        return const Color(0xFF283593);
      case outros:
      default:
        return const Color(0xFF546E7A);
    }
  }
}
