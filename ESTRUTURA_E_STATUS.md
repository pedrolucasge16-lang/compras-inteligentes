# Estrutura e status do projeto Compras Inteligentes

## Funcionalidades Incluídas
- Tela "Criar lista por seção" para cadastrar produtos agrupados por categoria sem exigir preço no cadastro; o preço real pode ser informado na confirmação da compra.
- Botão flutuante (+) na tela principal abre a tela de criação de lista e atualiza a lista ao retornar.
- Lista local com SQLite persistente: adicionar, editar, excluir, marcar comprado/pendente e compras parciais.
- Categorização de produtos nas 11 categorias solicitadas (Carnes, Frutas e verduras, Laticínios, Cereais, Massas, Bebidas, Padaria, Higiene pessoal, Limpeza, Congelados, Outros).
- Orçamento persistido e saldo/alerta visual de limite de gastos.
- Troca de produto com registro do item antigo como substituído.
- OCR local via Google ML Kit: captura por câmera e extração heurística de nome e preço brasileiro.
- Reconhecimento Inteligente de Produtos: compara a leitura da câmera contra a lista ativa cadastrada, tratando correspondências de alta confiança, ambiguidades com múltiplos produtos similares e opções manuais quando o produto não for encontrado.
- Tratamento cuidadoso de preços: preserva valores com vírgulas e pontos e nunca força R$ 0,00 silenciosamente.
- Nova Aba "Faltam Comprar": lista prática agrupada por categorias com contador de progresso por itens distintos (ex: 8 de 20 comprados = 40%) e suporte a itens pendentes/parciais.
- Nova Aba "Próximo Item": assistente passo a passo que guia o usuário pelo supermercado seguindo a ordem fixa de categorias, pulando categorias vazias e concluídas, com destaque visual e confirmação rápida.
- Finalização transacional da compra: arquiva itens concluídos e frações compradas no histórico e preserva os itens pendentes na lista ativa.
- Histórico dos últimos 30 dias com detalhamento de compras.
- Comparador de 2, 5, 10 e 20 unidades e embalagens por massa, volume e unidade.
- Testes unitários para regras de moeda, parser de preços, passos de quantidade, modelo ShoppingItem, categorias e casamento de produtos por OCR.
- Workflow GitHub Actions automatizado para análise, testes e compilação do APK de Release.

## Histórico de Versões do Banco SQLite
- Versão 1: Estrutura inicial (shopping_items, purchases, purchase_items, settings).
- Versão 2: Adição de `original_item_id`, `original_item_name` e `actual_unit_price_cents`.
- Versão 3: Migração segura via `ALTER TABLE` adicionando `category` (com padrão 'Outros') e `bought_quantity` (com padrão 0.0), preservando todos os dados anteriores sem perda de histórico.
