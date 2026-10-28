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
    final pendingItems = active.where((i) => !i.isFullyBought).toList();

    // Se não há nenhum item cadastrado ou se todos já foram comprados
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
                'Cadastre seus produtos na aba "Lista Geral" para usar o guia de compras.',
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
            elevation: 2,
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
                    'Você concluiu sua lista de compras.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Todos os produtos cadastrados foram adquiridos. Deseja registrar e salvar esta compra no histórico?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Finalizar e salvar compra'),
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

    // Outras categorias futuras com itens pendentes
    final upcomingCategories = ProductCategory.all
        .where((cat) => cat != currentCategory && pendingItems.any((i) => i.category == cat))
        .toList();

    final catColor = ProductCategory.colorFor(currentCategory);
    final catIcon = ProductCategory.iconFor(currentCategory);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Indicador do Corredor / Categoria Atual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: catColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: catColor,
                child: Icon(catIcon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categoria atual',
                      style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currentCategory,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: catColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${categoryItems.length} pendente(s)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card de Destaque: O Próximo Produto a ser comprado
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRÓXIMO PRODUTO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
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
                const SizedBox(height: 12),
                Text(
                  currentItem.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Comprar agora', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            '${formatQuantity(currentItem.remainingQuantity)} ${currentItem.unit}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                      Container(height: 32, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('Preço unitário', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            formatCents(currentItem.actualUnitPriceCents ?? currentItem.unitPriceCents),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(height: 32, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            formatCents(currentItem.subtotalCents),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (currentItem.boughtQuantity > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Você já comprou ${formatQuantity(currentItem.boughtQuantity)} de ${formatQuantity(currentItem.quantity)} ${currentItem.unit}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ],
                const SizedBox(height: 20),

                // Botões de Ação Imediata
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmar compra deste item', style: TextStyle(fontSize: 16)),
                    onPressed: () => onConfirmPurchase(currentItem),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Escanear embalagem/preço'),
                    onPressed: () => onScanItem(currentItem),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Demais itens na mesma categoria
        if (otherItemsInCategory.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Ainda nesta categoria ($currentCategory):',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final nextItem in otherItemsInCategory)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(nextItem.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Falta: ${formatQuantity(nextItem.remainingQuantity)} ${nextItem.unit} • ${formatCents(nextItem.actualUnitPriceCents ?? nextItem.unitPriceCents)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Confirmar agora',
                  onPressed: () => onConfirmPurchase(nextItem),
                ),
              ),
            ),
        ],

        // Próximas categorias
        if (upcomingCategories.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Próximos corredores:',
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
