import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/money.dart';
import '../services/ocr_service.dart';
import '../services/product_matcher.dart';
import '../services/quantity.dart';
import '../theme/app_theme.dart';
import 'create_list_screen.dart';
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
  String _selectedCategoryFilter = 'Todos';

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

  bool get isAllSelected =>
      activeItems.isNotEmpty && activeItems.every((i) => i.isFullyBought);

  /// Seleciona ou desmarca TODOS os itens da lista de uma vez (Select All)
  Future<void> _toggleSelectAll(bool selectAll) async {
    for (final item in activeItems) {
      final updated = item.copyWith(
        isBought: selectAll,
        boughtQuantity: selectAll ? item.quantity : 0.0,
      );
      await db.saveItem(updated);
    }
    await _load();
  }

  /// Marca ou desmarca um item individualmente direto no quadradinho
  Future<void> _toggleItemCheckbox(ShoppingItem item, bool checked) async {
    final updated = item.copyWith(
      isBought: checked,
      boughtQuantity: checked ? item.quantity : 0.0,
    );
    await db.saveItem(updated);
    await _load();
  }

  /// Abre a tela de adicionar itens à lista
  Future<void> _openQuickAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateListScreen()),
    );
    await _load();
  }

  /// Diálogo de adicionar ou editar produto (com detecção automática de categoria)
  Future<void> _editItem([ShoppingItem? old, OcrSuggestion? suggestion]) async {
    final name = TextEditingController(text: suggestion?.productName ?? old?.name ?? '');
    final qty = TextEditingController(text: formatQuantity(old?.quantity ?? 1));
    final initialPrice = suggestion?.priceCents ?? old?.actualUnitPriceCents ?? old?.unitPriceCents ?? 0;
    final price = TextEditingController(text: initialPrice > 0 ? centsToInput(initialPrice) : '');
    String unit = old?.unit ?? 'un';
    String category = old?.category ??
        (name.text.isNotEmpty ? ProductCategory.detectCategory(name.text) : ProductCategory.outros);
    bool manualCategory = old != null;

    final result = await showDialog<ShoppingItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.creamBackground,
          title: Text(old == null ? 'Adicionar produto' : 'Editar produto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestion != null) ...[
                  if (suggestion.priceCents == null)
                    const Text(
                      'Nenhum preço encontrado na foto. Digite manualmente se desejar.',
                      style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w600, fontSize: 13),
                    )
                  else if (suggestion.ambiguous)
                    const Text(
                      'Encontrei mais de um preço. Toque no correto:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  if (suggestion.candidates.length > 1) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in suggestion.candidates)
                          ActionChip(
                            backgroundColor: AppTheme.lightGreen,
                            label: Text(formatCents(c)),
                            onPressed: () => setD(() => price.text = centsToInput(c)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: name,
                  autofocus: old == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                    hintText: 'Ex: Peito de frango, Sabão, Leite...',
                  ),
                  onChanged: (val) {
                    if (!manualCategory) {
                      final detected = ProductCategory.detectCategory(val);
                      setD(() {
                        category = detected;
                        unit = ProductCategory.suggestUnit(val, detected);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                  ),
                  items: ProductCategory.all
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Icon(ProductCategory.iconFor(c),
                                    size: 18, color: ProductCategory.colorFor(c)),
                                const SizedBox(width: 8),
                                Text(c),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setD(() {
                        manualCategory = true;
                        category = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantidade'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: const [
                          DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
                          DropdownMenuItem(value: 'kg', child: Text('kg')),
                          DropdownMenuItem(value: 'g', child: Text('g')),
                          DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                        ],
                        onChanged: (v) {
                          if (v != null) setD(() => unit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Preço unitário estimado (R\$)',
                    hintText: 'Deixe vazio para ler na prateleira',
                  ),
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
                final parsedPrice = price.text.trim().isEmpty ? 0 : parseMoneyToCents(price.text);
                Navigator.pop(
                  ctx,
                  ShoppingItem(
                    id: old?.id,
                    name: name.text.trim(),
                    quantity: q,
                    unit: unit,
                    unitPriceCents: parsedPrice,
                    isBought: old?.isBought ?? false,
                    replacedBy: old?.replacedBy,
                    originalItemId: old?.originalItemId,
                    originalItemName: old?.originalItemName,
                    actualUnitPriceCents: parsedPrice > 0 ? parsedPrice : old?.actualUnitPriceCents,
                    category: category,
                    boughtQuantity: old?.boughtQuantity ?? 0.0,
                  ),
                );
              },
              child: const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      if (result.category != ProductCategory.outros) {
        await db.saveCustomCategoryItem(result.category, result.name);
      }
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
    await db.saveItem(item.copyWith(
      quantity: next,
      boughtQuantity: item.isBought ? next : item.boughtQuantity,
    ));
    await _load();
  }

  /// Ícone de câmera dentro do cartão do produto:
  /// Fotografa o preço na prateleira e registra o valor automaticamente no item!
  Future<void> _scanItemPriceAutomatically(ShoppingItem item) async {
    XFile? image;
    try {
      image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('denied');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(denied
            ? 'Sem permissão da câmera. Ative nas configurações do celular.'
            : 'Não foi possível abrir a câmera: ${e.message ?? e.code}'),
      ));
      return;
    }
    if (image == null) return;

    try {
      final suggestion = await OcrService.readImage(image.path);
      if (!mounted) return;

      final detectedPrice = suggestion.priceCents ??
          (suggestion.candidates.isNotEmpty ? suggestion.candidates.first : null);

      if (detectedPrice != null && detectedPrice > 0) {
        final updated = item.copyWith(
          unitPriceCents: detectedPrice,
          actualUnitPriceCents: detectedPrice,
          isBought: true,
          boughtQuantity: item.quantity,
        );
        await db.saveItem(updated);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryDarkGreen,
            content: Text(
              '✅ Preço ${formatCents(detectedPrice)} salvo automaticamente em "${item.name}"!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não encontrei o preço na foto. Digite o valor abaixo.'),
          ),
        );
        await _quickManualPriceDialog(item);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler foto: $e')),
        );
      }
    }
  }

  Future<void> _quickManualPriceDialog(ShoppingItem item) async {
    final ctrl = TextEditingController(
      text: item.effectiveUnitPriceCents > 0 ? centsToInput(item.effectiveUnitPriceCents) : '',
    );
    final val = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: Text('Preço de ${item.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Preço unitário (R\$)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseMoneyToCents(ctrl.text)),
            child: const Text('Salvar preço'),
          ),
        ],
      ),
    );
    if (val != null && val > 0) {
      await db.saveItem(item.copyWith(
        unitPriceCents: val,
        actualUnitPriceCents: val,
        isBought: true,
        boughtQuantity: item.quantity,
      ));
      await _load();
    }
  }

  /// Botão Fotografar do topo
  Future<void> _scanGeneral() async {
    XFile? image;
    try {
      image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('denied');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(denied
            ? 'Sem permissão da câmera. Ative nas configurações do celular.'
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
          const SnackBar(content: Text('Não foi possível ler o texto. Tente outra foto.')),
        );
        return;
      }

      final matchResult = ProductMatcher.match(suggestion, activeItems);
      if ((matchResult.confidence == MatchConfidence.exact ||
              matchResult.confidence == MatchConfidence.high) &&
          matchResult.bestItem != null &&
          suggestion.priceCents != null) {
        final matched = matchResult.bestItem!;
        final updated = matched.copyWith(
          unitPriceCents: suggestion.priceCents!,
          actualUnitPriceCents: suggestion.priceCents!,
          isBought: true,
          boughtQuantity: matched.quantity,
        );
        await db.saveItem(updated);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryDarkGreen,
            content: Text(
              '✅ "${matched.name}" atualizado com o preço ${formatCents(suggestion.priceCents!)}!',
            ),
          ),
        );
        return;
      }

      await _editItem(null, suggestion);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na leitura: $e')));
      }
    }
  }

  Future<void> _replace(ShoppingItem item) async {
    final name = TextEditingController();
    final price = TextEditingController();
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: Text('Trocar ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nome do substituto'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(ctx, (name.text.trim(), parseMoneyToCents(price.text)));
              }
            },
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await db.saveItem(item.copyWith(replacedBy: result.$1));
    await db.saveItem(ShoppingItem(
      name: result.$1,
      quantity: item.quantity,
      unit: item.unit,
      unitPriceCents: result.$2,
      category: ProductCategory.detectCategory(result.$1),
      originalItemId: item.id,
      originalItemName: item.name,
    ));
    await _load();
  }

  /// Diálogo de Orçamento da Lista com o visual do Redesign
  Future<void> _budgetDialog() async {
    final controller = TextEditingController(text: budget > 0 ? centsToInput(budget) : '');
    final spentRatio = budget > 0 ? (boughtTotal / budget).clamp(0.0, 1.0) : 0.0;
    final spentPct = (spentRatio * 100).round();

    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Text('Orçamento da Lista'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (budget > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.cardDecoration(radius: 14, withShadow: false),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orçamento definido',
                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                      Text(
                        formatCents(budget),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gasto até agora: ${formatCents(boughtTotal)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                          Text(
                            '$spentPct%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: spentRatio,
                          minHeight: 8,
                          backgroundColor: AppTheme.lightGreen,
                          color: boughtTotal > budget ? AppTheme.alertRed : AppTheme.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco, size: 18, color: AppTheme.primaryDarkGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                boughtTotal > budget
                                    ? 'Atenção: orçamento ultrapassado em ${formatCents(boughtTotal - budget)}.'
                                    : 'Dica: Você está dentro do orçamento!',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDarkGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Definir / Editar orçamento (R\$)',
                  hintText: 'Ex: 200,00',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseMoneyToCents(controller.text)),
            child: const Text('Salvar orçamento'),
          ),
        ],
      ),
    );
    if (value != null) {
      await db.setBudget(value);
      await _load();
    }
  }

  /// Finaliza a compra e exibe a tela de comprovante com o Total Gasto e a Data de Hoje
  Future<void> _confirmAndShowReceiptScreen() async {
    final selectedItems = activeItems.where((i) => i.isFullyBought || i.isPartiallyBought).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione os produtos (ou marque "Selecionar tudo") antes de finalizar.'),
        ),
      );
      return;
    }

    final totalSpentCents = selectedItems.fold<int>(0, (sum, i) => sum + i.subtotalCents);
    final now = DateTime.now();
    final dateFormatted = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(now);
    final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(now);
    final itemsSnapshot = List<ShoppingItem>.from(selectedItems);

    try {
      await db.finishPurchase();
      await _load();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: AppTheme.creamBackground,
          child: Scaffold(
            backgroundColor: AppTheme.creamBackground,
            appBar: AppBar(
              title: const Text('Resumo da Compra'),
              automaticallyImplyLeading: false,
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: AppTheme.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, size: 68, color: AppTheme.primaryDarkGreen),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Compra Confirmada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDarkGreen,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(radius: 18),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL QUE VOCÊ GASTOU',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatCents(totalSpentCents),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppTheme.accentGreen),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dia: $dateFormatted',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                              Text(
                                dayOfWeek.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Itens comprados (${itemsSnapshot.length}):',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 10),
                for (final it in itemsSnapshot)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppTheme.cardDecoration(radius: 14, withShadow: false),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.lightGreen,
                        child: Icon(
                          ProductCategory.iconFor(it.category),
                          color: AppTheme.primaryDarkGreen,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        it.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        '${formatQuantity(it.quantity)} ${it.unit} • ${it.category}',
                        style: const TextStyle(color: AppTheme.secondaryText),
                      ),
                      trailing: Text(
                        formatCents(it.subtotalCents),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir e Voltar ao Início'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Ver no Histórico de Compras'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// Constrói um cartão de produto elegante, branco, com borda discreta,
  /// controles de quantidade [-] 1 un [+], botão de câmera para preço e menu
  Widget _buildProductCard(ShoppingItem item) {
    final replaced = item.replacedBy != null;
    final catColor = ProductCategory.colorFor(item.category);
    final catIcon = ProductCategory.iconFor(item.category);
    final unitPrice = item.actualUnitPriceCents ?? item.unitPriceCents;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox de seleção
                if (replaced)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.swap_horiz, color: AppTheme.softOrange),
                  )
                else
                  Checkbox(
                    value: item.isFullyBought,
                    onChanged: (v) => _toggleItemCheckbox(item, v ?? false),
                  ),

                // Miniatura / Ícone da categoria estilizado
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.subtleBorder),
                  ),
                  child: Icon(catIcon, color: catColor, size: 24),
                ),
                const SizedBox(width: 12),

                // Nome, Categoria e Preço
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: replaced ? AppTheme.secondaryText : AppTheme.primaryText,
                          decoration: replaced ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ),
                          if (item.isFullyBought)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Comprado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryDarkGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (replaced)
                        Text(
                          'Substituído por ${item.replacedBy}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                        )
                      else ...[
                        Text(
                          item.actualUnitPriceCents != null
                              ? 'Preço unitário confirmado'
                              : 'Preço unitário estimado',
                          style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                        ),
                        Row(
                          children: [
                            Text(
                              formatCents(unitPrice),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryText,
                              ),
                            ),
                            if (item.quantity != 1) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• Sub: ${formatCents(item.subtotalCents)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Menu de 3 pontos (Editar, Trocar, Excluir)
                if (!replaced)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.secondaryText),
                    onSelected: (v) async {
                      if (v == 'edit') await _editItem(item);
                      if (v == 'replace') await _replace(item);
                      if (v == 'delete') {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.creamBackground,
                            title: const Text('Excluir produto?'),
                            content: Text('Deseja remover ${item.name} da lista?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remover da lista'),
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
                      PopupMenuItem(value: 'edit', child: Text('Detalhes / Editar')),
                      PopupMenuItem(value: 'replace', child: Text('Trocar produto')),
                      PopupMenuItem(value: 'delete', child: Text('Remover da lista')),
                    ],
                  ),
              ],
            ),

            // Linha inferior de controles do cartão: Cápsula [-] 1 kg [+] e botão [📷 Preço]
            if (!replaced) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cápsula de Quantidade [-] 1 kg [+]
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.creamBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.subtleBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: nextQuantity(item.quantity, item.unit, -1) == null
                              ? null
                              : () => _changeQuantity(item, -1),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: nextQuantity(item.quantity, item.unit, -1) == null
                                  ? AppTheme.subtleBorder
                                  : AppTheme.primaryText,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${formatQuantity(item.quantity)} ${item.unit}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryText,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _changeQuantity(item, 1),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Ícone de Câmera dentro do quadrado do item para ler o preço automaticamente
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _scanItemPriceAutomatically(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 16, color: AppTheme.primaryDarkGreen),
                          SizedBox(width: 5),
                          Text(
                            'Preço',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Constrói a Tela Principal "Minha Lista" com o Banner Fotográfico do Supermercado,
  /// Cartão de Resumo Financeiro em 2 colunas, Botões Arredondados e Filtros de Categoria
  Widget _buildMainTab() {
    final screenHeight = MediaQuery.of(context).size.height;
    final bannerHeight = (screenHeight * 0.23).clamp(175.0, 230.0);

    final over = budget > 0 && total > budget;
    final totalDistinct = activeItems.length;
    final boughtDistinct = activeItems.where((i) => i.isFullyBought).length;
    final remainingDistinct = totalDistinct - boughtDistinct;

    // Progresso: se houver orçamento definido, exibe quanto do orçamento já foi utilizado;
    // se não houver orçamento definido, exibe o progresso de conclusão dos itens.
    final progressRatio = budget > 0
        ? (total / budget).clamp(0.0, 1.0)
        : (totalDistinct == 0 ? 0.0 : (boughtDistinct / totalDistinct).clamp(0.0, 1.0));
    final progressPercentage = (progressRatio * 100).round();

    final filteredItems = _selectedCategoryFilter == 'Todos'
        ? items
        : items.where((i) => i.category == _selectedCategoryFilter).toList();

    return RefreshIndicator(
      color: AppTheme.primaryDarkGreen,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. BANNER FOTOGRÁFICO DO SUPERMERCADO + CARTÃO DE RESUMO FINANCEIRO SOBREPOSTO
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Imagem de fundo em banner horizontal (~22% da altura da tela)
              SizedBox(
                height: bannerHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      AppTheme.bannerAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryDarkGreen, AppTheme.accentGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    // Camada de gradiente suave para legibilidade perfeita do título e ícones
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.65),
                            Colors.black.withOpacity(0.25),
                            Colors.black.withOpacity(0.45),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cabeçalho com título "Compras Inteligentes" e ícones de ação
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Compras Inteligentes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Comparador de preços',
                          icon: const Icon(Icons.compare_arrows, color: Colors.white),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComparatorScreen()),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Histórico de compras',
                          icon: const Icon(Icons.history, color: Colors.white),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            );
                            await _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Cartão de Resumo Financeiro posicionado na base do banner
              Padding(
                padding: EdgeInsets.fromLTRB(16, bannerHeight - 48, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration(radius: 20),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Coluna Esquerda: Total da lista + Orçamento + Barra de progresso
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Total da lista',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatCents(total),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryDarkGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _budgetDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          budget == 0
                                              ? 'Orçamento: Definir'
                                              : 'Orçamento: ${formatCents(budget)}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: over ? AppTheme.alertRed : AppTheme.secondaryText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: progressRatio,
                                        minHeight: 7,
                                        backgroundColor: AppTheme.lightGreen,
                                        color: over ? AppTheme.alertRed : AppTheme.accentGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$progressPercentage%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Divisor Vertical Discreto
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: AppTheme.subtleBorder,
                        ),

                        // Coluna Direita: Comprado, Pendente, Concluídos, Pendentes
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 15,
                                    color: AppTheme.accentGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Comprado: ${formatCents(boughtTotal)}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 15,
                                    color: AppTheme.lightWood,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pendente: ${formatCents((total - boughtTotal) < 0 ? 0 : (total - boughtTotal))}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppTheme.accentGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$boughtDistinct concluídos',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: AppTheme.softOrange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$remainingDistinct pendentes',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.softOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. CORPO DA TELA EM FUNDO CREME (#FAF7F0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botões Principais: [+ Adicionar] e [📷 Fotografar] lado a lado
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDarkGreen,
                          foregroundColor: AppTheme.cardWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: _openQuickAdd,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text('Adicionar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.cardWhite,
                          foregroundColor: AppTheme.primaryDarkGreen,
                          side: const BorderSide(color: AppTheme.primaryDarkGreen, width: 1.3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: _scanGeneral,
                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                        label: const Text('Fotografar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Botão Principal Secundário de Largura Total: [✓ Finalizar compra]
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.cardWhite,
                      foregroundColor: AppTheme.primaryText,
                      side: const BorderSide(color: AppTheme.subtleBorder, width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _confirmAndShowReceiptScreen,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.primaryDarkGreen,
                      size: 20,
                    ),
                    label: const Text(
                      'Finalizar compra',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Barra de Filtros de Categorias (Todos, Carnes, Laticínios, Limpeza...)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryFilterChip(
                        label: 'Todos',
                        icon: Icons.shopping_basket_outlined,
                        color: AppTheme.primaryDarkGreen,
                        isSelected: _selectedCategoryFilter == 'Todos',
                        onTap: () => setState(() => _selectedCategoryFilter = 'Todos'),
                      ),
                      for (final cat in ProductCategory.all)
                        if (items.any((i) => i.category == cat))
                          _buildCategoryFilterChip(
                            label: cat,
                            icon: ProductCategory.iconFor(cat),
                            color: ProductCategory.colorFor(cat),
                            isSelected: _selectedCategoryFilter == cat,
                            onTap: () => setState(() => _selectedCategoryFilter = cat),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Barra "Selecionar tudo (Select All)"
                if (activeItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.cardDecoration(
                      color: isAllSelected ? AppTheme.lightGreen : AppTheme.cardWhite,
                      borderColor: isAllSelected ? AppTheme.accentGreen : AppTheme.subtleBorder,
                      radius: 14,
                      withShadow: false,
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: isAllSelected,
                      onChanged: (val) => _toggleSelectAll(val ?? false),
                      title: const Text(
                        'Selecionar tudo (Select All)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        isAllSelected
                            ? 'Todos os $totalDistinct itens selecionados!'
                            : 'Marque para selecionar todos os itens de uma vez.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                      secondary: isAllSelected
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: _confirmAndShowReceiptScreen,
                              child: const Text('Confirmar', style: TextStyle(fontSize: 12)),
                            )
                          : null,
                    ),
                  ),

                // Estado Vazio
                if (activeItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: AppTheme.cardDecoration(radius: 18, withShadow: false),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppTheme.lightGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_basket_outlined,
                            size: 40,
                            color: AppTheme.primaryDarkGreen,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sua lista está vazia',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque em "Adicionar" para montar sua lista de supermercado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                        ),
                      ],
                    ),
                  ),

                // Cartões dos Produtos
                for (final item in filteredItems) _buildProductCard(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.subtleBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.cardWhite : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.cardWhite : AppTheme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
        ),
      );
    }

    return Scaffold(
      // Na aba 0 ("Minha Lista"), o cabeçalho faz parte do banner fotográfico de supermercado
      appBar: _currentTabIndex == 0
          ? null
          : AppBar(
              title: Text(
                _currentTabIndex == 1 ? 'Faltam Comprar' : 'Próximo Item',
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
          _buildMainTab(),
          PendingTab(
            items: items,
            onConfirmPurchase: (item) => _toggleItemCheckbox(item, !item.isFullyBought),
            onScanItem: (target) =>
                target != null ? _scanItemPriceAutomatically(target) : _scanGeneral(),
          ),
          NextItemTab(
            items: items,
            onConfirmPurchase: (item) => _toggleItemCheckbox(item, true),
            onScanItem: (target) =>
                target != null ? _scanItemPriceAutomatically(target) : _scanGeneral(),
            onFinishPurchase: _confirmAndShowReceiptScreen,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Minha Lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Faltam Comprar',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Próximo Item',
          ),
        ],
      ),
    );
  }
}
