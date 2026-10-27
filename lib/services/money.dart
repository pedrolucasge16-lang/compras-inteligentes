String formatCents(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final reais = value ~/ 100;
  final centavos = (value % 100).toString().padLeft(2, '0');
  final grouped = reais.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return '${negative ? '-' : ''}R\$ $grouped,$centavos';
}

int parseMoneyToCents(String value) {
  var normalized = value.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (normalized.contains(',') && normalized.contains('.')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else if (normalized.contains(',')) {
    normalized = normalized.replaceAll(',', '.');
  }
  final amount = double.tryParse(normalized);
  if (amount == null || amount < 0) return 0;
  return (amount * 100).round();
}

String centsToInput(int cents) => (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
