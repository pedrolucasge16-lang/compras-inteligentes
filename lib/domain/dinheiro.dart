/// Formata centavos como moeda brasileira. Ex.: 1299 -> "R$ 12,99".
String formatarReais(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final reais = (abs ~/ 100).toString();
  final cent = (abs % 100).toString().padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buffer.write('.');
    buffer.write(reais[i]);
  }
  return '${negativo ? '-' : ''}R\$ ${buffer.toString()},$cent';
}

/// Formata centavos sem o "R$". Ex.: 1299 -> "12,99".
String centavosParaTexto(int centavos) {
  final cent = (centavos.abs() % 100).toString().padLeft(2, '0');
  return '${centavos ~/ 100},$cent';
}

/// Converte texto digitado ("12,99", "12.99", "1.234,50", "5") em centavos.
/// Retorna null se o texto for inválido.
int? lerReais(String texto) {
  var t = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final reais = int.parse(m.group(1)!);
  final cent = int.parse((m.group(2) ?? '0').padRight(2, '0'));
  return reais * 100 + cent;
}
