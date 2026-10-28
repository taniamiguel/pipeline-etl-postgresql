-- Versão original da camada stage (03/09/2026), recuperada do histórico do pgAdmin.
-- Atenção: a regex de data_prometida e data_entrega ('^[0-9]{1,2}/[0-9]{4}$') não tem o mês,
-- por isso todas essas datas ficavam NULL. Corrigido em sql/pipeline/02_stage.sql.

CREATE TABLE schema01.dados_ecommerce_stage AS
SELECT
    pedido_id,
    item_id,

    /* Datas convertidas - se inválidas, viram NULL */
    CASE
        WHEN data_pedido ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
        THEN TO_DATE(data_pedido, 'DD/MM/YYYY')
        ELSE NULL
    END AS data_pedido,
    
    CASE
        WHEN data_prometida ~ '^[0-9]{1,2}/[0-9]{4}$'
        THEN TO_DATE(data_prometida, 'DD/MM/YYYY')
        ELSE NULL
    END AS data_prometida,
    
    CASE
        WHEN data_entrega ~ '^[0-9]{1,2}/[0-9]{4}$'
        THEN TO_DATE(data_entrega, 'DD/MM/YYYY')
        ELSE NULL
    END AS data_entrega,

    cliente_id,
    segmento_cliente,
    cidade,
    estado,
    regiao,
    canal_venda,
    canal_aquisicao,
    categoria,
    subcategoria,
    produto,

    /* Quantidade - converte e corrige negativos */
    CASE
        WHEN quantidade ~ '^-?[0-9]+$' THEN GREATEST(CAST(quantidade AS INTEGER), 0)
        ELSE NULL
    END AS quantidade,
    
    /* Preço e Custo - converte texto para número */
    CASE
        WHEN preco_unitario ~ '^[0-9]+(\.[0-9]+)?$' THEN CAST(preco_unitario AS NUMERIC(10,2))
        ELSE NULL
    END AS preco_unitario,

    CASE
        WHEN custo_unitario ~ '^[0-9]+(\.[0-9]+)?$' THEN CAST(custo_unitario AS NUMERIC(10,2))
        ELSE NULL
    END AS custo_unitario,

    /* Desconto - garante valores entre 0 e 1 */
    CASE
        WHEN desconto_pct ~ '^[0-9]+(\.[0-9]+)?$'
        THEN LEAST(GREATEST(CAST(desconto_pct AS NUMERIC(5,2)), 0), 1)
        ELSE NULL
    END AS desconto_pct,
    
    /* Frete - converte e corrige negativos */
    CASE
        WHEN frete ~ '^-?[0-9]+(\.[0-9]+)?$' THEN GREATEST(CAST(frete AS NUMERIC(10,2)), 0)
        ELSE NULL
    END AS frete,
    
    metodo_pagamento,
    
    /* Parcelas - converte para inteiro */
    CASE
        WHEN parcelas ~ '^[0-9]+$' THEN CAST(parcelas AS INTEGER)
        ELSE NULL
    END AS parcelas,
    
    status_pedido,
    devolvido,
    
    /* Avaliação - converte para número */
    CASE
        WHEN avaliacao_cliente ~ '^[0-9]+(\.[0-9]+)?$'
        THEN CAST(avaliacao_cliente AS NUMERIC(3,1))
        ELSE NULL
    END AS avaliacao_cliente,

    cupom
FROM schema01.dados_ecommerce_raw;