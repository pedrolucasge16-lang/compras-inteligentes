# Requisitos funcionais — Compras Inteligentes

## Objetivo

Permitir que o usuário planeje uma compra, acompanhe o gasto, consulte preços anteriores e compare embalagens ou ofertas de maneira simples, com os dados armazenados localmente no aparelho.

## RF-01 — Cadastro e edição de produtos

- Cadastrar nome, preço unitário e quantidade.
- Validar nome não vazio, preço maior que zero e quantidade inteira maior que zero.
- Permitir editar e excluir um item.
- Exibir preço unitário, quantidade e subtotal.
- Usar centavos inteiros para cálculos monetários, evitando erros de arredondamento.

## RF-02 — Lista de compras

- Permitir criar uma lista com nome opcional, data de criação e estado (em andamento ou concluída).
- Adicionar produtos existentes ou cadastrar um produto novo.
- Para cada linha, armazenar nome do produto, quantidade desejada e preço estimado no momento em que foi adicionado.
- Permitir alterar quantidade, editar preço estimado, remover item e trocar/substituir um item.
- Permitir marcar cada linha como “comprado” ou “não comprado”.
- Exibir:
  - total estimado de todos os itens;
  - total estimado dos itens marcados como comprados;
  - total estimado dos itens ainda pendentes;
  - quantidade de itens comprados e pendentes.
- O total estimado da lista é a soma de preço unitário × quantidade de cada item ativo. Não somar linhas removidas ou substituídas.
- Ao concluir a compra, permitir confirmar os preços efetivamente pagos e gravar um registro no histórico.
- Não criar registros de compra no histórico apenas por abrir ou editar uma lista.

## RF-03 — Histórico dos últimos 30 dias

- Registrar uma compra concluída com data e hora, itens, quantidades, preços unitários pagos, subtotais e total final.
- Disponibilizar uma tela “Histórico” com as compras dos últimos 30 dias corridos.
- Em cada compra, exibir a data, o nome de cada produto, quantidade, preço unitário, subtotal e total da compra.
- Permitir abrir uma compra para ver seus detalhes.
- Exibir, para cada produto, o preço mais recente pago e, quando houver dados suficientes, comparar com o preço anterior.
- Ordenar compras da mais recente para a mais antiga.
- Se não houver histórico, exibir uma mensagem clara em vez de uma tela vazia.
- Preservar os registros históricos mesmo se o produto for removido do catálogo/lista atual.
- Usar uma data/hora consistente e filtrar os últimos 30 dias com base na data local do dispositivo.
- Não inventar preços históricos: se não houver registro, mostrar “Sem histórico de preço”.

## RF-04 — Comparador de custo-benefício para 2, 5, 10 e 20 unidades

- Permitir adicionar duas ou mais opções para comparar, como embalagens de tamanhos diferentes ou ofertas diferentes.
- Cada opção deve conter nome/descrição, quantidade de unidades ou conteúdo da embalagem e preço total.
- Calcular o custo por unidade comparável. Para produtos por peso ou volume, permitir informar a quantidade e unidade (g, kg, ml, L); converter para uma unidade comum antes de comparar.
- Mostrar, para cada opção, o custo total para adquirir 2, 5, 10 e 20 unidades de referência.
- Quando a embalagem contém mais de uma unidade, calcular quantas embalagens são necessárias para atingir a quantidade desejada, arredondando para cima, e exibir também o excedente.
- Mostrar custo por unidade de referência, total estimado e economia em relação à opção mais cara para cada quantidade.
- Destacar a melhor opção pelo menor custo comparável, sem assumir que o menor preço de etiqueta é sempre o melhor.
- Se as unidades de medida forem incompatíveis ou os dados estiverem incompletos, avisar que não é possível comparar com segurança.
- Deixar claro que a comparação considera os preços informados pelo usuário e não preços atualizados de lojas automaticamente.

### Regra de cálculo

Para uma embalagem com `conteudoPorEmbalagem` unidades de referência e `precoEmCentavos`:

- `precoPorUnidade = precoEmCentavos / conteudoPorEmbalagem`
- `embalagensNecessarias = teto(quantidadeDesejada / conteudoPorEmbalagem)`
- `totalParaQuantidade = embalagensNecessarias × precoEmCentavos`
- `unidadesAdquiridas = embalagensNecessarias × conteudoPorEmbalagem`
- `excedente = unidadesAdquiridas - quantidadeDesejada`

Não comparar produtos diferentes como se fossem idênticos sem permitir que o usuário confirme que são equivalentes.

## RF-05 — Troca de item na lista

- Disponibilizar ação explícita “Trocar item”.
- Permitir escolher outro produto ou cadastrar um substituto.
- Preservar a quantidade desejada quando fizer sentido, mas atualizar nome e preço estimado para os dados do substituto.
- Mostrar o novo total antes de confirmar a troca.
- Não apagar silenciosamente o item anterior: confirmar a substituição e manter consistência no histórico.
- A troca não deve criar uma compra concluída nem alterar compras antigas.

## RF-06 — Leitura de etiqueta por foto

- Usar a câmera ou seleção de imagem para reconhecer texto da etiqueta.
- Sugerir nome do produto e preço identificados.
- Mostrar os campos reconhecidos em um formulário editável antes de salvar.
- Não salvar automaticamente valores incertos.
- Se houver vários preços, mostrar as opções encontradas e permitir selecionar o preço correto.
- Tratar falhas de permissão, imagem ilegível e ausência de texto com mensagens compreensíveis.

## RF-07 — Orçamento

- Permitir configurar o orçamento em centavos.
- Exibir o total estimado da lista e o saldo estimado.
- Avisar quando o total ultrapassar o orçamento.
- Diferenciar valores estimados dos valores realmente pagos.

## RF-08 — Dados locais e privacidade

- Guardar listas e histórico no banco local SQLite.
- Não exigir conta ou serviço externo para as funções principais.
- Tratar migrações de banco sem apagar os dados existentes.
- Informar ao usuário antes de uma ação destrutiva, como excluir uma lista ou histórico.

## Critérios de aceite gerais

- Os totais são recalculados imediatamente quando quantidade, preço ou estado do item muda.
- Valores monetários são exibidos em reais (R$) com duas casas decimais.
- A lista e o histórico continuam disponíveis depois de fechar e reabrir o aplicativo.
- Uma compra só entra no histórico depois de o usuário confirmar a conclusão.
- Nenhum requisito planejado pode ser marcado como pronto sem implementação e teste no Android.
