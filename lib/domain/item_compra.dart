class ItemCompra {
  final int? id;
  final String nome;
  final int precoCentavos; // preço unitário em centavos
  final int quantidade;

  const ItemCompra({
    this.id,
    required this.nome,
    required this.precoCentavos,
    required this.quantidade,
  });

  int get totalCentavos => precoCentavos * quantidade;

  ItemCompra copyWith({String? nome, int? precoCentavos, int? quantidade}) {
    return ItemCompra(
      id: id,
      nome: nome ?? this.nome,
      precoCentavos: precoCentavos ?? this.precoCentavos,
      quantidade: quantidade ?? this.quantidade,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'nome': nome,
        'preco_centavos': precoCentavos,
        'quantidade': quantidade,
      };

  factory ItemCompra.fromMap(Map<String, Object?> m) => ItemCompra(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        precoCentavos: m['preco_centavos'] as int,
        quantidade: m['quantidade'] as int,
      );
}
