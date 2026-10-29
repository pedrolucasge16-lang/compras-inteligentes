import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/money.dart';
import '../services/quantity.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseService.instance;
  List<Map<String, Object?>> purchases = [];
  int total30Days = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final list = await db.getPurchasesSince(since);
    final spend = await db.getSpendSince(since);
    if (!mounted) return;
    setState(() {
      purchases = list;
      total30Days = spend;
      loading = false;
    });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Histórico de Compras'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Cartão de Resumo dos Últimos 30 Dias
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration(radius: 18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppTheme.lightGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: AppTheme.primaryDarkGreen,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total gasto (últimos 30 dias)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatCents(total30Days),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryDarkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${purchases.length} compra(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDarkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (purchases.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: AppTheme.cardDecoration(radius: 18, withShadow: false),
                    child: const Column(
                      children: [
                        Icon(Icons.history, size: 48, color: AppTheme.secondaryText),
                        SizedBox(height: 10),
                        Text(
                          'Nenhuma compra finalizada nos últimos 30 dias.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final p in purchases)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: AppTheme.cardDecoration(radius: 16),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.primaryDarkGreen,
                        ),
                        title: Text(
                          _formatDate(p['purchased_at'] as String),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        subtitle: Text(
                          '${p['items_count']} itens',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          formatCents((p['total_cents'] as num).toInt()),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        children: [
                          FutureBuilder<List<Map<String, Object?>>>(
                            future: db.getPurchaseItems((p['id'] as num).toInt()),
                            builder: (ctx, snap) {
                              if (!snap.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              final rows = snap.data!;
                              return Column(
                                children: [
                                  const Divider(height: 1),
                                  for (final item in rows)
                                    ListTile(
                                      dense: true,
                                      title: Text(
                                        item['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryText,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${formatQuantity((item['quantity'] as num).toDouble())} ${item['unit']} × ${formatCents((item['unit_price_cents'] as num).toInt())}'
                                        '${item['replaced_from'] != null ? ' (substituiu ${item['replaced_from']})' : ''}',
                                        style: const TextStyle(color: AppTheme.secondaryText),
                                      ),
                                      trailing: Text(
                                        formatCents((item['subtotal_cents'] as num).toInt()),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryDarkGreen,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
