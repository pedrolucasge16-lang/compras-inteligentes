import 'package:flutter/material.dart';

import '../data/banco_local.dart';
import '../domain/dinheiro.dart';
import '../domain/item_compra.dart';

const _laranja = Color(0xFFFF6D00);

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final _banco = BancoLocal.instancia;
  List<ItemCompra> _itens = [];
  int _orcamento = 0;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  int get _total => _itens.fold<int>(0, (soma, i) => soma + i.totalCentavos);
  int get _saldo => _orcamento - _total;

  Future<void> _carregar() async {
    final itens = await _banco.listarItens();
    final orcamento = await _banco.lerOrcamento();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _orcamento = orcamento;
      _carregando = false;
    });
  }

  void _mostrarDesfazer(String mensagem, Future<void> Function() desfazer) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        content: Text(mensagem),
        action: SnackBarAction(label: 'Desfazer', onPressed: desfazer),
      ),
    );
  }

  Future<void> _definirOrcamento() async {
    final controle = TextEditingController(
      text: _orcamento > 0 ? centavosParaTexto(_orcamento) : '',
    );
    final valor = await showDialog<int>(
      context: context,
      builder: (ctx) {
        String? erro;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Orçamento'),
            content: TextField(
              controller: controle,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor (ex.: 300,00)',
                prefixText: 'R\$ ',
                errorText: erro,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final v = lerReais(controle.text);
                  if (v == null) {
                    setLocal(() => erro = 'Valor inválido');
                    return;
                  }
                  Navigator.pop(ctx, v);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );
    if (valor == null) return;
    await _banco.salvarOrcamento(valor);
    await _carregar();
  }

  Future<ItemCompra?> _pedirItem({ItemCompra? atual}) {
    final nome = TextEditingController(text: atual?.nome ?? '');
    final preco = TextEditingController(
      text: atual == null ? '' : centavosParaTexto(atual.precoCentavos),
    );
    final qtd = TextEditingController(text: (atual?.quantidade ?? 1).toString());
    return showDialog<ItemCompra>(
      context: context,
      builder: (ctx) {
        String? erro;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(atual == null ? 'Adicionar produto' : 'Editar produto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nome,
                    autofocus: atual == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Produto'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: preco,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preço unitário',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtd,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                  if (erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        erro!,
                        style: TextStyle(color: Theme.of(ctx).colorScheme.error),
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
                  final n = nome.text.trim();
                  final pr = lerReais(preco.text);
                  final q = int.tryParse(qtd.text.trim());
                  if (n.isEmpty) {
                    setLocal(() => erro = 'Informe o nome do produto.');
                    return;
                  }
                  if (pr == null || pr <= 0) {
                    setLocal(() => erro = 'Informe um preço válido, como 12,99.');
                    return;
                  }
                  if (q == null || q < 1 || q > 999) {
                    setLocal(() => erro = 'A quantidade deve ser de 1 a 999.');
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    ItemCompra(
                      id: atual?.id,
                      nome: n,
                      precoCentavos: pr,
                      quantidade: q,
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _adicionar() async {
    final novo = await _pedirItem();
    if (novo == null) return;
    final id = await _banco.inserirItem(novo);
    await _carregar();
    _mostrarDesfazer('Produto adicionado.', () async {
      await _banco.removerItem(id);
      await _carregar();
    });
  }

  Future<void> _editar(ItemCompra item) async {
    final editado = await _pedirItem(atual: item);
    if (editado == null) return;
    await _banco.atualizarItem(editado);
    await _carregar();
  }

  Future<void> _mudarQuantidade(ItemCompra item, int delta) async {
    final nova = item.quantidade + delta;
    if (nova < 1 || nova > 999) return;
    await _banco.atualizarItem(item.copyWith(quantidade: nova));
    await _carregar();
  }

  Future<void> _remover(ItemCompra item) async {
    await _banco.removerItem(item.id!);
    await _carregar();
    _mostrarDesfazer('Produto removido.', () async {
      await _banco.inserirItem(item);
      await _carregar();
    });
  }

  Widget _bloco(String rotulo, String valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cor),
          ),
        ],
      ),
    );
  }

  Widget _resumo() {
    final temOrcamento = _orcamento > 0;
    final percentual = temOrcamento ? _total * 100 / _orcamento : 0.0;
    final estourou = temOrcamento && _total > _orcamento;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total acumulado'),
          Text(
            formatarReais(_total),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: _laranja,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _bloco('Orçamento', temOrcamento ? formatarReais(_orcamento) : '—')),
              Expanded(
                child: _bloco(
                  'Saldo',
                  temOrcamento ? formatarReais(_saldo) : '—',
                  cor: estourou ? Colors.red.shade700 : null,
                ),
              ),
              Expanded(child: _bloco('Usado', temOrcamento ? '${percentual.round()}%' : '—')),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (percentual / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: estourou ? Colors.red : _laranja,
            backgroundColor: Colors.white,
          ),
          if (estourou)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Atenção: você passou do orçamento em ${formatarReais(-_saldo)}.',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton.icon(
            onPressed: _definirOrcamento,
            icon: const Icon(Icons.edit, size: 18),
            label: Text(temOrcamento ? 'Alterar orçamento' : 'Definir orçamento'),
          ),
        ],
      ),
    );
  }

  Widget _linha(ItemCompra item) {
    return ListTile(
      onTap: () => _editar(item),
      title: Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatarReais(item.precoCentavos)} × ${item.quantidade} = ${formatarReais(item.totalCentavos)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: item.quantidade > 1 ? () => _mudarQuantidade(item, -1) : null,
          ),
          Text('${item.quantidade}'),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _mudarQuantidade(item, 1),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _remover(item),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras Inteligentes'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          _resumo(),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _itens.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum produto ainda.\nToque em "Adicionar manualmente".',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _itens.length,
                        itemBuilder: (ctx, i) => _linha(_itens[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionar,
        backgroundColor: _laranja,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar manualmente'),
      ),
    );
  }
}
