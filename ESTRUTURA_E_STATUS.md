# Estrutura e status desta entrega

## Incluído
- Lista local com SQLite: adicionar, editar, excluir, marcar comprado/pendente.
- Orçamento persistido e saldo/alerta visual.
- Troca de produto com registro do item antigo como substituído.
- OCR local via ML Kit: captura por câmera e sugestão de nome/preço para revisão.
- Finalização transacional da compra e registro de itens.
- Histórico dos últimos 30 dias e detalhe dos itens.
- Comparador de 2, 5, 10 e 20 unidades.
- Comparação de embalagens por massa, volume e unidade.
- Testes unitários para moeda e comparador.
- Workflow GitHub Actions para análise, testes e APK.

## Pendências conhecidas para uma versão de produção
- Histórico de preço por produto e comparação automática com compras anteriores ainda precisa de uma camada de catálogo/consulta dedicada.
- A tela ainda não implementa reaproveitamento de itens de compras anteriores.
- A função de registrar preço real está disponível como campo de preço unitário no cadastro, mas ainda pode ser melhorada com um fluxo explícito de confirmação de preço real.
- OCR de nome/preço é heurístico; precisa ser validado com fotos reais.
- A substituição preserva o item original na lista como marcado substituído; o relatório de compra armazena a observação genérica "substituição", e pode ser refinado para registrar nome original e substituto de forma estruturada.
- Testes de integração SQLite e migrações futuras ainda precisam ser adicionados.
- Este ambiente de geração de arquivos não executou Flutter nem compilou o APK. A primeira execução do workflow será a evidência da compilação real.

## Etapa 2 (branch trabalho-v2)
- Histórico: corrigido o erro `LocaleDataException` (datas em pt_BR inicializadas no `main.dart`).
- OCR: leitor de preço separado em `lib/services/price_parser.dart` (testável sem celular). Ignora código de barras, peso, validade e tabela nutricional; mostra vários preços para escolha; mostra o texto lido na revisão.
- Lista: botões [−] e [+] em cada produto (1 em 1 para unidade, 0,5 para kg/L, 100 para g/ml), nunca chega a zero, salva no SQLite.
- Workflow: aplica `atualizacao.zip` na branch de trabalho, mostra a versão do Flutter e guarda o `mapping.txt` do R8.
- Ainda não feito: várias listas de compras e migração do banco (Etapa 3).
