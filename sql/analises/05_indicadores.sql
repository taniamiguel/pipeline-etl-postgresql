-- =====================================================================
-- OS 5 INDICADORES DO PROJETO
-- Faturamento = quantidade × preço × (1 − desconto)
-- Lucro       = faturamento − quantidade × custo unitário
-- Faturamento, lucro, margem e ticket consideram só pedidos com status "Entregue".
-- =====================================================================

-- 1. Lucro líquido total
SELECT
    ROUND(SUM(faturamento), 2)                         AS faturamento,
    ROUND(SUM(custo_total), 2)                         AS custo,
    ROUND(SUM(lucro), 2)                               AS lucro_liquido,
    ROUND(100 * SUM(lucro) / SUM(faturamento), 1)      AS margem_pct
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND lucro IS NOT NULL;

-- 2a. Margem bruta por categoria
SELECT
    categoria,
    ROUND(SUM(faturamento), 2)                         AS faturamento,
    ROUND(SUM(lucro), 2)                               AS lucro,
    ROUND(100 * SUM(lucro) / SUM(faturamento), 1)      AS margem_pct
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND lucro IS NOT NULL
GROUP BY categoria
ORDER BY margem_pct DESC;

-- 2b. Margem bruta por produto (5 maiores e 5 menores)
WITH por_produto AS (
    SELECT
        categoria,
        produto,
        ROUND(SUM(faturamento), 2)                     AS faturamento,
        ROUND(100 * SUM(lucro) / SUM(faturamento), 1)  AS margem_pct,
        RANK() OVER (ORDER BY SUM(lucro) / SUM(faturamento) DESC) AS posicao,
        COUNT(*) OVER ()                               AS total_produtos
    FROM ecommerce.final_pedidos
    WHERE status_pedido = 'Entregue'
      AND lucro IS NOT NULL
      AND produto <> 'Não informado'
    GROUP BY categoria, produto
)
SELECT posicao, categoria, produto, faturamento, margem_pct
FROM por_produto
WHERE posicao <= 5 OR posicao > total_produtos - 5
ORDER BY posicao;

-- 3. Taxa de devolução (itens devolvidos ÷ itens vendidos, sem os cancelados)
SELECT
    categoria,
    COUNT(*)                                                         AS itens,
    COUNT(*) FILTER (WHERE devolvido = 'Sim')                        AS devolvidos,
    ROUND(100.0 * COUNT(*) FILTER (WHERE devolvido = 'Sim') / COUNT(*), 1) AS taxa_devolucao_pct
FROM ecommerce.final_pedidos
WHERE status_pedido <> 'Cancelado'
GROUP BY ROLLUP (categoria)
ORDER BY categoria NULLS LAST;

-- 4. Atraso médio na entrega
-- Só pedidos "Entregue" com data prometida e data de entrega conhecidas.
-- Datas vazias não são inventadas: essas linhas ficam fora do cálculo.
SELECT
    COUNT(*)                                                      AS pedidos_com_data,
    ROUND(AVG(dias_de_atraso), 1)                                 AS atraso_medio_dias,
    ROUND(AVG(dias_de_atraso) FILTER (WHERE dias_de_atraso > 0), 1) AS atraso_medio_dos_atrasados,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dias_de_atraso > 0) / COUNT(*), 1) AS pct_atrasados,
    ROUND(AVG(avaliacao_cliente) FILTER (WHERE dias_de_atraso <= 0), 2) AS nota_no_prazo,
    ROUND(AVG(avaliacao_cliente) FILTER (WHERE dias_de_atraso > 0), 2)  AS nota_com_atraso
FROM ecommerce.final_pedidos
WHERE dias_de_atraso IS NOT NULL;

-- 5. Ticket médio por cliente
WITH por_cliente AS (
    SELECT
        cliente_id,
        segmento_cliente,
        COUNT(DISTINCT pedido_id)                      AS pedidos,
        SUM(faturamento)                               AS faturamento
    FROM ecommerce.final_pedidos
    WHERE status_pedido = 'Entregue'
      AND faturamento IS NOT NULL
    GROUP BY cliente_id, segmento_cliente
)
SELECT
    segmento_cliente,
    COUNT(*)                                           AS clientes,
    ROUND(SUM(faturamento) / SUM(pedidos), 2)          AS ticket_medio,
    ROUND(AVG(pedidos), 2)                             AS pedidos_por_cliente
FROM por_cliente
GROUP BY ROLLUP (segmento_cliente)
ORDER BY segmento_cliente NULLS LAST;
