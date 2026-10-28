# Estrutura e status do projeto Compras Inteligentes

## Arquivos incluídos nesta atualização
- `lib/screens/create_list_screen.dart`: tela para cadastrar produtos por seção do mercado, com quantidade e unidade, sem exigir preço.
- `lib/screens/home_screen.dart`: botão flutuante redondo (`FloatingActionButton`) com `Icons.add`, que abre a tela de criação e recarrega a lista ao retornar.
- `lib/models/category.dart` e `lib/models/shopping_item.dart`: categorias e modelo dos produtos.
- `lib/services/product_matcher.dart`: correspondência entre o texto lido por OCR e produtos da lista.
- `lib/services/database_service.dart`: persistência local SQLite e finalização/histórico da compra.
- `lib/screens/tabs/pending_tab.dart` e `lib/screens/tabs/next_item_tab.dart`: abas de pendências e orientação por seção.
- Testes unitários existentes para categoria, modelo de produto e correspondência por OCR.

## Comportamento da compra por foto
O fluxo de leitura por câmera está implementado em `home_screen.dart`: tenta associar o produto lido a um item da lista e abre a confirmação da compra com o preço sugerido pelo OCR. Ao confirmar, atualiza a quantidade comprada e o preço efetivo. A aba “Faltam Comprar” filtra os itens totalmente comprados; compras parciais continuam pendentes até completar a quantidade. O total calculado usa o preço efetivo quando disponível.

## Observação importante
O ZIP de entrada continha uma pasta mãe `atualizacao/`, além de uma segunda cópia dos arquivos na raiz, e não continha `create_list_screen.dart` nem o botão flutuante na tela principal. Esta atualização removeu a duplicação, criou a tela ausente e conectou o botão à navegação.

## Estrutura esperada na raiz do ZIP
- `ESTRUTURA_E_STATUS.md`
- `lib/models/category.dart`
- `lib/models/shopping_item.dart`
- `lib/services/database_service.dart`
- `lib/services/product_matcher.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/create_list_screen.dart`
- `lib/screens/tabs/pending_tab.dart`
- `lib/screens/tabs/next_item_tab.dart`
- `test/category_test.dart`
- `test/product_matcher_test.dart`
- `test/shopping_item_test.dart`

O arquivo ZIP contém os arquivos diretamente na raiz, sem pasta mãe e sem duplicatas.
