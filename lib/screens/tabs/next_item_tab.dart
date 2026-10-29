import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/shopping_item.dart';
import '../../services/money.dart';
import '../../services/quantity.dart';

class NextItemTab extends StatelessWidget {
  const NextItemTab({
    super.key,
    required this.items,
    required this.onConfirmPurchase,
    required this.onScanItem,
    required this.onFinishPurchase,
  });

  final List<ShoppingItem> items;
  final Future<void> Function(ShoppingItem item) onConfirmPurchase;
  final Future<void> Function(ShoppingItem? targetItem) onScanItem;
  final Future<void> Function() onFinishPurchase;

  @override
  Widget build(BuildContext context) {
    final active = items.where((i) => i.replacedBy == null).toList();
    final totalDistinct = active.length;
    final boughtDistinct = active.where((i) => i.isFullyBought).length;
    final remainingDistinct = totalDistinct - boughtDistinct;
    final pendingItems = active.where((i) => !i.isFullyBought).toList();

    if (active.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Sua lista está vazia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Anote os produtos na aba "Minha Lista" antes de ir ao supermercado para usar este guia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (pendingItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration, size: 56, color: Colors.green),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Parabéns!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Você comprou todos os itens da sua lista!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Todos os produtos foram riscados e seus valores somados. Deseja finalizar e arquivar no histórico?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Finalizar e salvar no histórico'),
                    onPressed: onFinishPurchase,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Encontra a primeira categoria da sequência fixa que possui itens pendentes
    String? currentCategory;
    for (final cat in ProductCategory.all) {
      if (pendingItems.any((i) => i.category == cat)) {
        currentCategory = cat;
        break;
      }
    }
    currentCategory ??= ProductCategory.outros;

    final categoryItems = pendingItems.where((i) => i.category == currentCategory).toList();
    final currentItem = categoryItems.first;
    final otherItemsInCategory = categoryItems.skip(1).toList();

    final allItemsInCategory = active.where((i) => i.category == currentCategory).toList();

    // Próximas categorias que possuem pendências
    final upcomingCategories = ProductCategory.all
        .where((cat) => cat != currentCategory && pendingItems.any((i) => i.category == cat))
        .toList();

    final catColor = ProductCategory.colorFor(currentCategory);
    final catIcon = ProductCategory.iconFor(currentCategory);

    final hasPrice = (currentItem.actualUnitPriceCents ?? currentItem.unitPriceCents) > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Placar Geral do Mercado
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_basket, size: 20, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      'Faltam $remainingDistinct de $totalDistinct produtos',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${((boughtDistinct / totalDistinct) * 100).round()}% concluído',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Banner da Seção Atual do Supermercado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: catColor.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: catColor,
                child: Icon(catIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VOCÊ ESTÁ NA SEÇÃO:',
                      style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    Text(
                      currentCategory,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: catColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  'Faltam ${categoryItems.length} de ${allItemsInCategory.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card Principal de Destaque: O Próximo Produto a pegar na prateleira
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PEGAR AGORA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (currentItem.isPartiallyBought)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          'Compra parcial',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  currentItem.name,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Quantidade', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '${formatQuantity(currentItem.remainingQuantity)} ${currentItem.unit}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                      Container(height: 36, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('Preço unitário', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            hasPrice
                                ? formatCents(currentItem.actualUnitPriceCents ?? currentItem.unitPriceCents)
                                : 'A definir pela foto',
                            style: TextStyle(
                              fontSize: hasPrice ? 18 : 13,
                              fontWeight: FontWeight.bold,
                              color: hasPrice ? Colors.black87 : Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (currentItem.boughtQuantity > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Você já pegou ${formatQuantity(currentItem.boughtQuantity)} de ${formatQuantity(currentItem.quantity)} ${currentItem.unit}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ],
                const SizedBox(height: 20),

                // Botão Primário: Fotografar a etiqueta na prateleira
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 22),
                    label: const Text(
                      'Tirar foto na prateleira (Ler preço)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => onScanItem(currentItem),
                  ),
                ),
                const SizedBox(height: 10),

                // Botão Secundário: Confirmar manualmente sem foto
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Confirmar sem foto / Digitar valor'),
                    onPressed: () => onConfirmPurchase(currentItem),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Produtos seguintes da mesma seção (para não sair do corredor)
        if (otherItemsInCategory.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(catIcon, size: 18, color: catColor),
              const SizedBox(width: 8),
              Text(
                'A seguir nesta mesma seção ($currentCategory):',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final nextItem in otherItemsInCategory)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(nextItem.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Quantidade: ${formatQuantity(nextItem.remainingQuantity)} ${nextItem.unit}'),
                trailing: IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.deepOrange),
                  tooltip: 'Fotografar este',
                  onPressed: () => onScanItem(nextItem),
                ),
                onTap: () => onConfirmPurchase(nextItem),
              ),
            ),
        ],

        // Próximas seções da lista
        if (upcomingCategories.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Próximas seções da sua lista:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in upcomingCategories)
                Chip(
                  avatar: Icon(ProductCategory.iconFor(cat), size: 16, color: ProductCategory.colorFor(cat)),
                  label: Text('$cat (${pendingItems.where((i) => i.category == cat).length})'),
                  backgroundColor: Colors.grey.shade100,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
