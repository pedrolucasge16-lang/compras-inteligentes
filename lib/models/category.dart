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

  /// Ordem fixa de navegação no supermercado
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

  static String _normalize(String input) {
    var s = input.toLowerCase().trim();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const Map<String, List<String>> _keywordsByCategory = {
    carnes: [
      'carne', 'frango', 'boi', 'bovino', 'bovina', 'porco', 'suino', 'suina',
      'peixe', 'picanha', 'alcatra', 'maminha', 'contrafile', 'contra file',
      'patinho', 'acem', 'costela', 'cupim', 'musculo', 'lagarto', 'figado',
      'fraldinha', 'file', 'bife', 'moida', 'coxa', 'sobrecoxa', 'asa',
      'peito de frango', 'coracao', 'tulipa', 'bisteca', 'lombo', 'pernil',
      'bacon', 'panceta', 'linguica', 'calabresa', 'toscana', 'salsicha',
      'mortadela', 'presunto', 'peito de peru', 'salame', 'tilapia', 'salmao',
      'merluza', 'bacalhau', 'sardinha', 'atum', 'camarao', 'churrasco',
    ],
    limpeza: [
      'sabao', 'detergente', 'ype', 'agua sanitaria', 'cloro', 'candida',
      'qboa', 'amaciante', 'downy', 'confort', 'desinfetante', 'pinho',
      'veja', 'multiuso', 'limpa', 'lustra', 'esponja', 'bombril', 'palha de aco',
      'la de aco', 'vassoura', 'rodo', 'pano', 'flanela', 'saco de lixo',
      'lixo', 'alvejante', 'vanish', 'cera', 'inseticida', 'sbp', 'raid',
      'desengordurante', 'limpeza', 'omo', 'tixan', 'brilhante', 'ariel',
      ' álcool', 'alcool', 'naftalina', 'pedra sanitaria',
    ],
    higienePessoal: [
      'sabonete', 'dove', 'lux', 'protex', 'shampoo', 'xampu', 'condicionador',
      'creme de pentear', 'creme dental', 'pasta de dente', 'colgate', 'sorriso',
      'oral b', 'escova de dente', 'fio dental', 'enxaguante', 'listerine',
      'desodorante', 'rexona', 'papel higienico', 'neve', 'personal',
      'absorvente', 'fralda', 'pampers', 'huggies', 'lenco umedecido',
      'algodao', 'cotonete', 'barbear', 'prestobarba', 'gillette', 'hidratante',
      'protetor solar', 'acetona', 'esmalte', 'higiene',
    ],
    frutasVerduras: [
      'fruta', 'verdura', 'legume', 'banana', 'maca', 'laranja', 'limao',
      'uva', 'morango', 'mamao', 'melancia', 'melao', 'abacaxi', 'manga',
      'pera', 'abacate', 'kiwi', 'goiaba', 'maracuja', 'pessego', 'ameixa',
      'tangerina', 'mexerica', 'ponkan', 'coco', 'alface', 'tomate', 'cebola',
      'alho', 'batata', 'cenoura', 'beterraba', 'chuchu', 'abobrinha', 'abobora',
      'berinjela', 'pepino', 'pimentao', 'pimenta', 'couve', 'brocolis',
      'repolho', 'espinafre', 'rucula', 'agriao', 'cheiro verde', 'coentro',
      'salsinha', 'cebolinha', 'mandioca', 'aipim', 'macaxeira', 'inhame',
      'quiabo', 'vagem', 'gengibre', 'hortela',
    ],
    laticinios: [
      'leite', 'queijo', 'mussarela', 'mucarela', 'prato', 'parmesao', 'minas',
      'ricota', 'cottage', 'gorgonzola', 'provolone', 'requeijao', 'catupiry',
      'manteiga', 'margarina', 'qualy', 'danone', 'iogurte', 'coalhada',
      'creme de leite', 'leite condensado', 'chantilly', 'nata', 'yakult',
      'leite fermentado', 'ninho', 'laticinio',
    ],
    massas: [
      'macarrao', 'espaguete', 'parafuso', 'penne', 'lasanha', 'nhoque',
      'miojo', 'lamen', 'nissin', 'capeletti', 'ravioli', 'canelone',
      'talharim', 'massa',
    ],
    cereais: [
      'arroz', 'feijao', 'lentilha', 'grao de bico', 'ervilha', 'pipoca',
      'aveia', 'granola', 'farinha', 'fuba', 'amido', 'maizena', 'polvilho',
      'tapioca', 'cuscuz', 'flocao', 'trigo', 'quinoa', 'chia', 'linhaca',
      'cereal', 'sucrilhos', 'acucar', 'sal', 'oleo', 'azeite', 'vinagre',
      'molho de tomate', 'extrato de tomate', 'pomarola', 'maionese',
      'hellmanns', 'ketchup', 'catchup', 'mostarda', 'tempero', 'oregano',
      'cominho', 'colorau', 'caldo', 'sazon', 'ovo', 'ovos',
    ],
    bebidas: [
      'agua', 'refrigerante', 'coca', 'guarana', 'fanta', 'sprite', 'pepsi',
      'suco', 'tang', 'clight', 'cerveja', 'heineken', 'brahma', 'skol',
      'antarctica', 'amstel', 'vinho', 'vodka', 'whisky', 'cachaca',
      'energetico', 'red bull', 'monster', 'cha', 'mate', 'cafe', 'pilao',
      'melitta', 'nescafe', 'capuccino', 'gatorade', 'toddy', 'nescau',
      'achocolatado', 'bebida',
    ],
    padaria: [
      'pao', 'bisnaguinha', 'torrada', 'bolo', 'biscoito', 'bolacha',
      'cream cracker', 'wafer', 'passatempo', 'oreo', 'bauducco', 'panetone',
      'sonho', 'rosca', 'croissant', 'pao de queijo', 'salgado', 'torta',
      'geleia', 'mel', 'doce de leite', 'goiabada', 'chocolate', 'bombom',
      'bis', 'padaria',
    ],
    congelados: [
      'congelado', 'congelada', 'sorvete', 'kibon', 'picole', 'acai',
      'pizza', 'hamburguer', 'nuggets', 'empanado', 'steak', 'batata palito',
      'polpa', 'gelo',
    ],
  };

  /// Identifica automaticamente a categoria pelo nome do produto digitado.
  static String detectCategory(String productName) {
    final norm = _normalize(productName);
    if (norm.isEmpty) return outros;
    final words = norm.split(' ');

    // 1. Verifica expressões compostas ou palavras exatas
    for (final entry in _keywordsByCategory.entries) {
      for (final kw in entry.value) {
        final normKw = _normalize(kw);
        if (norm == normKw || norm.contains(normKw)) {
          // Se a palavra-chave é composta (ex: "agua sanitaria"), prioriza
          if (normKw.contains(' ')) {
            return entry.key;
          }
          // Se é palavra simples, confere se está entre as palavras ou é prefixo
          if (words.any((w) => w == normKw || (normKw.length >= 4 && w.startsWith(normKw)))) {
            return entry.key;
          }
        }
      }
    }

    return outros;
  }

  /// Sugere a unidade padrão ideal para o produto (ex: kg para carnes, un para limpeza)
  static String suggestUnit(String productName, String category) {
    final norm = _normalize(productName);
    if (category == carnes) {
      if (norm.contains('salsicha') || norm.contains('mortadela') || norm.contains('presunto')) {
        return 'g';
      }
      return 'kg';
    }
    return 'un';
  }

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
