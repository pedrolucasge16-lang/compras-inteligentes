class ShoppingItem {
  const ShoppingItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPriceCents,
    this.isBought = false,
    this.replacedBy,
    this.originalItemId,
    this.originalItemName,
    this.actualUnitPriceCents,
  });

  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final int unitPriceCents;
  final bool isBought;
  final String? replacedBy;
  final int? originalItemId;
  final String? originalItemName;
  final int? actualUnitPriceCents;

  int get subtotalCents => ((actualUnitPriceCents ?? unitPriceCents) * quantity).round();

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'unit_price_cents': unitPriceCents,
    'is_bought': isBought ? 1 : 0,
    'replaced_by': replacedBy,
    'original_item_id': originalItemId,
    'original_item_name': originalItemName,
    'actual_unit_price_cents': actualUnitPriceCents,
  };

  factory ShoppingItem.fromMap(Map<String, Object?> map) => ShoppingItem(
    id: map['id'] as int?,
    name: map['name'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unit: map['unit'] as String,
    unitPriceCents: (map['unit_price_cents'] as num).toInt(),
    isBought: (map['is_bought'] as int? ?? 0) == 1,
    replacedBy: map['replaced_by'] as String?,
    originalItemId: map['original_item_id'] as int?,
    originalItemName: map['original_item_name'] as String?,
    actualUnitPriceCents: (map['actual_unit_price_cents'] as num?)?.toInt(),
  );

  ShoppingItem copyWith({
    int? id,
    String? name,
    double? quantity,
    String? unit,
    int? unitPriceCents,
    bool? isBought,
    String? replacedBy,
    int? originalItemId,
    String? originalItemName,
    int? actualUnitPriceCents,
    bool clearReplacement = false,
    bool clearActualPrice = false,
  }) => ShoppingItem(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    isBought: isBought ?? this.isBought,
    replacedBy: clearReplacement ? null : (replacedBy ?? this.replacedBy),
    originalItemId: originalItemId ?? this.originalItemId,
    originalItemName: originalItemName ?? this.originalItemName,
    actualUnitPriceCents: clearActualPrice ? null : (actualUnitPriceCents ?? this.actualUnitPriceCents),
  );
}
