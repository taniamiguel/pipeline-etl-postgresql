-- =====================================================================
-- CAMADA FINAL: regras de negócio, deduplicação e colunas calculadas
-- - remove linhas repetidas (mesmo pedido_id + item_id)
-- - corrige categoria e subcategoria pela classificação mais comum de cada produto
-- - valores impossíveis viram NULL e ficam marcados em colunas "flag_"
--   (a linha não é apagada para não perder as outras informações dela)
-- - calcula faturamento, custo, lucro e atraso usados nos indicadores
-- =====================================================================

DROP TABLE IF EXISTS ecommerce.final_pedidos;

CREATE TABLE ecommerce.final_pedidos AS
WITH sem_duplicatas AS (
    SELECT *
    FROM (
        SELECT
            s.*,
            ROW_NUMBER() OVER (
                PARTITION BY pedido_id, item_id
                ORDER BY data_entrega NULLS LAST, avaliacao_cliente NULLS LAST
            ) AS ordem
        FROM ecommerce.stage_pedidos s
    ) x
    WHERE ordem = 1
),
/* Referência de cada produto: classificação mais frequente e preço/custo medianos */
referencia_produto AS (
    SELECT
        produto,
        mode() WITHIN GROUP (ORDER BY categoria)                     AS categoria,
        mode() WITHIN GROUP (ORDER BY subcategoria)                  AS subcategoria,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY preco_unitario)  AS preco_mediano,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY custo_unitario)  AS custo_mediano
    FROM ecommerce.stage_pedidos
    WHERE produto <> ''
    GROUP BY produto
),
checado AS (
    SELECT
        d.*,
        COALESCE(r.categoria, d.categoria)       AS categoria_correta,
        COALESCE(r.subcategoria, d.subcategoria) AS subcategoria_correta,
        /* Válido: maior que zero e até 5 vezes acima ou abaixo da mediana do produto */
        (d.preco_unitario > 0 AND (r.preco_mediano IS NULL
            OR d.preco_unitario BETWEEN r.preco_mediano / 5 AND r.preco_mediano * 5)) AS preco_ok,
        (d.custo_unitario > 0 AND (r.custo_mediano IS NULL
            OR d.custo_unitario BETWEEN r.custo_mediano / 5 AND r.custo_mediano * 5)) AS custo_ok
    FROM sem_duplicatas d
    LEFT JOIN referencia_produto r ON r.produto = d.produto
),
validado AS (
    SELECT
        pedido_id, item_id, cliente_id, segmento_cliente,
        cidade, estado, regiao,
        canal_venda, canal_aquisicao, metodo_pagamento, parcelas, cupom,
        categoria_correta                              AS categoria,
        subcategoria_correta                           AS subcategoria,
        COALESCE(NULLIF(produto, ''), 'Não informado') AS produto,

        data_pedido, data_prometida,
        /* Entrega antes do pedido é impossível: a data de entrega é descartada */
        CASE WHEN data_entrega < data_pedido THEN NULL ELSE data_entrega END AS data_entrega,

        CASE WHEN quantidade > 0 THEN quantidade END     AS quantidade,
        CASE WHEN preco_ok THEN preco_unitario END       AS preco_unitario,
        CASE WHEN custo_ok THEN custo_unitario END       AS custo_unitario,
        LEAST(GREATEST(desconto_pct, 0), 1)              AS desconto_pct,
        CASE WHEN frete >= 0 THEN frete END              AS frete,

        status_pedido, devolvido, avaliacao_cliente,

        /* Flags de qualidade: TRUE quando a linha tinha o problema na origem */
        (categoria IS DISTINCT FROM categoria_correta
          OR subcategoria IS DISTINCT FROM subcategoria_correta)          AS flag_categoria_corrigida,
        (produto IS NULL OR produto = '')                                 AS flag_produto_vazio,
        (data_entrega < data_pedido)                                      AS flag_entrega_antes_do_pedido,
        (quantidade IS NULL OR quantidade <= 0)                           AS flag_quantidade_invalida,
        NOT COALESCE(preco_ok, FALSE)                                     AS flag_preco_invalido,
        NOT COALESCE(custo_ok, FALSE)                                     AS flag_custo_invalido,
        (frete < 0)                                                       AS flag_frete_negativo,
        /* Status e coluna "devolvido" se contradizem */
        ((status_pedido = 'Devolvido' AND devolvido = 'Não')
          OR (status_pedido <> 'Devolvido' AND devolvido = 'Sim'))        AS flag_status_divergente
    FROM checado
)
SELECT
    v.*,
    ROUND(quantidade * preco_unitario * (1 - desconto_pct), 2)  AS faturamento,
    ROUND(quantidade * custo_unitario, 2)                       AS custo_total,
    ROUND(quantidade * preco_unitario * (1 - desconto_pct)
          - quantidade * custo_unitario, 2)                     AS lucro,
    /* Atraso só existe para pedido entregue com as duas datas conhecidas */
    CASE WHEN status_pedido = 'Entregue'
          AND data_entrega IS NOT NULL AND data_prometida IS NOT NULL
         THEN data_entrega - data_prometida END                 AS dias_de_atraso
FROM validado v;

ALTER TABLE ecommerce.final_pedidos ADD PRIMARY KEY (pedido_id, item_id);
