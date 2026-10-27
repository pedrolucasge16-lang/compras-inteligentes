# Compras Inteligentes

Aplicativo Android desenvolvido em Flutter/Dart para organizar compras, registrar preços e ajudar a comparar opções antes de comprar.

## Funcionalidades existentes identificadas no código-fonte

- Cadastro de produtos com nome, preço unitário e quantidade.
- Cálculo do subtotal de cada item e do total.
- Definição de orçamento e acompanhamento do saldo.
- Persistência local com SQLite.
- Captura de imagem e leitura de texto de etiquetas usando Google ML Kit.
- Edição e exclusão de itens.

> Importante: os recursos abaixo são requisitos planejados e não devem ser considerados implementados até serem desenvolvidos e testados.

## Funcionalidades a implementar

1. **Lista de compras:** criar uma lista de itens que a pessoa pretende comprar, marcar itens como comprados, editar quantidades e visualizar o total estimado e o total dos itens já comprados.
2. **Histórico do último mês:** registrar compras concluídas nos últimos 30 dias, com data, nome do produto, quantidade, preço unitário, subtotal e total da compra. Permitir consultar o preço pago anteriormente.
3. **Comparador de custo-benefício:** comparar opções do mesmo produto ou produtos equivalentes e calcular o custo total para 2, 5, 10 e 20 unidades, o custo por unidade e a economia estimada.
4. **Troca de item:** permitir substituir um produto da lista por outro sem ter de recomeçar a lista.
5. **Leitura de etiqueta aprimorada:** sugerir automaticamente o nome do produto e o preço reconhecidos na foto, sempre permitindo revisão antes de salvar.

## Documentação do projeto

- [`docs/REQUISITOS_FUNCIONAIS.md`](docs/REQUISITOS_FUNCIONAIS.md): comportamento esperado de cada função.
- [`docs/ESPECIFICACAO_TECNICA.md`](docs/ESPECIFICACAO_TECNICA.md): proposta de arquitetura, banco local e regras de cálculo.
- [`docs/PROMPT_DESENVOLVIMENTO_IA.md`](docs/PROMPT_DESENVOLVIMENTO_IA.md): prompt atualizado para orientar uma IA a implementar o projeto.
- [`docs/PLANO_DE_TESTES.md`](docs/PLANO_DE_TESTES.md): testes para verificar as funções e evitar regressões.

## Tecnologias atuais

- Flutter e Dart.
- SQLite por meio de `sqflite`.
- `image_picker` para selecionar/tirar fotos.
- Google ML Kit Text Recognition para OCR.
- GitHub Actions configurado para gerar um APK de depuração.

## Geração do APK

O repositório contém um workflow em `.github/workflows/build.yml` que gera a plataforma Android durante a execução e publica o APK como artefato de uma execução do GitHub Actions. A pasta `android/` não estava presente no ZIP analisado; portanto, confirme a geração e teste do APK antes de considerar a distribuição pronta.

Para compilar localmente, é necessário ter Flutter, Android SDK e Java configurados. O Termux no Android pode exigir configurações adicionais; se a compilação local não funcionar, use o workflow do GitHub Actions como alternativa.
