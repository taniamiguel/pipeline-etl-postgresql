-- =====================================================================
-- CAMADA STAGE: tipagem e padronização
-- - converte texto em DATE, INTEGER e NUMERIC (o que não for válido vira NULL)
-- - padroniza textos escritos de formas diferentes ("APP", " Site ", "eletronicos")
-- - completa estado e região vazios a partir da cidade
-- Valores fora da regra de negócio (ex.: quantidade negativa) são mantidos aqui
-- e tratados na camada final, para não esconder o problema.
-- =====================================================================

-- Chave de comparação: sem espaços nas pontas, minúscula e sem acento.
-- Assim "Loja fisica", "Loja Física" e "loja física " viram a mesma chave.
CREATE OR REPLACE FUNCTION ecommerce.chave(valor TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
    SELECT NULLIF(translate(lower(trim(valor)), 'áàâãéêíóôõúç', 'aaaaeeiooouc'), '')
$$;

DROP TABLE IF EXISTS ecommerce.stage_pedidos CASCADE;

CREATE TABLE ecommerce.stage_pedidos AS
WITH tipado AS (
    SELECT
        trim(pedido_id) AS pedido_id,
        trim(item_id)   AS item_id,

        /* Datas do pedido e prometida vêm em DD/MM/AAAA.
           Correção da v1: a regex precisa ter dia, mês e ano. */
        CASE WHEN data_pedido    ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN to_date(data_pedido,    'DD/MM/YYYY') END AS data_pedido,
        CASE WHEN data_prometida ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN to_date(data_prometida, 'DD/MM/YYYY') END AS data_prometida,
        /* A data de entrega vem em MM/DD/AAAA (dia e mês invertidos). Evidências:
           - lida como DD/MM, a entrega cai de -321 a +339 dias do pedido;
           - lida como MM/DD, cai de -5 a +16 dias, coerente com o prazo prometido (2 a 15 dias). */
        CASE WHEN data_entrega   ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN to_date(data_entrega,   'MM/DD/YYYY') END AS data_entrega,

        trim(cliente_id)                                   AS cliente_id,
        CASE ecommerce.chave(segmento_cliente)
            WHEN 'novo'       THEN 'Novo'
            WHEN 'recorrente' THEN 'Recorrente'
            WHEN 'vip'        THEN 'VIP'
            ELSE 'Não informado'
        END AS segmento_cliente,
        trim(cidade)                                       AS cidade,
        NULLIF(upper(trim(estado)), '')                    AS estado,
        NULLIF(trim(regiao), '')                           AS regiao,

        CASE ecommerce.chave(canal_venda)
            WHEN 'site'        THEN 'Site'
            WHEN 'app'         THEN 'App'
            WHEN 'marketplace' THEN 'Marketplace'
            WHEN 'loja fisica' THEN 'Loja Física'
        END AS canal_venda,

        CASE ecommerce.chave(canal_aquisicao)
            WHEN 'organico'  THEN 'Orgânico'
            WHEN 'pago'      THEN 'Pago'
            WHEN 'social'    THEN 'Social'
            WHEN 'email'     THEN 'Email'
            WHEN 'indicacao' THEN 'Indicação'
        END AS canal_aquisicao,

        CASE ecommerce.chave(categoria)
            WHEN 'eletronicos'           THEN 'Eletrônicos'
            WHEN 'moda'                  THEN 'Moda'
            WHEN 'casa'                  THEN 'Casa'
            WHEN 'beleza'                THEN 'Beleza'
            WHEN 'esporte'               THEN 'Esporte'
            WHEN 'esportes'              THEN 'Esporte'
        END AS categoria,

        trim(subcategoria) AS subcategoria,
        trim(produto)      AS produto,

        CASE WHEN quantidade     ~ '^-?[0-9]+$'              THEN quantidade::INTEGER        END AS quantidade,
        CASE WHEN preco_unitario ~ '^-?[0-9]+(\.[0-9]+)?$'   THEN preco_unitario::NUMERIC(10,2) END AS preco_unitario,
        CASE WHEN custo_unitario ~ '^-?[0-9]+(\.[0-9]+)?$'   THEN custo_unitario::NUMERIC(10,2) END AS custo_unitario,
        CASE WHEN desconto_pct   ~ '^-?[0-9]+(\.[0-9]+)?$'   THEN desconto_pct::NUMERIC(4,2)    END AS desconto_pct,
        CASE WHEN frete          ~ '^-?[0-9]+(\.[0-9]+)?$'   THEN frete::NUMERIC(10,2)          END AS frete,

        CASE ecommerce.chave(metodo_pagamento)
            WHEN 'cartao de credito' THEN 'Cartão de Crédito'
            WHEN 'cartao de debito'  THEN 'Cartão de Débito'
            WHEN 'pix'               THEN 'Pix'
            WHEN 'boleto'            THEN 'Boleto'
            WHEN 'carteira digital'  THEN 'Carteira Digital'
        END AS metodo_pagamento,

        CASE WHEN parcelas ~ '^[0-9]+$' THEN parcelas::INTEGER END AS parcelas,

        CASE ecommerce.chave(status_pedido)
            WHEN 'entregue'    THEN 'Entregue'
            WHEN 'devolvido'   THEN 'Devolvido'
            WHEN 'cancelado'   THEN 'Cancelado'
            WHEN 'em transito' THEN 'Em trânsito'
        END AS status_pedido,

        /* "Sim", "sim", "Não", "nao", "não ", "N" → Sim / Não */
        CASE left(ecommerce.chave(devolvido), 1)
            WHEN 's' THEN 'Sim'
            WHEN 'n' THEN 'Não'
        END AS devolvido,

        CASE WHEN avaliacao_cliente ~ '^[0-9]+(\.[0-9]+)?$' THEN avaliacao_cliente::NUMERIC(3,1) END AS avaliacao_cliente,
        NULLIF(upper(trim(cupom)), '') AS cupom
    FROM ecommerce.raw_pedidos
)
SELECT
    pedido_id, item_id, data_pedido, data_prometida, data_entrega,
    cliente_id, segmento_cliente, cidade,
    /* Estado vazio: usa o estado que a mesma cidade tem nas outras linhas */
    COALESCE(estado, MAX(estado) OVER (PARTITION BY cidade)) AS estado,
    /* Região vazia: usa a região que a mesma cidade tem nas outras linhas */
    COALESCE(regiao, MAX(regiao) OVER (PARTITION BY cidade)) AS regiao,
    canal_venda, canal_aquisicao, categoria, subcategoria, produto,
    quantidade, preco_unitario, custo_unitario, desconto_pct, frete,
    metodo_pagamento, parcelas, status_pedido, devolvido, avaliacao_cliente, cupom
FROM tipado;
