# Prompt atualizado para desenvolver o Compras Inteligentes

Copie o texto abaixo para a IA que vai trabalhar no repositório. Anexe/indique o código atual e peça para ela editar os arquivos reais do projeto, não apenas devolver exemplos.

---

Você é uma pessoa desenvolvedora Flutter/Dart experiente. Trabalhe no projeto existente **Compras Inteligentes**, um aplicativo Android offline-first. O código atual já contém cadastro de itens com nome, preço unitário em centavos e quantidade, cálculo de totais, orçamento, SQLite e leitura de texto de etiquetas usando `image_picker` e Google ML Kit.

## Objetivo

Evoluir o aplicativo existente sem começar do zero e sem quebrar o que já funciona. O produto final deve poder ser instalado como APK em um celular Android. O projeto é mantido no GitHub e o proprietário usa um celular Android e Termux; quando o build local não for viável, preserve/ajuste o workflow do GitHub Actions para gerar o APK.

## Funcionalidades obrigatórias

### 1. Lista de compras
- Criar uma lista para os produtos que o usuário pretende comprar.
- Permitir adicionar, editar, excluir, trocar/substituir e marcar itens como comprados.
- Guardar quantidade e preço estimado de cada item.
- Exibir o total estimado da lista inteira, total dos itens marcados como comprados e total dos pendentes.
- Permitir concluir a compra e confirmar o preço realmente pago por item.
- Persistir dados localmente no SQLite.

### 2. Histórico dos últimos 30 dias
- Ao confirmar uma compra, salvar data/hora, nome de cada produto, quantidade, preço unitário efetivamente pago, subtotal e total da compra.
- Criar tela de histórico mostrando compras dos últimos 30 dias, da mais recente para a mais antiga.
- Permitir abrir uma compra e consultar o preço pago por cada item.
- Mostrar o preço mais recente conhecido de um produto e, se houver registro anterior, a diferença em reais e percentual.
- Preservar os registros históricos mesmo que o item seja editado ou removido da lista atual.
- Nunca inventar histórico: mostrar “Sem histórico de preço” quando não houver registro.
- Não registrar uma compra no histórico até o usuário confirmar sua conclusão.

### 3. Comparador de custo-benefício: 2, 5, 10 e 20 unidades
- Criar uma tela para cadastrar/comparar duas ou mais opções de compra.
- Para cada opção, informar descrição/nome, preço total da embalagem, conteúdo da embalagem e unidade de medida.
- Calcular o custo por unidade comparável e o total necessário para comprar 2, 5, 10 e 20 unidades de referência.
- Se as embalagens forem fechadas, calcular quantas embalagens são necessárias com arredondamento para cima e mostrar o excedente.
- Mostrar preço por unidade, total estimado e economia em comparação às demais opções.
- Permitir comparação por unidade, peso ou volume, convertendo unidades compatíveis (kg/g e L/ml).
- Não comparar unidades incompatíveis nem afirmar que produtos diferentes são equivalentes sem confirmação do usuário.
- A melhor opção deve ser identificada pelo menor custo comparável, não simplesmente pelo menor preço de etiqueta.
- A comparação usa os preços inseridos pelo usuário; não alegar consulta automática a lojas.

### 4. Trocar item
- Adicionar uma ação clara “Trocar item” na lista.
- Permitir selecionar/cadastrar um substituto e ver o novo total antes de confirmar.
- Não alterar compras passadas nem apagar silenciosamente os dados de histórico.

### 5. Leitura de etiqueta
- Melhorar o fluxo existente de OCR para sugerir o nome do produto e preço a partir da foto.
- Apresentar os valores reconhecidos em formulário editável para confirmação humana antes de salvar.
- Quando houver mais de um preço possível, oferecer escolha ao usuário.
- Tratar permissão negada, imagem ilegível e texto não encontrado com mensagens claras.

### 6. Orçamento e usabilidade
- Preservar orçamento, cadastro manual, edição/exclusão e total atual.
- Diferenciar claramente valores estimados e valores realmente pagos.
- Usar português do Brasil, moeda R$ e duas casas decimais.
- Criar estados vazios, validação de campos e mensagens de erro.
- Interface responsiva e simples de usar no celular.

## Requisitos técnicos
- Continuar usando Flutter/Dart e SQLite (`sqflite`) salvo justificativa técnica real.
- Usar inteiros em centavos para dinheiro.
- Criar migrações de banco seguras; a versão atual do banco é 1 e já possui tabelas `itens` e `config`. Não apagar os dados existentes.
- Fazer gravação de compra e itens do histórico em transação.
- Separar domínio, dados e interface, respeitando a estrutura já presente.
- Não substituir todo o projeto por um protótipo nem remover funcionalidades existentes.
- Não incluir chaves secretas no GitHub.
- Manter ou corrigir `.github/workflows/build.yml` para gerar `app-debug.apk` como artefato.
- O projeto atual não contém a pasta `android/` no ZIP analisado; verifique a geração da plataforma Android e documente a forma confiável de gerar o APK.
- Considere que o proprietário trabalha pelo Android/Termux. Forneça comandos compatíveis e, quando necessário, explique como baixar o APK gerado pelo GitHub Actions.

## Processo obrigatório
1. Inspecione todos os arquivos atuais antes de editar.
2. Resuma a arquitetura e liste os riscos.
3. Implemente as funcionalidades nos arquivos reais, não apenas em documentação.
4. Faça migrações sem perder os dados já existentes.
5. Adicione testes unitários para cálculos, comparação, filtros de 30 dias e totais.
6. Execute `dart format`, `flutter analyze` e testes disponíveis.
7. Tente `flutter build apk --debug` no ambiente disponível; se não for possível, informe o motivo e valide o workflow de CI.
8. Corrija os erros encontrados e informe claramente o que foi testado e o que ainda não foi testado.
9. Ao final, liste cada arquivo criado/modificado e dê passos objetivos para gerar/instalar o APK pelo celular.

Não diga que algo foi implementado ou testado se não tiver realmente sido feito. Comece inspecionando o projeto e prossiga até entregar alterações concretas.
