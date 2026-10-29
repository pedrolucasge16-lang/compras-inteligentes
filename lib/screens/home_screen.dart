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
import 'create_list_screen.dart';
import 'history_screen.dart';
import 'comparator_screen.dart';
import 'tabs/next_item_tab.dart';

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

  /// Marca ou desmarca um item individualmente direto no quadradinho (sem janelas extras)
  Future<void> _toggleItemCheckbox(ShoppingItem item, bool checked) async {
    final updated = item.copyWith(
      isBought: checked,
      boughtQuantity: checked ? item.quantity : 0.0,
    );
    await db.saveItem(updated);
    await _load();
  }

  /// Abre a tela rápida de adicionar itens (com categoria automática)
  Future<void> _openQuickAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateListScreen()),
    );
    await _load();
  }

  /// Diálogo de adicionar ou editar produto (com detecção automática de categoria ao digitar)
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
          title: Text(old == null ? 'Adicionar produto' : 'Editar produto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    labelText: 'Categoria (identificada automaticamente)',
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
                    labelText: 'Preço unitário (R\$) - Opcional',
                    hintText: 'Deixe vazio para tirar foto no mercado',
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
    await db.saveItem(item.copyWith(
      quantity: next,
      boughtQuantity: item.isBought ? next : item.boughtQuantity,
    ));
    await _load();
  }

  /// ÍCONE DE CÂMERA DENTRO DO QUADRADO DO ITEM (circulado em verde):
  /// Tira a foto do preço na prateleira e coloca o preço AUTOMATICAMENTE naquele item!
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
        // Preenche o preço automaticamente no quadrado do item sem pedir confirmação!
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
            backgroundColor: Colors.green.shade800,
            content: Text(
              '✅ Preço ${formatCents(detectedPrice)} registrado automaticamente em "${item.name}"!',
            ),
          ),
        );
      } else {
        // Caso não haja número legível na foto, avisa e permite digitar rápido
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não encontrei o número do preço na foto. Tente aproximar da etiqueta ou digite abaixo.'),
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

  /// Botão de câmera de cima (geral): lê produto e preço ou adiciona novo
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

      // Verifica se bate com algum item da lista para já preencher o preço nele
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
            backgroundColor: Colors.green.shade800,
            content: Text(
              '✅ "${matched.name}" atualizado com o preço ${formatCents(suggestion.priceCents!)}!',
            ),
          ),
        );
        return;
      }

      // Caso contrário, abre para adicionar com os dados lidos
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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

  /// CONFIRMAR COMPRA:
  /// Salva os itens selecionados e exibe uma TELA DE COMPROVANTE mostrando
  /// QUANTO VOCÊ GASTOU e O DIA EM QUE VOCÊ ESTÁ!
  Future<void> _confirmAndShowReceiptScreen() async {
    final selectedItems = activeItems.where((i) => i.isFullyBought || i.isPartiallyBought).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione os produtos (ou marque "Selecionar tudo") antes de confirmar a compra.'),
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

      // Abre a tela de resumo mostrando quanto gastou e o dia atual
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Resumo da Compra'),
              automaticallyImplyLeading: false,
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, size: 72, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Compra Confirmada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 20),

                // Card principal com QUANTO GASTOU e O DIA EM QUE ESTÁ
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL QUE VOCÊ GASTOU',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatCents(totalSpentCents),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const Divider(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dia: $dateFormatted',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  dayOfWeek.toUpperCase(),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Itens comprados (${itemsSnapshot.length}):',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final it in itemsSnapshot)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        ProductCategory.iconFor(it.category),
                        color: ProductCategory.colorFor(it.category),
                      ),
                      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${formatQuantity(it.quantity)} ${it.unit} • ${it.category}'),
                      trailing: Text(
                        formatCents(it.subtotalCents),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Concluir e Voltar ao Início',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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

  /// Constrói a Aba Principal ("Minha Lista") unificando também todas as informações
  /// que antes ficavam na aba "Faltam Comprar" (conforme circulado em azul e verde)
  Widget _buildMainTab() {
    final over = budget > 0 && total > budget;
    final totalDistinct = activeItems.length;
    final boughtDistinct = activeItems.where((i) => i.isFullyBought).length;
    final remainingDistinct = totalDistinct - boughtDistinct;
    final progressRatio = totalDistinct == 0 ? 0.0 : (boughtDistinct / totalDistinct);
    final progressPercentage = (progressRatio * 100).round();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Card de Total da Lista e Orçamento
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total da lista', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    formatCents(total),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Orçamento: ${budget == 0 ? 'não definido' : formatCents(budget)}',
                        ),
                      ),
                      TextButton(onPressed: _budgetDialog, child: const Text('Definir')),
                    ],
                  ),
                  if (budget > 0)
                    Text(
                      over
                          ? 'Orçamento ultrapassado em ${formatCents(total - budget)}'
                          : 'Saldo disponível: ${formatCents(budget - total)}',
                      style: TextStyle(
                        color: over ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Comprado: ${formatCents(boughtTotal)} • Pendente: ${formatCents(total - boughtTotal)}',
                  ),
                  const Divider(height: 22),

                  // INFORMAÇÕES TRAZIDAS DA ABA "FALTAM COMPRAR" DIRETO PARA A ABA PRINCIPAL (Circulado em Azul)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progresso da compra',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalDistinct == 0 ? 0 : progressRatio,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Barra de Botões no Topo (Mantendo o botão Fotografar lá em cima + Adicionar + Confirmar compra)
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
                onPressed: _scanGeneral,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Fotografar'),
              ),
              FilledButton.tonalIcon(
                onPressed: _confirmAndShowReceiptScreen,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmar compra'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Quadrado "Selecionar tudo" (Select All)
          if (activeItems.isNotEmpty)
            Card(
              color: isAllSelected ? Colors.green.shade50 : Colors.orange.shade50,
              margin: const EdgeInsets.only(bottom: 12),
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: isAllSelected,
                onChanged: (val) => _toggleSelectAll(val ?? false),
                title: const Text(
                  'Selecionar tudo (Select All)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isAllSelected
                      ? 'Todos os $totalDistinct itens selecionados! Toque em "Confirmar compra".'
                      : 'Marque para selecionar todos os itens da lista de uma vez.',
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: isAllSelected
                    ? FilledButton(
                        onPressed: _confirmAndShowReceiptScreen,
                        child: const Text('Confirmar'),
                      )
                    : null,
              ),
            ),

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

          // 4. Lista de Itens Organizados por Categoria com o Ícone de Câmera dentro do quadrado de cada item!
          for (final cat in ProductCategory.all) ...[
            if (items.any((i) => i.category == cat)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
                child: Row(
                  children: [
                    Icon(
                      ProductCategory.iconFor(cat),
                      size: 20,
                      color: ProductCategory.colorFor(cat),
                    ),
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
                      '${activeItems.where((i) => i.category == cat && !i.isFullyBought).length} pendente(s)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              for (final item in items.where((i) => i.category == cat))
                Builder(builder: (context) {
                  final replaced = item.replacedBy != null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: replaced
                            ? const Icon(Icons.swap_horiz, color: Colors.orange)
                            : Checkbox(
                                value: item.isFullyBought,
                                onChanged: (v) => _toggleItemCheckbox(item, v ?? false),
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (!replaced)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.isFullyBought
                                      ? Colors.green.shade100
                                      : ProductCategory.colorFor(item.category).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isFullyBought ? 'Selecionado' : item.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.isFullyBought
                                        ? Colors.green.shade900
                                        : ProductCategory.colorFor(item.category),
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
                                  const SizedBox(height: 4),
                                  Text(
                                    'Desejada: ${formatQuantity(item.quantity)} ${item.unit} • ${item.isFullyBought ? "Concluído" : "Falta: ${formatQuantity(item.remainingQuantity)} ${item.unit}"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.isFullyBought ? Colors.green.shade700 : Colors.deepOrange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Preço unitário: ${formatCents(item.actualUnitPriceCents ?? item.unitPriceCents)}${item.actualUnitPriceCents != null ? ' (lido/confirmado)' : ' (estimado)'}',
                                  ),
                                  Text(
                                    'Subtotal: ${formatCents(item.subtotalCents)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  // LINHA DE BOTÕES DENTRO DO QUADRADO DO ITEM: [-] 1 un [+] e [📷 CÂMERA] (Circulado em Verde!)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      IconButton.filledTonal(
                                        tooltip: 'Diminuir quantidade',
                                        iconSize: 22,
                                        onPressed: nextQuantity(item.quantity, item.unit, -1) == null
                                            ? null
                                            : () => _changeQuantity(item, -1),
                                        icon: const Icon(Icons.remove),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '${formatQuantity(item.quantity)} ${item.unit}',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton.filledTonal(
                                        tooltip: 'Aumentar quantidade',
                                        iconSize: 22,
                                        onPressed: () => _changeQuantity(item, 1),
                                        icon: const Icon(Icons.add),
                                      ),
                                      const SizedBox(width: 4),
                                      // NOVO ÍCONE DE CÂMERA DENTRO DO QUADRADO DO ITEM (Circulado em Verde pelo usuário)
                                      FilledButton.tonalIcon(
                                        onPressed: () => _scanItemPriceAutomatically(item),
                                        icon: const Icon(Icons.camera_alt, size: 20),
                                        label: const Text('Preço'),
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
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
                    ),
                  );
                }),
            ],
          ],
          const SizedBox(height: 70),
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
          _currentTabIndex == 0 ? 'Compras Inteligentes' : 'Próximo Item',
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
          NextItemTab(
            items: items,
            onConfirmPurchase: (item) => _toggleItemCheckbox(item, true),
            onScanItem: (target) => target != null ? _scanItemPriceAutomatically(target) : _scanGeneral(),
            onFinishPurchase: _confirmAndShowReceiptScreen,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar produtos rapidamente',
        onPressed: _openQuickAdd,
        child: const Icon(Icons.add),
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
            icon: Icon(Icons.assistant_navigation),
            label: 'Próximo Item',
          ),
        ],
      ),
    );
  }
}
