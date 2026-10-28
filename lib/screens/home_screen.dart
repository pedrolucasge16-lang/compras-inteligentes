import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/money.dart';
import '../services/ocr_service.dart';
import '../services/quantity.dart';
import 'history_screen.dart';
import 'comparator_screen.dart';

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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await db.getItems();
    final b = await db.getBudget();
    if (!mounted) return;
    setState(() { items = data; budget = b; loading = false; });
  }

  List<ShoppingItem> get activeItems => items.where((i) => i.replacedBy == null).toList();
  int get total => activeItems.fold(0, (sum, item) => sum + item.subtotalCents);
  int get boughtTotal => activeItems.where((i) => i.isBought).fold(0, (sum, item) => sum + item.subtotalCents);

  Future<void> _editItem([ShoppingItem? old, OcrSuggestion? suggestion]) async {
    final name = TextEditingController(text: suggestion?.productName ?? old?.name ?? '');
    final qty = TextEditingController(text: formatQuantity(old?.quantity ?? 1));
    final price = TextEditingController(text: centsToInput(suggestion?.priceCents ?? old?.unitPriceCents ?? 0));
    String unit = old?.unit ?? 'un';
    final result = await showDialog<ShoppingItem>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text(old == null ? 'Adicionar produto' : 'Editar produto'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (suggestion != null) ...[
          if (suggestion.priceCents == null)
            const Text('Nenhum preço encontrado na foto. Digite o preço manualmente.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))
          else if (suggestion.ambiguous)
            const Text('Encontrei mais de um preço. Toque no correto:',
              style: TextStyle(fontWeight: FontWeight.w600))
          else
            const Text('Confira o nome e o preço lidos antes de salvar.'),
          if (suggestion.candidates.length > 1) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final c in suggestion.candidates)
                ActionChip(label: Text(formatCents(c)), onPressed: () => setD(() => price.text = centsToInput(c))),
            ]),
          ],
          const SizedBox(height: 6),
          Text('Texto lido: ${suggestion.text.replaceAll('\n', ' | ')}',
            maxLines: 4, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
        ],
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do produto')),
        const SizedBox(height: 10),
        TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantidade')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'Unidade'), items: const [
          DropdownMenuItem(value: 'un', child: Text('Unidade')), DropdownMenuItem(value: 'kg', child: Text('kg')),
          DropdownMenuItem(value: 'g', child: Text('g')), DropdownMenuItem(value: 'L', child: Text('Litro')),
          DropdownMenuItem(value: 'ml', child: Text('ml')),
        ], onChanged: (v) { if (v != null) setD(() => unit = v); }),
        const SizedBox(height: 10),
        TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço unitário (R\$)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () {
          final q = double.tryParse(qty.text.replaceAll(',', '.'));
          if (name.text.trim().isEmpty || q == null || q <= 0) return;
          Navigator.pop(ctx, ShoppingItem(id: old?.id, name: name.text.trim(), quantity: q, unit: unit,
            unitPriceCents: parseMoneyToCents(price.text), isBought: old?.isBought ?? false,
            replacedBy: old?.replacedBy, originalItemId: old?.originalItemId,
            actualUnitPriceCents: old?.actualUnitPriceCents));
        }, child: const Text('Salvar')),
      ],
    )));
    if (result != null) { await db.saveItem(result); await _load(); }
  }

  Future<void> _changeQuantity(ShoppingItem item, int direction) async {
    if (item.replacedBy != null) return; // produto substituído não muda
    final next = nextQuantity(item.quantity, item.unit, direction);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A quantidade precisa ser maior que zero.')));
      return;
    }
    await db.saveItem(item.copyWith(quantity: next));
    await _load();
  }

  Future<void> _toggleBought(ShoppingItem item, bool bought) async {
    if (!bought) {
      await db.saveItem(item.copyWith(isBought: false, clearActualPrice: true));
      await _load();
      return;
    }
    final controller = TextEditingController(text: centsToInput(item.actualUnitPriceCents ?? item.unitPriceCents));
    final actualPrice = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirmar preço pago'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name),
        const SizedBox(height: 8),
        Text('Preço estimado: ${formatCents(item.unitPriceCents)} por ${item.unit}'),
        const SizedBox(height: 12),
        TextField(controller: controller, autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Preço real por unidade (R\$)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, parseMoneyToCents(controller.text)), child: const Text('Confirmar compra')),
      ],
    ));
    if (actualPrice == null) return;
    await db.saveItem(item.copyWith(isBought: true, actualUnitPriceCents: actualPrice));
    await _load();
  }

  Future<void> _replace(ShoppingItem item) async {
    final name = TextEditingController();
    final price = TextEditingController();
    final result = await showDialog<(String, int)>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Trocar ${item.name}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do substituto')),
        const SizedBox(height: 10),
        TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço unitário (R\$)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () { if (name.text.trim().isNotEmpty) Navigator.pop(ctx, (name.text.trim(), parseMoneyToCents(price.text))); }, child: const Text('Substituir')),
      ],
    ));
    if (result == null) return;
    await db.saveItem(item.copyWith(replacedBy: result.$1));
    await db.saveItem(ShoppingItem(name: result.$1, quantity: item.quantity, unit: item.unit,
      unitPriceCents: result.$2, originalItemId: item.id, originalItemName: item.name));
    await _load();
  }

  Future<void> _budgetDialog() async {
    final controller = TextEditingController(text: centsToInput(budget));
    final value = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Definir orçamento'),
      content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Orçamento total (R\$)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, parseMoneyToCents(controller.text)), child: const Text('Salvar')),
      ],
    ));
    if (value != null) { await db.setBudget(value); await _load(); }
  }

  Future<void> _scan() async {
    XFile? image;
    try {
      image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('denied');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(denied
          ? 'Sem permissão da câmera. Ative em Configurações > Apps > Compras Inteligentes > Permissões.'
          : 'Não foi possível abrir a câmera: ${e.message ?? e.code}')));
      return;
    }
    if (image == null) return; // usuário cancelou a câmera
    try {
      final suggestion = await OcrService.readImage(image.path);
      if (!mounted) return;
      if (suggestion.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível ler o texto. Tente outra foto ou digite manualmente.')));
        await _editItem();
      } else {
        await _editItem(null, suggestion);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na leitura: $e')));
    }
  }

  Future<void> _finish() async {
    final boughtCount = activeItems.where((i) => i.isBought).length;
    if (boughtCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marque pelo menos um produto como comprado.')));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Salvar compra?'),
      content: const Text('Os produtos marcados como comprados serão salvos no histórico. Os itens pendentes continuarão na lista.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar'))],
    ));
    if (ok != true) return;
    try { await db.finishPurchase(); await _load(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra salva no histórico.'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final over = budget > 0 && total > budget;
    return Scaffold(
      appBar: AppBar(title: const Text('Compras Inteligentes'), actions: [
        IconButton(tooltip: 'Comparador', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComparatorScreen())), icon: const Icon(Icons.compare_arrows)),
        IconButton(tooltip: 'Histórico', onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())); await _load(); }, icon: const Icon(Icons.history)),
      ]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total da lista', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Text(formatCents(total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: Text('Orçamento: ${budget == 0 ? 'não definido' : formatCents(budget)}')),
            TextButton(onPressed: _budgetDialog, child: const Text('Definir'))]),
          if (budget > 0) Text(over ? 'Orçamento ultrapassado em ${formatCents(total - budget)}' : 'Saldo disponível: ${formatCents(budget - total)}',
            style: TextStyle(color: over ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Comprado: ${formatCents(boughtTotal)}  •  Pendente: ${formatCents(total - boughtTotal)}'),
          Text('${activeItems.where((i) => i.isBought).length} comprados • ${activeItems.where((i) => !i.isBought).length} pendentes'),
        ]))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: () => _editItem(), icon: const Icon(Icons.add), label: const Text('Adicionar')),
          OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.camera_alt), label: const Text('Fotografar')),
          OutlinedButton.icon(onPressed: _finish, icon: const Icon(Icons.check_circle), label: const Text('Finalizar compra')),
        ]),
        const SizedBox(height: 12),
        if (activeItems.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Column(children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8), Text('Sua lista está vazia. Adicione seu primeiro produto.'),
        ])),
        ...items.map((item) {
          final replaced = item.replacedBy != null;
          return Card(
            child: ListTile(
              leading: replaced ? const Icon(Icons.swap_horiz, color: Colors.orange) : Checkbox(value: item.isBought, onChanged: (v) => _toggleBought(item, v ?? false)),
              isThreeLine: !replaced,
              title: Text(item.name, style: TextStyle(decoration: replaced ? TextDecoration.lineThrough : null, color: replaced ? Colors.grey : null)),
              subtitle: replaced
                  ? Text('Substituído por ${item.replacedBy}')
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Preço unitário: ${formatCents(item.actualUnitPriceCents ?? item.unitPriceCents)}${item.isBought ? ' (confirmado)' : ' (estimado)'}'),
                      Text('Subtotal: ${formatCents(item.subtotalCents)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                        IconButton.filledTonal(
                          tooltip: 'Diminuir quantidade',
                          iconSize: 26,
                          onPressed: nextQuantity(item.quantity, item.unit, -1) == null ? null : () => _changeQuantity(item, -1),
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('${formatQuantity(item.quantity)} ${item.unit}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Aumentar quantidade',
                          iconSize: 26,
                          onPressed: () => _changeQuantity(item, 1),
                          icon: const Icon(Icons.add),
                        ),
                      ]),
                    ]),
              trailing: replaced ? null : PopupMenuButton<String>(onSelected: (v) async {
                if (v == 'edit') await _editItem(item);
                if (v == 'replace') await _replace(item);
                if (v == 'delete') {
                  final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Excluir produto?'), content: Text('Deseja excluir ${item.name}?'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir'))],
                  ));
                  if (yes == true && item.id != null) { await db.deleteItem(item.id!); await _load(); }
                }
              }, itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'replace', child: Text('Trocar produto')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ]),
            ),
          );
        }),
      ])),
    );
  }
}
