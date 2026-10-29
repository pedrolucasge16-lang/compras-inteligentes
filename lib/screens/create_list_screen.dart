import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/quantity.dart';
import '../theme/app_theme.dart';

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
            backgroundColor: AppTheme.creamBackground,
            title: const Text('Cadastrar no Banco de Setores'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cadastre produtos neste setor para que o aplicativo sempre os identifique sozinho quando você digitar:',
                    style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCat,
                    decoration: const InputDecoration(
                      labelText: 'Escolha o Setor',
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
                        style: IconButton.styleFrom(backgroundColor: AppTheme.primaryDarkGreen),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
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

  /// Seleciona a categoria ou abre o cadastro no banco de setores
  Future<void> _pickCategoryOverride() async {
    final currentTyped = _nameController.text.trim();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.creamBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      currentTyped.isNotEmpty
                          ? 'Categoria para "$currentTyped"'
                          : 'Categorias e Banco de Produtos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (currentTyped.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Ao escolher uma categoria abaixo, este produto será memorizado no banco para ser identificado sozinho nas próximas vezes!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.lightGreen,
                  foregroundColor: AppTheme.primaryDarkGreen,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openRegisterInBankDialog(_detectedCategory);
                },
                icon: const Icon(Icons.library_add),
                label: const Text(
                  'Cadastrar novos itens no banco de setores',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 22),
              for (final cat in ProductCategory.all)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: ProductCategory.colorFor(cat).withOpacity(0.14),
                    child: Icon(
                      ProductCategory.iconFor(cat),
                      color: ProductCategory.colorFor(cat),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    cat,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  subtitle: (ProductCategory.customKeywords[cat]?.isNotEmpty ?? false)
                      ? Text(
                          'Salvos: ${ProductCategory.customKeywords[cat]!.join(", ")}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
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
              duration: const Duration(seconds: 2),
              content: Text(
                '✅ "$currentTyped" salvo no banco de $chosen!',
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

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Adicionar à Lista'),
        actions: [
          IconButton(
            tooltip: 'Concluir',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, color: AppTheme.primaryDarkGreen, size: 26),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  // Rótulo do Campo
                  const Text(
                    'O que você vai comprar?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Campo Branco de Digitação com Ícone de Lápis Verde
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ex.: Arroz, Feijão, Sabão, Leite...',
                      prefixIcon: const Icon(
                        Icons.edit_outlined,
                        color: AppTheme.accentGreen,
                      ),
                      suffixIcon: _nameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.secondaryText),
                              onPressed: () => _nameController.clear(),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Barra de Seleção de Categoria em Verde-claro Suave (#E7F0E6)
                  InkWell(
                    onTap: _pickCategoryOverride,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.subtleBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.grid_view_rounded,
                            size: 20,
                            color: AppTheme.primaryDarkGreen,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Categoria: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _detectedCategory,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryDarkGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Linha de Quantidade com Botões Redondos [-] 1 un [+]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantidade',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _changeQty(-1),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.subtleBorder.withOpacity(0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.remove,
                                size: 20,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              '${formatQuantity(_quantity)} $_unit',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _changeQty(1),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppTheme.lightGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 20,
                                color: AppTheme.primaryDarkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Botão Principal Verde-escuro (#245C46): [+ Adicionar na Lista]
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
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text(
                        'Adicionar na Lista',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Lista de Itens Já Adicionados Agrupados por Categoria
                  Text(
                    'Itens na sua lista (${active.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (active.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration(radius: 14, withShadow: false),
                      child: const Text(
                        'Digite o nome do produto acima. O setor é identificado automaticamente (ou toque em Categoria para cadastrar novos itens no banco).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                      ),
                    )
                  else ...[
                    for (final cat in ProductCategory.all) ...[
                      if (active.any((i) => i.category == cat)) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                ProductCategory.iconFor(cat),
                                size: 17,
                                color: ProductCategory.colorFor(cat),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ProductCategory.colorFor(cat),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in active.where((i) => i.category == cat))
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                                decoration: BoxDecoration(
                                  color: ProductCategory.colorFor(cat).withOpacity(0.11),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item.name} (${formatQuantity(item.quantity)} ${item.unit})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: item.id == null ? null : () => _deleteItem(item.id!),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: AppTheme.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],

                  const SizedBox(height: 24),

                  // Botão Inferior: [→ Pronto! Ir para a Página Inicial]
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.cardWhite,
                        foregroundColor: AppTheme.primaryText,
                        side: const BorderSide(color: AppTheme.subtleBorder, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_forward, color: AppTheme.primaryDarkGreen),
                      label: const Text(
                        'Pronto! Ir para a Página Inicial',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
