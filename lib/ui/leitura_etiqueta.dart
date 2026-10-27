import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/dinheiro.dart';
import '../domain/item_compra.dart';
import '../ocr/leitor_etiqueta.dart';

/// Abre a câmera, lê a etiqueta e pede confirmação. Retorna o item
/// confirmado ou null se o usuário cancelar.
Future<ItemCompra?> lerEtiquetaDaCamera(
  BuildContext context,
  List<ItemCompra> existentes,
) async {
  final mensagens = ScaffoldMessenger.of(context);

  XFile? foto;
  try {
    foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
  } catch (_) {
    mensagens.showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a câmera. Verifique a permissão do app.'),
      ),
    );
    return null;
  }
  if (foto == null) return null;
  if (!context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  final leitor = LeitorEtiqueta();
  ResultadoLeitura resultado;
  var falhou = false;
  try {
    resultado = await leitor.ler(foto.path);
  } catch (_) {
    falhou = true;
    resultado = const ResultadoLeitura(precos: [], textos: [], houveTexto: false);
  } finally {
    await leitor.fechar();
  }
  if (!context.mounted) return null;
  Navigator.of(context).pop();

  final item = await showDialog<ItemCompra>(
    context: context,
    builder: (_) => _ConfirmarLeitura(resultado: resultado, falhou: falhou),
  );
  if (item == null || !context.mounted) return null;

  final repetido = existentes.any(
    (e) =>
        e.nome.toLowerCase() == item.nome.toLowerCase() &&
        e.precoCentavos == item.precoCentavos,
  );
  if (repetido) {
    final seguir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produto já está na lista'),
        content: Text(
          'Já existe "${item.nome}" por ${formatarReais(item.precoCentavos)}. Adicionar de novo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adicionar mesmo assim'),
          ),
        ],
      ),
    );
    if (seguir != true) return null;
  }
  return item;
}

class _ConfirmarLeitura extends StatefulWidget {
  final ResultadoLeitura resultado;
  final bool falhou;

  const _ConfirmarLeitura({required this.resultado, required this.falhou});

  @override
  State<_ConfirmarLeitura> createState() => _ConfirmarLeituraState();
}

class _ConfirmarLeituraState extends State<_ConfirmarLeitura> {
  late final TextEditingController _nome;
  late final TextEditingController _preco;
  final _qtd = TextEditingController(text: '1');
  String? _erro;

  @override
  void initState() {
    super.initState();
    final r = widget.resultado;
    _nome = TextEditingController(text: r.textos.isNotEmpty ? r.textos.first : '');
    _preco = TextEditingController(
      text: r.precos.isNotEmpty ? centavosParaTexto(r.precos.first) : '',
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _preco.dispose();
    _qtd.dispose();
    super.dispose();
  }

  void _salvar() {
    final n = _nome.text.trim();
    final pr = lerReais(_preco.text);
    final q = int.tryParse(_qtd.text.trim());
    if (n.isEmpty) {
      setState(() => _erro = 'Informe o nome do produto.');
      return;
    }
    if (pr == null || pr <= 0) {
      setState(() => _erro = 'Informe um preço válido, como 12,99.');
      return;
    }
    if (q == null || q < 1 || q > 999) {
      setState(() => _erro = 'A quantidade deve ser de 1 a 999.');
      return;
    }
    Navigator.pop(
      context,
      ItemCompra(nome: n, precoCentavos: pr, quantidade: q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final precoAtual = lerReais(_preco.text);
    final String? aviso = widget.falhou
        ? 'Não consegui analisar a foto. Digite os dados manualmente.'
        : !r.houveTexto
            ? 'Nenhum texto reconhecido. Tente de novo com mais luz e a etiqueta bem enquadrada, ou digite manualmente.'
            : r.precos.isEmpty
                ? 'Li texto, mas nenhum preço. Digite o preço manualmente.'
                : null;

    return AlertDialog(
      title: const Text('Confirmar leitura'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (aviso != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(aviso),
              ),
            if (r.precos.length > 1) ...[
              const Text('Encontrei mais de um preço. Toque no correto:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in r.precos)
                    ChoiceChip(
                      label: Text(formatarReais(p)),
                      selected: precoAtual == p,
                      onSelected: (_) =>
                          setState(() => _preco.text = centavosParaTexto(p)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _preco,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Preço unitário',
                prefixText: 'R\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Produto'),
            ),
            if (r.textos.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Textos lidos (toque para usar como nome):',
                style: TextStyle(fontSize: 12),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in r.textos)
                    ActionChip(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      ),
                      onPressed: () => setState(() => _nome.text = t),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _qtd,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confira os dados lidos pela câmera antes de salvar.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
