-- =====================================================================
-- CAMADA RAW: dados exatamente como vieram do CSV
-- Todas as colunas são TEXT para que nenhuma linha seja rejeitada na carga.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS ecommerce;

DROP TABLE IF EXISTS ecommerce.raw_pedidos CASCADE;

CREATE TABLE ecommerce.raw_pedidos (
    pedido_id         TEXT,
    item_id           TEXT,
    data_pedido       TEXT,
    data_prometida    TEXT,
    data_entrega      TEXT,
    cliente_id        TEXT,
    segmento_cliente  TEXT,
    cidade            TEXT,
    estado            TEXT,
    regiao            TEXT,
    canal_venda       TEXT,
    canal_aquisicao   TEXT,
    categoria         TEXT,
    subcategoria      TEXT,
    produto           TEXT,
    quantidade        TEXT,
    preco_unitario    TEXT,
    custo_unitario    TEXT,
    desconto_pct      TEXT,
    frete             TEXT,
    metodo_pagamento  TEXT,
    parcelas          TEXT,
    status_pedido     TEXT,
    devolvido         TEXT,
    avaliacao_cliente TEXT,
    cupom             TEXT
);

-- O arquivo é montado em /data pelo docker-compose.
-- Fora do Docker, use no psql: \copy ecommerce.raw_pedidos FROM 'data/dados-ecommerce.csv' CSV HEADER
COPY ecommerce.raw_pedidos
FROM '/data/dados-ecommerce.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
