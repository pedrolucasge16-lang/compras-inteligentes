import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/quantity.dart';

class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen> {
  final db = DatabaseService.instance;
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  List<ShoppingItem> items = [];
  bool loading = true;

  String _detectedCategory = ProductCategory.outros;
  String? _manualCategoryOverride;
  double _quantity = 1.0;
  String _unit = 'un';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _load();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final text = _nameController.text;
    final autoCat = ProductCategory.detectCategory(text);
    final effectiveCat = _manualCategoryOverride ?? autoCat;
    final autoUnit = ProductCategory.suggestUnit(text, effectiveCat);
    if (mounted) {
      setState(() {
        _detectedCategory = effectiveCat;
        if (_manualCategoryOverride == null) {
          _unit = autoUnit;
        }
      });
    }
  }

  Future<void> _load() async {
    final data = await db.getItems();
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _addItem() async {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    final categoryToSave = _manualCategoryOverride ?? ProductCategory.detectCategory(text);

    final newItem = ShoppingItem(
      name: text,
      quantity: _quantity > 0 ? _quantity : 1.0,
      unit: _unit,
      unitPriceCents: 0,
      category: categoryToSave,
    );

    await db.saveItem(newItem);
    _nameController.clear();
    setState(() {
      _manualCategoryOverride = null;
      _detectedCategory = ProductCategory.outros;
      _quantity = 1.0;
      _unit = 'un';
    });
    await _load();
    _nameFocus.requestFocus();
  }

  Future<void> _deleteItem(int id) async {
    await db.deleteItem(id);
    await _load();
  }

  void _changeQty(int dir) {
    final step = quantityStep(_unit);
    final next = ((_quantity + dir * step) * 1000).round() / 1000;
    if (next > 0) {
      setState(() => _quantity = next);
    }
  }

  Future<void> _pickCategoryOverride() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mudar setor manualmente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            for (final cat in ProductCategory.all)
              ListTile(
                leading: Icon(ProductCategory.iconFor(cat), color: ProductCategory.colorFor(cat)),
                title: Text(cat),
                onTap: () => Navigator.pop(ctx, cat),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      setState(() {
        _manualCategoryOverride = chosen;
        _detectedCategory = chosen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = items.where((i) => i.replacedBy == null && !i.isFullyBought).toList();
    final catColor = ProductCategory.colorFor(_detectedCategory);
    final catIcon = ProductCategory.iconFor(_detectedCategory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar à Lista'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'Concluir',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Painel de Adição Rápida (1 campo só, categoria automática!)
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addItem(),
                          decoration: InputDecoration(
                            labelText: 'O que você vai comprar?',
                            hintText: 'Ex: Frango, Sabão, Leite, Arroz...',
                            prefixIcon: const Icon(Icons.edit),
                            suffixIcon: _nameController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _nameController.clear(),
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Linha que mostra a categoria detectada automaticamente + quantidade
                        Row(
                          children: [
                            // Badge do setor identificado sozinho
                            Expanded(
                              child: InkWell(
                                onTap: _pickCategoryOverride,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: catColor.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(catIcon, size: 18, color: catColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Setor: $_detectedCategory',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: catColor,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.edit_outlined, size: 14, color: catColor),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Botões simples de quantidade (-) 1 (+)
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _changeQty(-1),
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${formatQuantity(_quantity)} $_unit',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _changeQty(1),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Botão Grande Adicionar
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text(
                              'Adicionar na Lista',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista dos itens já anotados (organizados automaticamente por setor)
                Expanded(
                  child: active.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Digite o nome do produto acima (ex: "Frango" ou "Sabão").\nO aplicativo coloca no setor certo automaticamente!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Itens na sua lista (${active.length}):',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                            ),
                            for (final cat in ProductCategory.all) ...[
                              if (active.any((i) => i.category == cat)) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        ProductCategory.iconFor(cat),
                                        size: 16,
                                        color: ProductCategory.colorFor(cat),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ProductCategory.colorFor(cat),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (final item in active.where((i) => i.category == cat))
                                      Chip(
                                        backgroundColor: ProductCategory.colorFor(cat).withOpacity(0.1),
                                        label: Text(
                                          '${item.name} (${formatQuantity(item.quantity)} ${item.unit})',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                        onDeleted: item.id == null ? null : () => _deleteItem(item.id!),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                ),

                // Botão Inferior para voltar para a Tela Inicial
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text(
                          'Pronto! Ir para a Página Inicial',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
