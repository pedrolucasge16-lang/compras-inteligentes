import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/money.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseService.instance;
  List<Map<String, Object?>> purchases = [];
  int spend = 0;
  bool loading = true;

  Future<void> load() async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final p = await db.getPurchasesSince(since);
    final s = await db.getSpendSince(since);
    if (mounted) setState(() { purchases = p; spend = s; loading = false; });
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico — últimos 30 dias')),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(title: const Text('Total gasto no período'), subtitle: Text(formatCents(spend), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
      if (purchases.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma compra finalizada nos últimos 30 dias.')),
      ...purchases.map((p) {
        final date = DateTime.tryParse(p['purchased_at'] as String) ?? DateTime.now();
        return Card(child: ListTile(
          leading: const Icon(Icons.receipt_long),
          title: Text(formatCents(p['total_cents'] as int)),
          subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(date)} • ${p['items_count']} produtos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final id = p['id'] as int;
            final rows = await db.getPurchaseItems(id);
            if (!context.mounted) return;
            showDialog<void>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Itens da compra'),
              content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: rows.map((item) =>
                ListTile(
                  title: Text(item['name'] as String),
                  subtitle: Text('${item['quantity']} ${item['unit']} × ${formatCents(item['unit_price_cents'] as int)}${item['replaced_from'] == null ? '' : '\nSubstituiu: ${item['replaced_from']}'}\nToque para comparar com compras anteriores'),
                  trailing: IconButton(
                    tooltip: 'Adicionar novamente à lista',
                    icon: const Icon(Icons.add_shopping_cart),
                    onPressed: () async {
                      await db.saveItem(ShoppingItem(
                        name: item['name'] as String,
                        quantity: (item['quantity'] as num).toDouble(),
                        unit: item['unit'] as String,
                        unitPriceCents: (item['unit_price_cents'] as num).toInt(),
                      ));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${item['name']} adicionado à lista.')));
                      }
                    },
                  ),
                  onTap: () async {
                    final history = await db.getPriceHistory(item['name'] as String);
                    if (!ctx.mounted) return;
                    showDialog<void>(context: ctx, builder: (hctx) => AlertDialog(
                      title: Text('Histórico de preço: ${item['name']}'),
                      content: SizedBox(width: double.maxFinite, child: history.isEmpty
                        ? const Text('Não há registros anteriores deste produto.')
                        : ListView(shrinkWrap: true, children: history.map((h) {
                            final d = DateTime.tryParse(h['purchased_at'] as String) ?? DateTime.now();
                            return ListTile(
                              title: Text(formatCents((h['unit_price_cents'] as num).toInt()) + ' por ${h['unit']}'),
                              subtitle: Text(DateFormat('dd/MM/yyyy').format(d) + ' • ${h['quantity']} ${h['unit']}'),
                              trailing: Text(formatCents((h['subtotal_cents'] as num).toInt())),
                            );
                          }).toList())),
                      actions: [TextButton(onPressed: () => Navigator.pop(hctx), child: const Text('Fechar'))],
                    ));
                  },
                )).toList())),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
            ));
          },
        ));
      }),
    ]),
  );
}
