-- =====================================================================
-- RELATÓRIO DE QUALIDADE: problemas encontrados na raw e o que sobrou na final
-- =====================================================================

WITH raw AS (
    SELECT
        COUNT(*)                                                                   AS linhas,
        COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT pedido_id, item_id
                                          FROM ecommerce.raw_pedidos) d)           AS duplicadas,
        COUNT(*) FILTER (WHERE canal_venda      <> ALL (ARRAY['Site','App','Marketplace','Loja Física'])) AS canal_fora_do_padrao,
        COUNT(*) FILTER (WHERE categoria        <> ALL (ARRAY['Eletrônicos','Moda','Casa','Esporte','Beleza'])) AS categoria_fora_do_padrao,
        COUNT(*) FILTER (WHERE metodo_pagamento <> ALL (ARRAY['Cartão de Crédito','Cartão de Débito','Pix','Boleto','Carteira Digital'])) AS pagamento_fora_do_padrao,
        COUNT(*) FILTER (WHERE devolvido        <> ALL (ARRAY['Sim','Não']))       AS devolvido_fora_do_padrao,
        COUNT(*) FILTER (WHERE estado IS NULL OR estado <> upper(estado))          AS estado_vazio_ou_minusculo,
        COUNT(*) FILTER (WHERE regiao IS NULL)                                     AS regiao_vazia,
        COUNT(*) FILTER (WHERE COALESCE(produto, '') = '')                         AS produto_vazio,
        COUNT(*) FILTER (WHERE quantidade::INTEGER <= 0)                           AS quantidade_zero_ou_negativa,
        COUNT(*) FILTER (WHERE frete LIKE '-%')                                    AS frete_negativo
    FROM ecommerce.raw_pedidos
),
final AS (
    SELECT
        COUNT(*)                                                                   AS linhas,
        COUNT(*) - COUNT(DISTINCT (pedido_id, item_id))                            AS duplicadas,
        COUNT(*) FILTER (WHERE canal_venda      IS NULL)                           AS canal_fora_do_padrao,
        COUNT(*) FILTER (WHERE categoria        IS NULL)                           AS categoria_fora_do_padrao,
        COUNT(*) FILTER (WHERE metodo_pagamento IS NULL)                           AS pagamento_fora_do_padrao,
        COUNT(*) FILTER (WHERE devolvido        IS NULL)                           AS devolvido_fora_do_padrao,
        COUNT(*) FILTER (WHERE estado IS NULL OR estado <> upper(estado))          AS estado_vazio_ou_minusculo,
        COUNT(*) FILTER (WHERE regiao IS NULL)                                     AS regiao_vazia,
        COUNT(*) FILTER (WHERE produto = '')                                       AS produto_vazio,
        COUNT(*) FILTER (WHERE quantidade <= 0)                                    AS quantidade_zero_ou_negativa,
        COUNT(*) FILTER (WHERE frete < 0)                                          AS frete_negativo,
        /* Estes só podem ser medidos depois de comparar com o padrão de cada produto */
        COUNT(*) FILTER (WHERE flag_categoria_corrigida)                           AS categoria_errada_no_produto,
        COUNT(*) FILTER (WHERE flag_preco_invalido)                                AS preco_invalido,
        COUNT(*) FILTER (WHERE flag_custo_invalido)                                AS custo_invalido
    FROM ecommerce.final_pedidos
)
SELECT problema, antes, depois
FROM raw, final,
LATERAL (VALUES
    ('Linhas',                                         raw.linhas,                      final.linhas),
    ('Linhas duplicadas (pedido + item)',              raw.duplicadas,                  final.duplicadas),
    ('Canal de venda fora do padrão',                  raw.canal_fora_do_padrao,        final.canal_fora_do_padrao),
    ('Categoria fora do padrão',                       raw.categoria_fora_do_padrao,    final.categoria_fora_do_padrao),
    ('Categoria errada para o produto',                final.categoria_errada_no_produto, 0::BIGINT),
    ('Forma de pagamento fora do padrão',              raw.pagamento_fora_do_padrao,    final.pagamento_fora_do_padrao),
    ('"Devolvido" fora do padrão (sim, nao, N)',       raw.devolvido_fora_do_padrao,    final.devolvido_fora_do_padrao),
    ('Estado vazio ou em minúsculas',                  raw.estado_vazio_ou_minusculo,   final.estado_vazio_ou_minusculo),
    ('Região vazia',                                   raw.regiao_vazia,                final.regiao_vazia),
    ('Produto sem nome',                               raw.produto_vazio,               final.produto_vazio),
    ('Quantidade zero ou negativa',                    raw.quantidade_zero_ou_negativa, final.quantidade_zero_ou_negativa),
    ('Preço ≤ 0 ou fora do padrão do produto',         final.preco_invalido,            0::BIGINT),
    ('Custo ≤ 0 ou fora do padrão do produto',         final.custo_invalido,            0::BIGINT),
    ('Frete negativo',                                 raw.frete_negativo,              final.frete_negativo)
) AS t(problema, antes, depois);

-- Data de entrega: dia e mês invertidos na origem.
-- Compara as duas leituras possíveis da data (entrega − pedido, em dias).
SELECT
    leitura,
    MIN(dias)                                              AS minimo,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY dias)      AS mediana,
    MAX(dias)                                              AS maximo,
    COUNT(*) FILTER (WHERE dias < 0)                       AS entrega_antes_do_pedido
FROM ecommerce.raw_pedidos r,
LATERAL (VALUES
    ('DD/MM (leitura da v1)', to_date(r.data_entrega, 'DD/MM/YYYY') - to_date(r.data_pedido, 'DD/MM/YYYY')),
    ('MM/DD (leitura correta)', to_date(r.data_entrega, 'MM/DD/YYYY') - to_date(r.data_pedido, 'DD/MM/YYYY'))
) AS t(leitura, dias)
WHERE r.data_entrega <> '' AND r.data_pedido <> ''
GROUP BY leitura;

-- Problemas que não dá para corrigir, só sinalizar (ficam nas colunas flag_ ou nulos)
SELECT
    COUNT(*) FILTER (WHERE flag_status_divergente)     AS status_contradiz_devolvido,
    COUNT(*) FILTER (WHERE data_pedido IS NULL)        AS sem_data_do_pedido,
    COUNT(*) FILTER (WHERE status_pedido = 'Entregue'
                       AND data_entrega IS NULL)       AS entregue_sem_data_de_entrega
FROM ecommerce.final_pedidos;
