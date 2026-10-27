class PackageOption {
  const PackageOption({required this.name, required this.amount, required this.unit, required this.priceCents});
  final String name;
  final double amount;
  final String unit;
  final int priceCents;
}

class PackageComparison {
  const PackageComparison({required this.name, required this.packages, required this.totalCents, required this.leftover});
  final String name;
  final int packages;
  final int totalCents;
  final double leftover;
}

double? normalizedAmount(PackageOption option) {
  switch (option.unit.toLowerCase()) {
    case 'g': return option.amount;
    case 'kg': return option.amount * 1000;
    case 'ml': return option.amount;
    case 'l': return option.amount * 1000;
    case 'un':
    case 'unidade':
    case 'unidades': return option.amount;
    default: return null;
  }
}

String? normalizedDimension(String unit) {
  switch (unit.toLowerCase()) {
    case 'g':
    case 'kg': return 'massa';
    case 'ml':
    case 'l': return 'volume';
    case 'un':
    case 'unidade':
    case 'unidades': return 'unidades';
    default: return null;
  }
}

bool areComparable(PackageOption a, PackageOption b) =>
    normalizedDimension(a.unit) != null &&
    normalizedDimension(a.unit) == normalizedDimension(b.unit) &&
    a.amount > 0 && b.amount > 0;

double? pricePerBaseUnit(PackageOption option) {
  final amount = normalizedAmount(option);
  if (amount == null || amount <= 0) return null;
  return option.priceCents / amount;
}

PackageComparison? calculatePackages(PackageOption option, double desiredBaseAmount) {
  final size = normalizedAmount(option);
  if (size == null || size <= 0 || desiredBaseAmount <= 0) return null;
  final count = (desiredBaseAmount / size).ceil();
  return PackageComparison(
    name: option.name,
    packages: count,
    totalCents: count * option.priceCents,
    leftover: count * size - desiredBaseAmount,
  );
}

List<int> quantitiesCost(int unitPriceCents) => [2, 5, 10, 20].map((n) => n * unitPriceCents).toList();
