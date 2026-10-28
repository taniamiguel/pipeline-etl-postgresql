-- Versão original da camada final (03/09/2026), recuperada do histórico do pgAdmin.
-- Corrigia o formato das datas, mas mantinha duplicatas, textos sem padronização e preço negativo.

CREATE TABLE schema01.dados_ecommerce_final AS
SELECT
    pedido_id,
    cliente_id,
    categoria,
    subcategoria,
    produto,

    /* Datas corrigidas */
    CASE
        WHEN data_pedido ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN TO_DATE(data_pedido, 'DD/MM/YYYY')
        ELSE NULL
    END AS data_pedido,

    CASE
        WHEN data_prometida ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN TO_DATE(data_prometida, 'DD/MM/YYYY')
        ELSE NULL
    END AS data_prometida,

    CASE
        WHEN data_entrega ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN TO_DATE(data_entrega, 'DD/MM/YYYY')
        ELSE NULL
    END AS data_entrega,

    /* Quantidade corrigida */
    CASE
        WHEN quantidade ~ '^-?[0-9]+$' THEN GREATEST(CAST(quantidade AS INTEGER), 0)
        ELSE NULL
    END AS quantidade,

    /* Preço e custo corrigidos */
    CASE
        WHEN preco_unitario ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN CAST(preco_unitario AS NUMERIC(10,2))
        ELSE NULL
    END AS preco_unitario,

    CASE
        WHEN custo_unitario ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN CAST(custo_unitario AS NUMERIC(10,2))
        ELSE NULL
    END AS custo_unitario,

    /* Desconto entre 0 e 1 */
    CASE
        WHEN desconto_pct ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN LEAST(GREATEST(CAST(desconto_pct AS NUMERIC(3,2)), 0), 1)
        ELSE NULL
    END AS desconto_pct,
    
    /* Frete corrigido */
    CASE
        WHEN frete ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN GREATEST(CAST(frete AS NUMERIC(10,2)), 0)
        ELSE NULL
    END AS frete,

    status_pedido,
    devolvido
FROM schema01.dados_ecommerce_raw;
