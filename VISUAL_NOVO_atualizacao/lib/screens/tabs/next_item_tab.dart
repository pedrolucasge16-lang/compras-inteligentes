import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/shopping_item.dart';
import '../../services/money.dart';
import '../../services/quantity.dart';
import '../../theme/app_theme.dart';

class NextItemTab extends StatefulWidget {
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
  State<NextItemTab> createState() => _NextItemTabState();
}

class _NextItemTabState extends State<NextItemTab> {
  int _skipOffset = 0;

  @override
  Widget build(BuildContext context) {
    final active = widget.items.where((i) => i.replacedBy == null).toList();
    final pendingItems = active.where((i) => !i.isFullyBought).toList();

    if (active.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: AppTheme.cardDecoration(radius: 20, withShadow: false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppTheme.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_basket_outlined,
                    size: 48,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sua lista está vazia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adicione os produtos na aba "Minha Lista" para utilizar o guia de compras por corredor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (pendingItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: AppTheme.cardDecoration(radius: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppTheme.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration,
                    size: 56,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Parabéns!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você concluiu sua lista de compras.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Todos os itens foram marcados como comprados. Deseja finalizar e arquivar no histórico?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onFinishPurchase,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Finalizar e salvar no histórico'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Encontra a primeira categoria na ordem fixa que possui itens pendentes
    String? currentCategory;
    for (final cat in ProductCategory.all) {
      if (pendingItems.any((i) => i.category == cat)) {
        currentCategory = cat;
        break;
      }
    }
    currentCategory ??= ProductCategory.outros;

    final categoryItems = pendingItems.where((i) => i.category == currentCategory).toList();
    final safeIndex = _skipOffset % categoryItems.length;
    final currentItem = categoryItems[safeIndex];
    final otherItemsInCategory = [
      for (var i = 0; i < categoryItems.length; i++)
        if (i != safeIndex) categoryItems[i],
    ];

    final upcomingCategories = ProductCategory.all
        .where((cat) => cat != currentCategory && pendingItems.any((i) => i.category == cat))
        .toList();

    final catColor = ProductCategory.colorFor(currentCategory);
    final catIcon = ProductCategory.iconFor(currentCategory);
    final hasPrice = (currentItem.actualUnitPriceCents ?? currentItem.unitPriceCents) > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
      children: [
        // Cartão Principal Estilo Vitrine (Conforme Mockup "Próximo Item")
        Container(
          decoration: AppTheme.cardDecoration(radius: 24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Topo Verde-escuro Elegante com o Nome e Ilustração do Produto
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryDarkGreen,
                      AppTheme.accentGreen,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SEÇÃO ATUAL: ${currentCategory.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentItem.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        catIcon,
                        size: 54,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Área Inferior Branca com Quantidade, Categoria e Botões de Ação
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quantidade: ${formatQuantity(currentItem.remainingQuantity)} ${currentItem.unit}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        if (hasPrice)
                          Text(
                            formatCents(currentItem.actualUnitPriceCents ?? currentItem.unitPriceCents),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Categoria: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          currentCategory,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botão Principal Verde-escuro: [✓ Marcar como comprado]
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDarkGreen,
                          foregroundColor: AppTheme.cardWhite,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () => widget.onConfirmPurchase(currentItem),
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('Marcar como comprado'),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Botão Secundário: [📷 Fotografar preço na prateleira]
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () => widget.onScanItem(currentItem),
                        icon: const Icon(Icons.camera_alt_outlined, size: 19),
                        label: const Text('Fotografar preço na prateleira'),
                      ),
                    ),

                    if (categoryItems.length > 1) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _skipOffset++),
                          child: const Text(
                            'Pular este item',
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Demais itens no mesmo corredor
        if (otherItemsInCategory.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Ainda nesta seção ($currentCategory):',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          for (final nextItem in otherItemsInCategory)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: AppTheme.cardDecoration(radius: 14, withShadow: false),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: catColor.withOpacity(0.12),
                  child: Icon(catIcon, color: catColor, size: 18),
                ),
                title: Text(
                  nextItem.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                subtitle: Text(
                  '${formatQuantity(nextItem.remainingQuantity)} ${nextItem.unit}',
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryDarkGreen),
                  onPressed: () => widget.onConfirmPurchase(nextItem),
                ),
              ),
            ),
        ],

        // Próximos corredores
        if (upcomingCategories.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Próximos corredores:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in upcomingCategories)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.subtleBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ProductCategory.iconFor(cat),
                        size: 15,
                        color: ProductCategory.colorFor(cat),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$cat (${pendingItems.where((i) => i.category == cat).length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
