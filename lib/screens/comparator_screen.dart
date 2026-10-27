import 'package:flutter/material.dart';
import '../services/money.dart';
import '../services/price_comparator.dart';

class ComparatorScreen extends StatefulWidget {
  const ComparatorScreen({super.key});
  @override
  State<ComparatorScreen> createState() => _ComparatorScreenState();
}

class _ComparatorScreenState extends State<ComparatorScreen> {
  final price = TextEditingController(text: '4,50');
  final aName = TextEditingController(text: 'Embalagem A');
  final aAmount = TextEditingController(text: '500');
  final aPrice = TextEditingController(text: '8,00');
  final bName = TextEditingController(text: 'Embalagem B');
  final bAmount = TextEditingController(text: '1');
  final bPrice = TextEditingController(text: '14,00');
  final desiredAmount = TextEditingController(text: '1000');
  String unitA = 'g';
  String unitB = 'kg';

  @override
  void dispose() {
    for (final c in [price, aName, aAmount, aPrice, bName, bAmount, bPrice, desiredAmount]) { c.dispose(); }
    super.dispose();
  }

  double readNumber(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final unitPriceCents = parseMoneyToCents(price.text);
    final costs = quantitiesCost(unitPriceCents);
    final optA = PackageOption(name: aName.text.trim().isEmpty ? 'Opção A' : aName.text.trim(), amount: readNumber(aAmount), unit: unitA, priceCents: parseMoneyToCents(aPrice.text));
    final optB = PackageOption(name: bName.text.trim().isEmpty ? 'Opção B' : bName.text.trim(), amount: readNumber(bAmount), unit: unitB, priceCents: parseMoneyToCents(bPrice.text));
    final comparable = areComparable(optA, optB);
    final perA = pricePerBaseUnit(optA);
    final perB = pricePerBaseUnit(optB);
    final winner = comparable && perA != null && perB != null ? (perA <= perB ? optA.name : optB.name) : null;
    final dimension = normalizedDimension(unitA);
    final displayUnit = dimension == 'massa' ? 'kg' : dimension == 'volume' ? 'L' : 'un';
    final desiredBase = readNumber(desiredAmount) * ((dimension == 'massa' || dimension == 'volume') ? 1000 : 1);
    final packA = comparable ? calculatePackages(optA, desiredBase) : null;
    final packB = comparable ? calculatePackages(optB, desiredBase) : null;

    Widget field(TextEditingController c, String label, {TextInputType keyboard = TextInputType.text}) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: keyboard,
        onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: label)));

    Widget packageFields({required String name, required TextEditingController nameController,
      required TextEditingController amountController, required TextEditingController priceController,
      required String unit, required ValueChanged<String?> onUnitChanged}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        field(nameController, 'Nome do produto'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: field(amountController, 'Conteúdo da embalagem', keyboard: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'Unidade'),
            items: const ['g', 'kg', 'ml', 'l', 'un'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: onUnitChanged)),
        ]),
        field(priceController, 'Preço da embalagem (R$)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
      ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Comparador inteligente')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Quanto vou gastar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('Informe o preço de uma unidade para calcular o custo de 2, 5, 10 e 20 unidades.'),
        const SizedBox(height: 12),
        field(price, 'Preço de uma unidade (R$)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ...[2, 5, 10, 20].asMap().entries.map((e) => Card(child: ListTile(
          title: Text('${[2, 5, 10, 20][e.key]} unidades'),
          trailing: Text(formatCents(costs[e.key]), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ))),
        const Divider(height: 36),
        const Text('Qual embalagem compensa?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('Compare massa com massa, volume com volume ou unidades com unidades.'),
        const SizedBox(height: 16),
        packageFields(name: 'Opção A', nameController: aName, amountController: aAmount, priceController: aPrice, unit: unitA,
          onUnitChanged: (v) => setState(() => unitA = v ?? 'g')),
        const SizedBox(height: 8),
        packageFields(name: 'Opção B', nameController: bName, amountController: bAmount, priceController: bPrice, unit: unitB,
          onUnitChanged: (v) => setState(() => unitB = v ?? 'kg')),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: comparable
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Custo equivalente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              Text('${optA.name}: ${formatCents(((perA ?? 0) * (dimension == 'massa' || dimension == 'volume' ? 1000 : 1)).round())} por $displayUnit'),
              Text('${optB.name}: ${formatCents(((perB ?? 0) * (dimension == 'massa' || dimension == 'volume' ? 1000 : 1)).round())} por $displayUnit'),
              const SizedBox(height: 8),
              Text('Mais econômica: $winner', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
            ])
          : const Text('Não é possível comparar: confira as quantidades e use unidades compatíveis.'))),
        const SizedBox(height: 12),
        const Text('Quantas embalagens preciso comprar?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        field(desiredAmount, dimension == 'massa' ? 'Quantidade desejada em kg' : dimension == 'volume' ? 'Quantidade desejada em litros' : 'Quantidade desejada em unidades', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        if (comparable && packA != null && packB != null) ...[
          Card(child: ListTile(title: Text(optA.name), subtitle: Text('${packA.packages} embalagem(ns) • sobra ${packA.leftover.toStringAsFixed(2)} unidade-base'), trailing: Text(formatCents(packA.totalCents)))),
          Card(child: ListTile(title: Text(optB.name), subtitle: Text('${packB.packages} embalagem(ns) • sobra ${packB.leftover.toStringAsFixed(2)} unidade-base'), trailing: Text(formatCents(packB.totalCents)))),
        ],
      ]),
    );
  }
}
