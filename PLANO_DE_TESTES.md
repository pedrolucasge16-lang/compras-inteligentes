# Plano de testes — Compras Inteligentes

## 1. Cadastro e totais

- [ ] Cadastrar um item de R$ 3,50 em quantidade 2: subtotal R$ 7,00.
- [ ] Alterar quantidade e verificar recálculo imediato.
- [ ] Alterar preço e verificar recálculo imediato.
- [ ] Rejeitar nome vazio, quantidade zero/negativa e preço inválido.
- [ ] Confirmar que o orçamento não altera os preços e que o saldo é calculado corretamente.

## 2. Lista de compras

- [ ] Criar lista vazia e confirmar estado vazio amigável.
- [ ] Adicionar itens e validar o total estimado.
- [ ] Marcar um item como comprado e verificar totais comprado e pendente.
- [ ] Desmarcar um item e verificar reversão dos totais.
- [ ] Trocar um item e confirmar o novo total antes de aceitar.
- [ ] Excluir item e confirmar que não entra no total.
- [ ] Fechar e reabrir o app; confirmar persistência da lista.
- [ ] Concluir compra e confirmar preços reais antes de registrar histórico.

## 3. Histórico de 30 dias

- [ ] Confirmar uma compra com dois produtos e verificar cabeçalho, itens, subtotais e total.
- [ ] Verificar se compras de hoje e de 30 dias atrás aparecem conforme a regra de corte documentada.
- [ ] Verificar se uma compra anterior ao intervalo de 30 dias não aparece na lista padrão.
- [ ] Verificar ordenação da mais recente para a mais antiga.
- [ ] Editar/remover um produto da lista atual e confirmar que o registro histórico continua igual.
- [ ] Conferir preço mais recente e diferença em reais/percentual quando houver compra anterior.
- [ ] Conferir mensagem “Sem histórico de preço” para produto sem registros.
- [ ] Simular falha durante a gravação e verificar que a transação não deixa compra incompleta.

## 4. Comparador de 2, 5, 10 e 20 unidades

- [ ] Comparar duas opções de embalagem com a mesma unidade de medida.
- [ ] Conferir cálculos para quantidades-alvo 2, 5, 10 e 20.
- [ ] Validar arredondamento para cima quando não for possível comprar fração de embalagem.
- [ ] Conferir excedente de unidades após comprar embalagens fechadas.
- [ ] Testar conversão de 1 kg para 1000 g e de 1 L para 1000 ml.
- [ ] Bloquear comparação de unidades incompatíveis, como kg e ml.
- [ ] Conferir identificação da opção mais econômica pelo custo comparável.
- [ ] Conferir cálculo da economia sem valores negativos ou divisão por zero.
- [ ] Confirmar que a interface informa que os preços são os digitados pelo usuário.

## 5. OCR / leitura de etiqueta

- [ ] Reconhecer texto e preço em imagem nítida.
- [ ] Tratar imagem sem texto.
- [ ] Tratar mais de um preço candidato e permitir seleção.
- [ ] Confirmar que o OCR não salva automaticamente sem revisão.
- [ ] Tratar permissão de câmera/galeria negada e falha de leitura.

## 6. Banco e build

- [ ] Migrar um banco versão 1 com dados existentes sem perder `itens` ou `config`.
- [ ] Reiniciar o app após migração e conferir dados.
- [ ] Executar `dart format`.
- [ ] Executar `flutter analyze`.
- [ ] Executar testes unitários.
- [ ] Gerar APK de depuração e instalar em aparelho Android.
- [ ] Verificar navegação, banco local, câmera/OCR e histórico no aparelho.
- [ ] Confirmar que o workflow do GitHub Actions publica o APK como artefato.
