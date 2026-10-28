-- =====================================================================
-- OS 5 INDICADORES DO PROJETO
-- Receita líquida = quantidade × preço × (1 − desconto)
-- Margem bruta    = receita líquida − quantidade × custo unitário
-- Receita, margem e ticket consideram só pedidos com status "Entregue":
-- pedido cancelado ou devolvido não gera receita.
-- =====================================================================

-- 1. Receita líquida
SELECT
    COUNT(DISTINCT pedido_id)                          AS pedidos,
    ROUND(SUM(quantidade * preco_unitario), 2)         AS receita_bruta,
    ROUND(SUM(quantidade * preco_unitario) - SUM(faturamento), 2) AS descontos,
    ROUND(SUM(faturamento), 2)                         AS receita_liquida
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND faturamento IS NOT NULL;

-- 2a. Margem bruta total e por categoria
SELECT
    COALESCE(categoria, 'TOTAL')                       AS categoria,
    ROUND(SUM(faturamento), 2)                         AS receita_liquida,
    ROUND(SUM(custo_total), 2)                         AS custo,
    ROUND(SUM(lucro), 2)                               AS margem_bruta,
    ROUND(100 * SUM(lucro) / SUM(faturamento), 1)      AS margem_bruta_pct
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND lucro IS NOT NULL
GROUP BY ROLLUP (categoria)
ORDER BY categoria IS NULL, margem_bruta_pct DESC;

-- 2b. Margem bruta por produto (5 maiores e 5 menores)
WITH por_produto AS (
    SELECT
        categoria,
        produto,
        ROUND(SUM(faturamento), 2)                     AS receita_liquida,
        ROUND(SUM(lucro), 2)                           AS margem_bruta,
        ROUND(100 * SUM(lucro) / SUM(faturamento), 1)  AS margem_bruta_pct,
        RANK() OVER (ORDER BY SUM(lucro) / SUM(faturamento) DESC) AS posicao,
        COUNT(*) OVER ()                               AS total_produtos
    FROM ecommerce.final_pedidos
    WHERE status_pedido = 'Entregue'
      AND lucro IS NOT NULL
      AND produto <> 'Não informado'
    GROUP BY categoria, produto
)
SELECT posicao, categoria, produto, receita_liquida, margem_bruta, margem_bruta_pct
FROM por_produto
WHERE posicao <= 5 OR posicao > total_produtos - 5
ORDER BY posicao;

-- 3. Taxa de devolução (itens devolvidos ÷ itens vendidos, sem os cancelados)
SELECT
    COALESCE(categoria, 'TOTAL')                                     AS categoria,
    COUNT(*)                                                         AS itens,
    COUNT(*) FILTER (WHERE devolvido = 'Sim')                        AS devolvidos,
    ROUND(100.0 * COUNT(*) FILTER (WHERE devolvido = 'Sim') / COUNT(*), 1) AS taxa_devolucao_pct
FROM ecommerce.final_pedidos
WHERE status_pedido <> 'Cancelado'
GROUP BY ROLLUP (categoria)
ORDER BY categoria IS NULL, taxa_devolucao_pct DESC;

-- 4. Atraso médio na entrega
-- Só pedidos "Entregue" com data prometida e data de entrega conhecidas.
-- Entregas adiantadas entram como atraso negativo: tirá-las da média a deixaria maior do que é.
-- Datas vazias não são inventadas: essas linhas ficam fora do cálculo.
SELECT
    COUNT(*)                                                         AS pedidos_com_data,
    ROUND(AVG(dias_de_atraso), 2)                                    AS atraso_medio_dias,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dias_de_atraso < 0) / COUNT(*), 1) AS pct_adiantados,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dias_de_atraso = 0) / COUNT(*), 1) AS pct_no_dia,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dias_de_atraso > 0) / COUNT(*), 1) AS pct_atrasados,
    ROUND(AVG(dias_de_atraso) FILTER (WHERE dias_de_atraso > 0), 1)  AS atraso_medio_dos_atrasados,
    ROUND(AVG(avaliacao_cliente) FILTER (WHERE dias_de_atraso <= 0), 2) AS nota_no_prazo,
    ROUND(AVG(avaliacao_cliente) FILTER (WHERE dias_de_atraso > 0), 2)  AS nota_com_atraso
FROM ecommerce.final_pedidos
WHERE dias_de_atraso IS NOT NULL;

-- 5. Ticket médio por cliente (receita líquida ÷ clientes), por segmento
SELECT
    COALESCE(segmento_cliente, 'TOTAL')                       AS segmento_cliente,
    COUNT(DISTINCT cliente_id)                                AS clientes,
    COUNT(DISTINCT pedido_id)                                 AS pedidos,
    ROUND(SUM(faturamento) / COUNT(DISTINCT cliente_id), 2)   AS ticket_medio_por_cliente,
    ROUND(SUM(faturamento) / COUNT(DISTINCT pedido_id), 2)    AS ticket_medio_por_pedido
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND faturamento IS NOT NULL
GROUP BY ROLLUP (segmento_cliente)
ORDER BY segmento_cliente IS NULL, ticket_medio_por_cliente DESC;
