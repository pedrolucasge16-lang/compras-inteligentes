import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';

/// Tela rápida para montar a lista por seção do supermercado, sem exigir preços.
class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen> {
  final _db = DatabaseService.instance;
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String _category = ProductCategory.carnes;
  String _unit = 'un';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.replaceAll(',', '.'));
    if (name.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o produto e uma quantidade válida.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.saveItem(ShoppingItem(
        name: name,
        quantity: quantity,
        unit: _unit,
        unitPriceCents: 0,
        category: _category,
      ));
      if (!mounted) return;
      _nameController.clear();
      _quantityController.text = '1';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name adicionado em $_category.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar lista de compras')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Adicione os produtos por seção do mercado. Não é necessário informar preços.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do produto',
              hintText: 'Ex.: peito de frango',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shopping_basket_outlined),
            ),
            onSubmitted: (_) => _addItem(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Seção do mercado',
              border: OutlineInputBorder(),
            ),
            items: ProductCategory.all.map((category) => DropdownMenuItem(
              value: category,
              child: Row(
                children: [
                  Icon(ProductCategory.iconFor(category), size: 20),
                  const SizedBox(width: 10),
                  Text(category),
                ],
              ),
            )).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantidade',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unidade',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'un', child: Text('Unidade(s)')),
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'g', child: Text('g')),
                    DropdownMenuItem(value: 'L', child: Text('Litro(s)')),
                    DropdownMenuItem(value: 'ml', child: Text('ml')),
                    DropdownMenuItem(value: 'pct', child: Text('Pacote(s)')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _unit = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _addItem,
            icon: const Icon(Icons.add),
            label: Text(_saving ? 'Adicionando...' : 'Adicionar produto'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Os itens adicionados ficam disponíveis na sua lista principal e podem receber o preço quando você registrar a compra.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
