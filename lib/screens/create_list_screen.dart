import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';

/// Permite preparar uma lista por seção do mercado sem exigir preço antecipado.
/// O preço real poderá ser informado quando o produto for comprado.
class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen> {
  final _nameController = TextEditingController();
  final List<ShoppingItem> _draftItems = [];
  String _category = ProductCategory.carnes;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome do produto.')),
      );
      return;
    }
    setState(() {
      _draftItems.add(ShoppingItem(
        name: name,
        quantity: 1,
        unit: 'un',
        unitPriceCents: 0,
        category: _category,
      ));
      _nameController.clear();
    });
  }

  Future<void> _saveList() async {
    if (_draftItems.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final db = DatabaseService.instance;
      for (final item in _draftItems) {
        await db.saveItem(item);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_draftItems.length} produto(s) adicionados à lista.')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a lista. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in _draftItems) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar lista por seção')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                    decoration: const InputDecoration(
                      labelText: 'Nome do produto',
                      hintText: 'Ex.: peito de frango',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Seção do mercado',
                      border: OutlineInputBorder(),
                    ),
                    items: ProductCategory.all
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar produto'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Não precisa informar o preço agora. Você poderá registrar o valor na hora da compra.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _draftItems.isEmpty
                  ? const Center(child: Text('Adicione produtos para montar sua lista.'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final category in ProductCategory.all)
                          if (grouped.containsKey(category)) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(
                                category,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            for (final item in grouped[category]!)
                              Card(
                                child: ListTile(
                                  leading: Icon(ProductCategory.iconFor(category)),
                                  title: Text(item.name),
                                  subtitle: const Text('Quantidade: 1 • Preço a informar na compra'),
                                  trailing: IconButton(
                                    tooltip: 'Remover produto',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(() => _draftItems.remove(item)),
                                  ),
                                ),
                              ),
                          ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _draftItems.isEmpty || _saving ? null : _saveList,
                  child: Text(_saving ? 'Salvando...' : 'Salvar lista (${_draftItems.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
