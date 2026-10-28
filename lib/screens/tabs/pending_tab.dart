import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/shopping_item.dart';
import '../../services/money.dart';
import '../../services/quantity.dart';

class PendingTab extends StatelessWidget {
  const PendingTab({
    super.key,
    required this.items,
    required this.onConfirmPurchase,
    required this.onScanItem,
  });

  final List<ShoppingItem> items;
  final Future<void> Function(ShoppingItem item) onConfirmPurchase;
  final Future<void> Function(ShoppingItem? targetItem) onScanItem;

  @override
  Widget build(BuildContext context) {
    final active = items.where((i) => i.replacedBy == null).toList();
    final totalDistinct = active.length;
    final boughtDistinct = active.where((i) => i.isFullyBought).length;
    final remainingDistinct = totalDistinct - boughtDistinct;
    final partialDistinct = active.where((i) => i.isPartiallyBought).length;

    final progressRatio = totalDistinct == 0 ? 0.0 : (boughtDistinct / totalDistinct);
    final progressPercentage = (progressRatio * 100).round();

    final pendingItems = active.where((i) => !i.isFullyBought).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card de Progresso Baseado em Itens Distintos
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progresso da compra',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$progressPercentage%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalDistinct == 0 ? 0 : progressRatio,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Produtos comprados: $boughtDistinct de $totalDistinct',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Restantes: $remainingDistinct',
                        style: TextStyle(
                          color: remainingDistinct > 0 ? Colors.orange.shade800 : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (partialDistinct > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$partialDistinct produto(s) com compra parcial em andamento',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (pendingItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      totalDistinct == 0 ? Icons.playlist_add : Icons.task_alt,
                      size: 56,
                      color: totalDistinct == 0 ? Colors.grey : Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      totalDistinct == 0
                          ? 'Sua lista está vazia.\nAdicione produtos para começar suas compras.'
                          : 'Tudo pronto!\nTodos os produtos cadastrados foram comprados.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (final cat in ProductCategory.all) ...[
              if (pendingItems.any((i) => i.category == cat)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Row(
                    children: [
                      Icon(ProductCategory.iconFor(cat), size: 20, color: ProductCategory.colorFor(cat)),
                      const SizedBox(width: 8),
                      Text(
                        cat,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ProductCategory.colorFor(cat),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pendingItems.where((i) => i.category == cat).length} pendente(s)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                for (final item in pendingItems.where((i) => i.category == cat))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (item.isPartiallyBought)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade400),
                                  ),
                                  child: Text(
                                    'Parcial',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Pendente',
                                    style: TextStyle(fontSize: 11, color: Colors.black87),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Desejada: ${formatQuantity(item.quantity)} ${item.unit}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (item.boughtQuantity > 0)
                                      Text(
                                        'Já comprada: ${formatQuantity(item.boughtQuantity)} ${item.unit}',
                                        style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                                      ),
                                    Text(
                                      'Falta: ${formatQuantity(item.remainingQuantity)} ${item.unit}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Preço un: ${formatCents(item.actualUnitPriceCents ?? item.unitPriceCents)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Subtotal: ${formatCents(item.subtotalCents)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Escanear'),
                                onPressed: () => onScanItem(item),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Confirmar compra'),
                                onPressed: () => onConfirmPurchase(item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
