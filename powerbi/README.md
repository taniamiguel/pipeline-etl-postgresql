# Power BI: painel dos 5 indicadores

O painel do curso lia a tabela `schema01.dados_ecommerce_final` do banco `dbAlura` (a versão com os erros). As medidas DAX originais e as corrigidas estão em [`medidas.dax`](medidas.dax), cada uma com o motivo da correção.

## O que mudou nas medidas

| Medida | Problema na versão original | Correção |
|---|---|---|
| Receita Líquida | Somava pedidos cancelados e devolvidos | Só pedidos entregues |
| Margem Bruta % | Margem sem desconto dividida por receita com desconto | Margem e receita na mesma base |
| Taxa de Devolução | Contava só o texto exato `"Sim"` e incluía cancelados no total | Coluna padronizada no SQL e cancelados fora do total |
| Atraso Médio | Ignorava entregas adiantadas, o que puxava a média para cima | Usa todas as entregas com data, adiantadas como valor negativo |
| Ticket Médio por Cliente | Fórmula certa, mas com a receita errada | Herda a Receita Líquida corrigida |

## Como apontar o painel para o banco corrigido

1. Suba o banco: `docker compose up -d` na pasta do projeto.
2. No Power BI Desktop: **Página Inicial → Transformar dados → Configurações da fonte de dados → Alterar fonte**.
   - Servidor: `localhost:5435`
   - Banco de dados: `ecommerce`
   - Usuário e senha: `analista`
3. No Power Query, troque a navegação da tabela para o esquema `ecommerce` e a tabela `final_pedidos`. Mantenha o nome da consulta como `fVendas`.
4. Substitua as medidas pelas versões corrigidas de `medidas.dax`.
5. Clique em **Atualizar**.
