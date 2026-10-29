import 'category.dart';

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
    this.category = ProductCategory.outros,
    this.boughtQuantity = 0.0,
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
  final String category;
  final double boughtQuantity;

  int get effectiveUnitPriceCents => actualUnitPriceCents ?? unitPriceCents;
  int get subtotalCents => (effectiveUnitPriceCents * quantity).round();
  int get boughtSubtotalCents =>
      (effectiveUnitPriceCents * (isFullyBought ? quantity : boughtQuantity)).round();

  double get remainingQuantity {
    final diff = quantity - boughtQuantity;
    if (diff <= 0.0001) return 0.0;
    return (diff * 1000).round() / 1000;
  }

  bool get isFullyBought => isBought || remainingQuantity == 0.0;
  bool get isPartiallyBought => !isFullyBought && boughtQuantity > 0.0001;
  bool get isPending => !isFullyBought;

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
    'category': category,
    'bought_quantity': boughtQuantity,
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
    category: (map['category'] as String?) ?? ProductCategory.outros,
    boughtQuantity: (map['bought_quantity'] as num?)?.toDouble() ??
        ((map['is_bought'] as int? ?? 0) == 1 ? (map['quantity'] as num).toDouble() : 0.0),
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
    String? category,
    double? boughtQuantity,
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
    category: category ?? this.category,
    boughtQuantity: boughtQuantity ?? this.boughtQuantity,
  );
}
