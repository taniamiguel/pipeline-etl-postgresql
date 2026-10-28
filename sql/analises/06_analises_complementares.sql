-- =====================================================================
-- ANÁLISES COMPLEMENTARES
-- As três primeiras são as consultas que fiz no curso, agora sobre a tabela padronizada.
-- =====================================================================

-- 6a. Os 10 clientes com maior ticket médio
SELECT
    cliente_id,
    COUNT(DISTINCT pedido_id)                                     AS pedidos,
    ROUND(SUM(faturamento) / NULLIF(COUNT(DISTINCT pedido_id), 0), 2) AS ticket_medio
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND faturamento IS NOT NULL
GROUP BY cliente_id
ORDER BY ticket_medio DESC
LIMIT 10;

-- 6b. Vendas por categoria e subcategoria
SELECT
    categoria,
    subcategoria,
    ROUND(SUM(faturamento), 2) AS total_vendas
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND faturamento IS NOT NULL
GROUP BY categoria, subcategoria
ORDER BY total_vendas DESC;

-- 6c. Os 3 produtos mais vendidos em quantidade
SELECT
    produto,
    SUM(quantidade) AS total_quantidade_vendida
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND quantidade IS NOT NULL
GROUP BY produto
ORDER BY total_quantidade_vendida DESC
LIMIT 3;

-- 6d. Faturamento e margem por canal de venda
SELECT
    canal_venda,
    COUNT(DISTINCT pedido_id)                          AS pedidos,
    ROUND(SUM(faturamento), 2)                         AS faturamento,
    ROUND(SUM(faturamento) / COUNT(DISTINCT pedido_id), 2) AS ticket_medio,
    ROUND(100 * SUM(lucro) / SUM(faturamento), 1)      AS margem_pct
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND lucro IS NOT NULL
GROUP BY canal_venda
ORDER BY faturamento DESC;

-- 6e. Efeito dos cupons: desconto médio e margem com e sem cupom
SELECT
    COALESCE(cupom, 'Sem cupom')                       AS cupom,
    COUNT(*)                                           AS itens,
    ROUND(100 * AVG(desconto_pct), 1)                  AS desconto_medio_pct,
    ROUND(100 * SUM(lucro) / SUM(faturamento), 1)      AS margem_pct
FROM ecommerce.final_pedidos
WHERE status_pedido = 'Entregue'
  AND lucro IS NOT NULL
GROUP BY COALESCE(cupom, 'Sem cupom')
ORDER BY itens DESC;
