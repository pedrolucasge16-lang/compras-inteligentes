class PurchaseRecord {
  const PurchaseRecord({
    required this.id, required this.purchasedAt, required this.totalCents,
    required this.itemsCount,
  });
  final int id;
  final DateTime purchasedAt;
  final int totalCents;
  final int itemsCount;
}
