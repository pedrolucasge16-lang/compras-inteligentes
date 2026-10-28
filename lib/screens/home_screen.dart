import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/money.dart';
import '../services/ocr_service.dart';
import '../services/product_matcher.dart';
import '../services/quantity.dart';
import 'history_screen.dart';
import 'comparator_screen.dart';
import 'tabs/next_item_tab.dart';
import 'tabs/pending_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseService.instance;
  List<ShoppingItem> items = [];
  int budget = 0;
  bool loading = true;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await db.getItems();
    final b = await db.getBudget();
    if (!mounted) return;
    setState(() {
      items = data;
      budget = b;
      loading = false;
    });
  }

  List<ShoppingItem> get activeItems => items.where((i) => i.replacedBy == null).toList();
  int get total => activeItems.fold(0, (sum, item) => sum + item.subtotalCents);
  int get boughtTotal => activeItems
      .where((i) => i.isFullyBought || i.isPartiallyBought)
      .fold(0, (sum, item) => sum + item.boughtSubtotalCents);

  Future<void> _editItem([ShoppingItem? old, OcrSuggestion? suggestion]) async {
    final name = TextEditingController(text: suggestion?.productName ?? old?.name ?? '');
    final qty = TextEditingController(text: formatQuantity(old?.quantity ?? 1));
    final price = TextEditingController(text: centsToInput(suggestion?.priceCents ?? old?.unitPriceCents ?? 0));
    String unit = old?.unit ?? 'un';
    String category = old?.category ?? ProductCategory.outros;

    final result = await showDialog<ShoppingItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(old == null ? 'Adicionar produto' : 'Editar produto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestion != null) ...[
                  if (suggestion.priceCents == null)
                    const Text(
                      'Nenhum preço encontrado na foto. Digite o preço manualmente.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    )
                  else if (suggestion.ambiguous)
                    const Text(
                      'Encontrei mais de um preço. Toque no correto:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    )
                  else
                    const Text('Confira o nome e o preço lidos antes de salvar.'),
                  if (suggestion.candidates.length > 1) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in suggestion.candidates)
                          ActionChip(
                            label: Text(formatCents(c)),
                            onPressed: () => setD(() => price.text = centsToInput(c)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Texto lido: ${suggestion.text.replaceAll('\n', ' | ')}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome do produto'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: ProductCategory.all.map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(ProductCategory.iconFor(c), size: 18, color: ProductCategory.colorFor(c)),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => category = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantidade desejada'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: const [
                    DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
                    DropdownMenuItem(value: 'kg', child: Text('Quilograma (kg)')),
                    DropdownMenuItem(value: 'g', child: Text('Grama (g)')),
                    DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                    DropdownMenuItem(value: 'ml', child: Text('Mililitro (ml)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => unit = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Preço unitário estimado (R\$)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final q = double.tryParse(qty.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty || q == null || q <= 0) return;
                Navigator.pop(
                  ctx,
                  ShoppingItem(
                    id: old?.id,
                    name: name.text.trim(),
                    quantity: q,
                    unit: unit,
                    unitPriceCents: parseMoneyToCents(price.text),
                    isBought: old?.isBought ?? false,
                    replacedBy: old?.replacedBy,
                    originalItemId: old?.originalItemId,
                    originalItemName: old?.originalItemName,
                    actualUnitPriceCents: old?.actualUnitPriceCents,
                    category: category,
                    boughtQuantity: old?.boughtQuantity ?? 0.0,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await db.saveItem(result);
      await _load();
    }
  }

  Future<void> _changeQuantity(ShoppingItem item, int direction) async {
    if (item.replacedBy != null) return;
    final next = nextQuantity(item.quantity, item.unit, direction);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A quantidade precisa ser maior que zero.')),
      );
      return;
    }
    await db.saveItem(item.copyWith(quantity: next));
    await _load();
  }

  /// Diálogo central para confirmação de compra (total ou parcial) com suporte a preço real
  Future<void> _confirmPurchaseDialog(ShoppingItem item, {int? ocrSuggestedPrice}) async {
    final remaining = item.remainingQuantity;
    final qtyController = TextEditingController(text: formatQuantity(remaining));
    final priceToUse = ocrSuggestedPrice ?? item.actualUnitPriceCents ?? item.unitPriceCents;
    final priceController = TextEditingController(text: centsToInput(priceToUse));
    bool markAsCompleted = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final currentQtyVal = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0.0;
          final isPartial = currentQtyVal > 0 && currentQtyVal < remaining;

          return AlertDialog(
            title: Row(
              children: [
                Icon(ProductCategory.iconFor(item.category), color: ProductCategory.colorFor(item.category)),
                const SizedBox(width: 8),
                Expanded(child: Text(item.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categoria: ${item.category}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Total desejado na lista: ${formatQuantity(item.quantity)} ${item.unit}'),
                  if (item.boughtQuantity > 0)
                    Text('Já comprado antes: ${formatQuantity(item.boughtQuantity)} ${item.unit}',
                        style: TextStyle(color: Colors.blue.shade800)),
                  Text('Faltam comprar: ${formatQuantity(remaining)} ${item.unit}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const Divider(height: 20),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantidade comprada agora (${item.unit})',
                      helperText: 'Ajuste caso não tenha encontrado todas as unidades.',
                    ),
                    onChanged: (v) => setD(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Preço unitário real (R\$)',
                      helperText: ocrSuggestedPrice != null ? 'Preço sugerido pela câmera.' : null,
                    ),
                  ),
                  if (isPartial) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: markAsCompleted,
                      title: const Text('Concluir item mesmo assim', style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                        'Desmarque se você pretende procurar o restante em outro momento.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (v) => setD(() => markAsCompleted = v ?? false),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar compra'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final boughtQtyNow = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0.0;
    if (boughtQtyNow <= 0) return;

    final paidPriceCents = parseMoneyToCents(priceController.text);
    final totalBoughtSoFar = (item.boughtQuantity + boughtQtyNow);
    final isFullyDone = (totalBoughtSoFar >= item.quantity) || markAsCompleted;

    final updated = item.copyWith(
      boughtQuantity: isFullyDone ? item.quantity : totalBoughtSoFar,
      isBought: isFullyDone,
      actualUnitPriceCents: paidPriceCents > 0 ? paidPriceCents : item.unitPriceCents,
    );

    await db.saveItem(updated);
    await _load();
  }

  Future<void> _toggleBought(ShoppingItem item, bool bought) async {
    if (!bought) {
      await db.saveItem(item.copyWith(isBought: false, boughtQuantity: 0.0, clearActualPrice: true));
      await _load();
      return;
    }
    await _confirmPurchaseDialog(item);
  }

  Future<void> _replace(ShoppingItem item) async {
    final name = TextEditingController();
    final price = TextEditingController();
    String category = item.category;

    final result = await showDialog<(String, int, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Trocar ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome do substituto'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: ProductCategory.all.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  if (v != null) setD(() => category = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Preço unitário (R\$)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, (name.text.trim(), parseMoneyToCents(price.text), category));
                }
              },
              child: const Text('Substituir'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    await db.saveItem(item.copyWith(replacedBy: result.$1));
    await db.saveItem(ShoppingItem(
      name: result.$1,
      quantity: item.remainingQuantity > 0 ? item.remainingQuantity : item.quantity,
      unit: item.unit,
      unitPriceCents: result.$2,
      category: result.$3,
      originalItemId: item.id,
      originalItemName: item.name,
    ));
    await _load();
  }

  Future<void> _budgetDialog() async {
    final controller = TextEditingController(text: centsToInput(budget));
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Definir orçamento'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Orçamento total (R\$)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseMoneyToCents(controller.text)),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (value != null) {
      await db.setBudget(value);
      await _load();
    }
  }

  /// Fluxo de leitura inteligente por OCR:
  /// Se `targetItem` for informado, valida e confirma diretamente para aquele produto.
  /// Se nenhum item for informado, compara o texto lido com a lista cadastrada.
  Future<void> _scan([ShoppingItem? targetItem]) async {
    XFile? image;
    try {
      image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('denied');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(denied
            ? 'Sem permissão da câmera. Ative nas configurações do aparelho.'
            : 'Não foi possível abrir a câmera: ${e.message ?? e.code}'),
      ));
      return;
    }
    if (image == null) return;

    try {
      final suggestion = await OcrService.readImage(image.path);
      if (!mounted) return;

      if (suggestion.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ler o texto. Tente outra foto ou selecione manualmente.')),
        );
        return;
      }

      // Se foi escaneado a partir de um item específico
      if (targetItem != null) {
        await _confirmPurchaseDialog(targetItem, ocrSuggestedPrice: suggestion.priceCents);
        return;
      }

      // Comparação inteligente contra a lista ativa
      final matchResult = ProductMatcher.match(suggestion, activeItems);

      switch (matchResult.confidence) {
        case MatchConfidence.exact:
        case MatchConfidence.high:
          final matched = matchResult.bestItem!;
          final confirmMatch = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Produto reconhecido!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Identificamos:', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    matched.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text('Categoria: ${matched.category}', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  if (matchResult.suggestedPriceCents != null)
                    Text('Preço identificado no rótulo: ${formatCents(matchResult.suggestedPriceCents!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  const SizedBox(height: 6),
                  Text('Texto lido pela câmera: "${suggestion.productName ?? suggestion.text.split('\n').first}"',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 14),
                  const Text('Deseja confirmar a compra deste produto?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Não é este'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sim, confirmar'),
                ),
              ],
            ),
          );

          if (confirmMatch == true) {
            await _confirmPurchaseDialog(matched, ocrSuggestedPrice: matchResult.suggestedPriceCents);
          } else if (confirmMatch == false) {
            await _showManualChoiceDialog(suggestion);
          }
          break;

        case MatchConfidence.ambiguous:
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Produtos semelhantes encontrados'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A câmera leu: "${suggestion.productName ?? suggestion.text.split('\n').first}"',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    const Text('Selecione qual produto você está comprando:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final cand in matchResult.candidates)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(ProductCategory.iconFor(cand.item.category),
                            color: ProductCategory.colorFor(cand.item.category)),
                        title: Text(cand.item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Falta: ${formatQuantity(cand.item.remainingQuantity)} ${cand.item.unit}'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _confirmPurchaseDialog(cand.item, ocrSuggestedPrice: matchResult.suggestedPriceCents);
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showManualChoiceDialog(suggestion);
                  },
                  child: const Text('Nenhum destes'),
                ),
              ],
            ),
          );
          break;

        case MatchConfidence.none:
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Produto não encontrado na lista'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Texto lido: "${suggestion.productName ?? suggestion.text.replaceAll('\n', ' ')}"',
                      style: const TextStyle(fontSize: 13)),
                  if (suggestion.priceCents != null) ...[
                    const SizedBox(height: 6),
                    Text('Preço lido: ${formatCents(suggestion.priceCents!)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                  const SizedBox(height: 12),
                  const Text('O que você gostaria de fazer?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showManualChoiceDialog(suggestion);
                  },
                  child: const Text('Escolher da lista'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _editItem(null, suggestion);
                  },
                  child: const Text('Cadastrar novo item'),
                ),
              ],
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na leitura: $e')));
      }
    }
  }

  Future<void> _showManualChoiceDialog(OcrSuggestion suggestion) async {
    final pending = activeItems.where((i) => !i.isFullyBought).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há produtos pendentes na lista.')),
      );
      return;
    }

    final chosen = await showDialog<ShoppingItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escolha o produto da lista'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pending.length,
            itemBuilder: (ctx, i) {
              final it = pending[i];
              return ListTile(
                leading: Icon(ProductCategory.iconFor(it.category), color: ProductCategory.colorFor(it.category)),
                title: Text(it.name),
                subtitle: Text('${it.category} • Falta: ${formatQuantity(it.remainingQuantity)} ${it.unit}'),
                onTap: () => Navigator.pop(ctx, it),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );

    if (chosen != null) {
      await _confirmPurchaseDialog(chosen, ocrSuggestedPrice: suggestion.priceCents);
    }
  }

  Future<void> _finish() async {
    final boughtCount = activeItems.where((i) => i.isFullyBought || i.isPartiallyBought).length;
    if (boughtCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marque pelo menos um produto como comprado.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar e salvar compra?'),
        content: const Text(
          'Os produtos comprados serão salvos no histórico. Itens que ainda restarem pendentes continuarão na lista para a próxima compra.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await db.finishPurchase();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra salva no histórico com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _buildGeneralListTab() {
    final over = budget > 0 && total > budget;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total da lista', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(formatCents(total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Orçamento: ${budget == 0 ? 'não definido' : formatCents(budget)}'),
                      ),
                      TextButton(onPressed: _budgetDialog, child: const Text('Definir')),
                    ],
                  ),
                  if (budget > 0)
                    Text(
                      over
                          ? 'Orçamento ultrapassado em ${formatCents(total - budget)}'
                          : 'Saldo disponível: ${formatCents(budget - total)}',
                      style: TextStyle(color: over ? Colors.red : Colors.green, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 8),
                  Text('Comprado: ${formatCents(boughtTotal)} • Pendente: ${formatCents(total - boughtTotal)}'),
                  Text(
                    '${activeItems.where((i) => i.isFullyBought).length} concluídos • ${activeItems.where((i) => !i.isFullyBought).length} pendentes',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _editItem(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _scan(),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Fotografar'),
              ),
              OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check_circle),
                label: const Text('Finalizar compra'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Sua lista está vazia. Adicione seu primeiro produto.'),
                ],
              ),
            ),
          ...items.map((item) {
            final replaced = item.replacedBy != null;
            return Card(
              child: ListTile(
                leading: replaced
                    ? const Icon(Icons.swap_horiz, color: Colors.orange)
                    : Checkbox(
                        value: item.isFullyBought,
                        onChanged: (v) => _toggleBought(item, v ?? false),
                      ),
                isThreeLine: !replaced,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          decoration: replaced ? TextDecoration.lineThrough : null,
                          color: replaced ? Colors.grey : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!replaced)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ProductCategory.colorFor(item.category).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ProductCategory.colorFor(item.category),
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: replaced
                    ? Text('Substituído por ${item.replacedBy}')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preço unitário: ${formatCents(item.actualUnitPriceCents ?? item.unitPriceCents)}${item.isFullyBought ? ' (confirmado)' : ' (estimado)'}',
                          ),
                          Text(
                            'Subtotal: ${formatCents(item.subtotalCents)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (item.boughtQuantity > 0 && !item.isFullyBought)
                            Text(
                              'Parcial: ${formatQuantity(item.boughtQuantity)} / ${formatQuantity(item.quantity)} ${item.unit} comprados',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                            ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Diminuir quantidade',
                                iconSize: 24,
                                onPressed: nextQuantity(item.quantity, item.unit, -1) == null
                                    ? null
                                    : () => _changeQuantity(item, -1),
                                icon: const Icon(Icons.remove),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${formatQuantity(item.quantity)} ${item.unit}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Aumentar quantidade',
                                iconSize: 24,
                                onPressed: () => _changeQuantity(item, 1),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                trailing: replaced
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _editItem(item);
                          if (v == 'replace') await _replace(item);
                          if (v == 'delete') {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Excluir produto?'),
                                content: Text('Deseja excluir ${item.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true && item.id != null) {
                              await db.deleteItem(item.id!);
                              await _load();
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'replace', child: Text('Trocar produto')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0
              ? 'Compras Inteligentes'
              : _currentTabIndex == 1
                  ? 'Faltam Comprar'
                  : 'Próximo Item',
        ),
        actions: [
          IconButton(
            tooltip: 'Comparador',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparatorScreen()),
            ),
            icon: const Icon(Icons.compare_arrows),
          ),
          IconButton(
            tooltip: 'Histórico',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
              await _load();
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildGeneralListTab(),
          PendingTab(
            items: items,
            onConfirmPurchase: (item) => _confirmPurchaseDialog(item),
            onScanItem: (target) => _scan(target),
          ),
          NextItemTab(
            items: items,
            onConfirmPurchase: (item) => _confirmPurchaseDialog(item),
            onScanItem: (target) => _scan(target),
            onFinishPurchase: _finish,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted),
            label: 'Minha Lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.pending_actions),
            label: 'Faltam Comprar',
          ),
          NavigationDestination(
            icon: Icon(Icons.assistant_navigation),
            label: 'Próximo Item',
          ),
        ],
      ),
    );
  }
}
