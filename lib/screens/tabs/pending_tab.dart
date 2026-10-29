import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/shopping_item.dart';
import '../../services/money.dart';
import '../../services/quantity.dart';
import '../../theme/app_theme.dart';

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
    final progressRatio = totalDistinct == 0 ? 0.0 : (boughtDistinct / totalDistinct);
    final progressPercentage = (progressRatio * 100).round();

    final pendingItems = active.where((i) => !i.isFullyBought).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        // Cartão de Progresso e Itens Pendentes
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.cardDecoration(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: AppTheme.softOrange),
                      const SizedBox(width: 6),
                      Text(
                        '$remainingDistinct itens pendentes',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.softOrange,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$progressPercentage%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDarkGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressRatio,
                  minHeight: 8,
                  backgroundColor: AppTheme.lightGreen,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Produtos comprados: $boughtDistinct de $totalDistinct',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (pendingItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AppTheme.cardDecoration(radius: 18, withShadow: false),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppTheme.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    totalDistinct == 0 ? Icons.playlist_add : Icons.task_alt,
                    size: 44,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  totalDistinct == 0
                      ? 'Sua lista está vazia.\nAdicione produtos para começar suas compras.'
                      : 'Tudo pronto!\nTodos os produtos cadastrados foram comprados.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryText,
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final cat in ProductCategory.all) ...[
            if (pendingItems.any((i) => i.category == cat)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8, left: 4),
                child: Row(
                  children: [
                    Icon(
                      ProductCategory.iconFor(cat),
                      size: 18,
                      color: ProductCategory.colorFor(cat),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ProductCategory.colorFor(cat),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${pendingItems.where((i) => i.category == cat).length} pendente(s)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
              for (final item in pendingItems.where((i) => i.category == cat))
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppTheme.cardDecoration(radius: 16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    leading: Checkbox(
                      value: item.isFullyBought,
                      onChanged: (_) => onConfirmPurchase(item),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatQuantity(item.remainingQuantity)} ${item.unit}${(item.actualUnitPriceCents ?? item.unitPriceCents) > 0 ? ' • ${formatCents(item.actualUnitPriceCents ?? item.unitPriceCents)}' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ProductCategory.colorFor(item.category).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ProductCategory.colorFor(item.category),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Fotografar preço',
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppTheme.primaryDarkGreen,
                            size: 20,
                          ),
                          onPressed: () => onScanItem(item),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ],
    );
  }
}
