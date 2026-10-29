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
    if (text.trim().isEmpty) {
      _manualCategoryOverride = null;
    }
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
    await db.loadCustomCategories();
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

    // Se o usuário escolheu manualmente um setor para uma palavra nova, salva no banco automaticamente!
    if (_manualCategoryOverride != null && categoryToSave != ProductCategory.outros) {
      await db.saveCustomCategoryItem(categoryToSave, text);
    }

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

  /// Abre janela para cadastrar novos itens no banco de um setor específico
  Future<void> _openRegisterInBankDialog([String? initialCategory]) async {
    String selectedCat = initialCategory != null && initialCategory != ProductCategory.outros
        ? initialCategory
        : ProductCategory.carnes;
    final wordCtrl = TextEditingController(text: _nameController.text.trim());

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final savedWords = ProductCategory.customKeywords[selectedCat] ?? const <String>[];
          final catColor = ProductCategory.colorFor(selectedCat);

          return AlertDialog(
            title: const Text('Cadastrar no Banco de Setores'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cadastre produtos neste setor para que o aplicativo sempre os identifique sozinho quando você digitar:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCat,
                    decoration: const InputDecoration(
                      labelText: 'Escolha o Setor',
                      border: OutlineInputBorder(),
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
                      if (v != null) setD(() => selectedCat = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wordCtrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Nome do item p/ $selectedCat',
                            hintText: 'Ex: Rabada, Veja Gold...',
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) async {
                            final w = wordCtrl.text.trim();
                            if (w.isEmpty) return;
                            await db.saveCustomCategoryItem(selectedCat, w);
                            wordCtrl.clear();
                            setD(() {});
                            _onNameChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: catColor),
                        tooltip: 'Salvar no banco',
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final w = wordCtrl.text.trim();
                          if (w.isEmpty) return;
                          await db.saveCustomCategoryItem(selectedCat, w);
                          wordCtrl.clear();
                          setD(() {});
                          _onNameChanged();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade800,
                                content: Text('✅ "$w" salvo no banco de $selectedCat!'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (savedWords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Itens que você já cadastrou em $selectedCat:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final word in savedWords)
                          Chip(
                            label: Text(word),
                            backgroundColor: catColor.withOpacity(0.12),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () async {
                              await db.removeCustomCategoryItem(selectedCat, word);
                              setD(() {});
                              _onNameChanged();
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Concluir'),
              ),
            ],
          );
        },
      ),
    );
    _onNameChanged();
  }

  /// Ao tocar no quadrado "Setor: ...", permite escolher o setor (já memorizando no banco!)
  /// ou abrir o cadastro de novos itens no banco de setores.
  Future<void> _pickCategoryOverride() async {
    final currentTyped = _nameController.text.trim();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      currentTyped.isNotEmpty
                          ? 'Qual o setor de "$currentTyped"?'
                          : 'Setores e Banco de Produtos',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (currentTyped.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Ao escolher um setor abaixo, "$currentTyped" será salvo no banco para ser identificado automaticamente nas próximas vezes!',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                  ),
                ),

              // Botão em destaque para cadastrar vários itens no banco de qualquer setor
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openRegisterInBankDialog(_detectedCategory);
                },
                icon: const Icon(Icons.library_add),
                label: const Text(
                  'Cadastrar novos itens no banco de setores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 20),

              for (final cat in ProductCategory.all)
                ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: ProductCategory.colorFor(cat).withOpacity(0.15),
                    child: Icon(
                      ProductCategory.iconFor(cat),
                      color: ProductCategory.colorFor(cat),
                      size: 18,
                    ),
                  ),
                  title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: (ProductCategory.customKeywords[cat]?.isNotEmpty ?? false)
                      ? Text(
                          'Seus itens salvos: ${ProductCategory.customKeywords[cat]!.join(", ")}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  trailing: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openRegisterInBankDialog(cat);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Cadastrar', style: TextStyle(fontSize: 12)),
                  ),
                  onTap: () => Navigator.pop(ctx, cat),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      if (currentTyped.isNotEmpty && chosen != ProductCategory.outros) {
        await db.saveCustomCategoryItem(chosen, currentTyped);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 2),
              content: Text(
                '✅ "$currentTyped" salvo no banco de $chosen! Será identificado sozinho sempre.',
              ),
            ),
          );
        }
      }
      setState(() {
        _manualCategoryOverride = chosen;
        _detectedCategory = chosen;
        _unit = ProductCategory.suggestUnit(currentTyped, chosen);
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
            icon: const Icon(Icons.check),
            label: const Text(
              'Concluir',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Painel de Adição Rápida
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

                        // Quadrado do Setor (com toque para escolher ou cadastrar novos itens no banco!) + Quantidade
                        Row(
                          children: [
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Setor: $_detectedCategory',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: catColor,
                                              ),
                                            ),
                                            Text(
                                              'Toque p/ mudar ou cadastrar no banco',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: catColor.withOpacity(0.85),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.add_circle_outline, size: 18, color: catColor),
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
                              'Digite o nome do produto acima.\nSe algum item não estiver no banco, basta tocar em "Setor" para cadastrá-lo uma única vez!',
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
