# Estrutura e status do projeto Compras Inteligentes

## Redesign Visual e Identidade (Etapa 4)
- **Fotografia oficial integrada**: `assets/images/supermarket_banner.jpg` configurada em `pubspec.yaml` e exibida na tela principal em banner horizontal (~23% da altura da tela) com `BoxFit.cover` e gradiente suave para máxima legibilidade do título "Compras Inteligentes" e ícones de ação.
- **Paleta de cores centralizada (`lib/theme/app_theme.dart`)**:
  - Verde-escuro principal: `#245C46`
  - Verde de destaque: `#387653`
  - Verde-claro: `#E7F0E6`
  - Creme de fundo: `#FAF7F0`
  - Branco de cartões: `#FFFFFF`
  - Madeira clara: `#D8B895`
  - Laranja suave: `#E99A52`
  - Texto principal: `#292D2A`
  - Texto secundário: `#747A75`
  - Bordas discretas: `#E5E0D7`
  - Vermelho de alerta: `#C94C4C`
- **Cartão de Resumo Financeiro em 2 colunas**:
  - Coluna esquerda: Total da lista em destaque, orçamento com acesso rápido e barra de progresso percentual.
  - Coluna direita: Valores Comprado e Pendente, mais indicadores de itens concluídos e pendentes.
- **Telas Padronizadas**:
  - `HomeScreen` (Minha Lista) com filtros rápidos de categorias, barra "Selecionar tudo (Select All)", cartões brancos com controle cápsula de quantidade `[-] 1 kg [+]` e botão de câmera para preço no próprio item.
  - `CreateListScreen` (Adicionar à Lista) com fundo creme, campos brancos, seletor de categoria verde-claro suave com detecção automática e cadastro no banco de setores.
  - `PendingTab` (Faltam Comprar), `NextItemTab` (Próximo Item), `HistoryScreen` (Histórico de Compras) e diálogo de `Orçamento da Lista` padronizados.

## Funcionalidades Preservadas
- Lista local com SQLite persistente: adicionar, editar, excluir, marcar comprado/pendente, compras parciais e selecionar tudo.
- Categorização automática nas 11 categorias + banco de setores personalizável pelo usuário.
- OCR local via Google ML Kit: captura por câmera na prateleira e no topo.
- Comprovante de compra confirmada com valor total gasto e data/hora atual.
- Histórico dos últimos 30 dias e comparador de embalagens/unidades.
