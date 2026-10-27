# Especificação técnica — Compras Inteligentes

## Estado atual observado

O código-fonte enviado usa Flutter/Dart, `sqflite`, `image_picker` e `google_mlkit_text_recognition`. O modelo `ItemCompra` atual armazena nome, preço em centavos e quantidade. O banco local atual cria as tabelas `itens` e `config` na versão 1. O workflow de GitHub Actions cria a plataforma Android durante a compilação.

As funções de lista de compras, histórico e comparador descritas aqui são propostas de implementação, não confirmação de que já existem no código.

## Diretrizes

- Manter a aplicação offline-first.
- Usar SQLite para persistência.
- Representar dinheiro como inteiro em centavos.
- Separar modelos de domínio, acesso a dados e interface.
- Evitar reescrever recursos existentes sem necessidade.
- Preservar dados do banco atual em qualquer migração.
- Exibir mensagens de erro úteis e estados vazios.

## Modelo de dados proposto

Os nomes são sugestões; podem ser adaptados à arquitetura existente, mantendo os mesmos dados e relações.

### `listas_compra`

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `nome TEXT`
- `criada_em TEXT NOT NULL` — ISO-8601
- `status TEXT NOT NULL` — `aberta` ou `concluida`
- `concluida_em TEXT NULL`

### `itens_lista`

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `lista_id INTEGER NOT NULL`
- `nome_produto TEXT NOT NULL`
- `quantidade INTEGER NOT NULL`
- `preco_estimado_centavos INTEGER NOT NULL`
- `comprado INTEGER NOT NULL DEFAULT 0`
- `substitui_item_id INTEGER NULL`
- chave estrangeira para `listas_compra(id)`

Guardar o nome e o preço estimado como snapshot evita que mudanças futuras no cadastro alterem listas antigas.

### `compras_historico`

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `lista_id INTEGER NULL`
- `data_compra TEXT NOT NULL` — ISO-8601
- `total_centavos INTEGER NOT NULL`

### `itens_historico`

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `compra_id INTEGER NOT NULL`
- `nome_produto TEXT NOT NULL`
- `quantidade INTEGER NOT NULL`
- `preco_unitario_centavos INTEGER NOT NULL`
- `subtotal_centavos INTEGER NOT NULL`
- chave estrangeira para `compras_historico(id)`

O histórico precisa guardar snapshots de nome, quantidade e preço para não mudar quando a lista atual for editada.

### Comparador

O comparador pode calcular os resultados sem persistência. Se o usuário quiser salvar comparações, criar uma tabela separada somente após essa necessidade ser definida. Para cada opção, guardar a descrição, o preço da embalagem, o conteúdo e sua unidade de medida.

## Migração do banco

O banco atual usa versão 1. Ao adicionar as novas tabelas:

1. Aumentar a versão do banco para 2 ou superior.
2. Implementar `onUpgrade` com `CREATE TABLE` das novas tabelas e índices.
3. Não apagar nem recriar as tabelas `itens` e `config`.
4. Testar a atualização a partir de um banco versão 1 contendo dados reais.
5. Garantir que listas e histórico recém-criados persistam após reiniciar o aplicativo.

Se o projeto receber novas mudanças de esquema, incrementar a versão e criar uma migração para cada versão anterior suportada.

## Regras de cálculo

- Subtotal: `precoUnitarioCentavos * quantidade`.
- Total estimado da lista: soma dos subtotais dos itens não removidos.
- Total estimado comprado: soma dos subtotais dos itens marcados como comprados.
- Total pendente: soma dos subtotais dos itens não marcados como comprados.
- Total do histórico: soma dos subtotais gravados na compra concluída.
- A conclusão da compra deve ocorrer em transação SQLite para evitar cabeçalho de compra sem seus itens.
- O preço real pago pode diferir do estimado; pedir confirmação/edição antes de registrar.
- Comparações de peso/volume devem normalizar unidades antes de comparar (por exemplo, kg para g e L para ml).
- Para atingir uma quantidade de referência usando embalagens fechadas, usar arredondamento para cima e mostrar excedente.

## Organização sugerida

Manter a estrutura existente e adicionar arquivos conforme necessário, por exemplo:

- `lib/domain/lista_compra.dart`
- `lib/domain/item_lista.dart`
- `lib/domain/compra_historico.dart`
- `lib/domain/item_historico.dart`
- `lib/domain/opcao_comparacao.dart`
- `lib/data/banco_local.dart` — migrações e consultas
- `lib/ui/tela_lista_compras.dart`
- `lib/ui/tela_historico.dart`
- `lib/ui/tela_comparador.dart`

Os nomes são sugestões. Evitar duplicar modelos se já existir estrutura equivalente.

## APK e integração contínua

- Preservar o workflow de GitHub Actions existente enquanto ele estiver funcionando.
- Verificar `flutter analyze`, testes e `flutter build apk --debug`.
- Não incluir segredos ou chaves privadas no repositório.
- O Termux pode não oferecer a mesma experiência de build do ambiente Linux/CI; documentar erros reais em vez de presumir que a compilação local funciona.
