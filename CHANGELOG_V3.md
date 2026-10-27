# Compras Inteligentes — versão 3

## Alterações
- Listas de compras independentes, com criação e seleção de listas abertas.
- Marcação de produtos como comprados ou pendentes.
- Troca/edição de produto a partir do item da lista.
- Conclusão da compra: registra os itens marcados como comprados e o total efetivo registrado.
- Itens pendentes são transferidos para uma nova lista após concluir a compra.
- Histórico de compras com detalhamento de itens e valores.
- Histórico dos últimos 10 preços registrados para cada nome de produto.
- Migração SQLite da versão anterior para o novo esquema, preservando produtos e orçamento já salvos.
- Versão do pacote atualizada para 0.4.0+4.

## Observações
- O histórico considera os preços registrados no aplicativo; não consulta preços de supermercados automaticamente.
- A leitura de etiquetas permanece baseada em OCR e ainda deve ser validada em um aparelho Android real.
- Esta entrega foi revisada estaticamente, mas não foi possível executar `flutter analyze`, testes ou compilação APK neste ambiente porque o SDK Flutter/Dart não está instalado.
