/// Regras de quantidade usadas pelos botões [−] e [+] da lista.
///
/// Unidades usadas pelo app: un, kg, g, L, ml.
double quantityStep(String unit) {
  switch (unit.toLowerCase()) {
    case 'kg':
    case 'l':
      return 0.5;
    case 'g':
    case 'ml':
      return 100;
    default:
      return 1;
  }
}

/// Arredonda para 3 casas para evitar erros como 0.30000000000000004.
double _clean(double value) => (value * 1000).round() / 1000;

/// Devolve a próxima quantidade ao tocar em [+] (direction = 1)
/// ou [−] (direction = -1). Devolve `null` quando o resultado seria
/// zero ou negativo (a quantidade nunca chega a zero).
double? nextQuantity(double current, String unit, int direction) {
  final next = _clean(current + direction * quantityStep(unit));
  if (next <= 0) return null;
  return next;
}

/// Mostra 2 em vez de 2.0 e 0,5 em vez de 0.5.
String formatQuantity(double value) {
  final v = _clean(value);
  final text = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toString().replaceAll(RegExp(r'0+$'), '');
  return text.replaceAll('.', ',');
}
