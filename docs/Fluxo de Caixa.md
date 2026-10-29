# Planilha e Projeção de Fluxo de Caixa (12 Meses) — Desperrengue

> **Escopo:** Este documento apresenta o planejamento financeiro e a **Planilha de Fluxo de Caixa projetada para 12 meses** da startup **Desperrengue**, mantendo total coerência com as premissas definidas em [`docs/Planos de Negocio e Tributação.md`](./Planos%20de%20Negocio%20e%20Tributação.md), com a regra de comissão implementada no banco de dados (`payments.fee_amount = 12%`) e com os marcos do [`ROADMAP.md`](ROADMAP.md).
> **Arquivo de Planilha:** A planilha completa em formato CSV (separada por ponto e vírgula, padrão PT-BR para Microsoft Excel e Google Sheets) está disponível em [`docs/planilhas/fluxo_de_caixa_12m.csv`](./planilhas/fluxo_de_caixa_12m.csv).

---

## 1. Premissas Financeiras e Tributárias Adotadas

Para evitar qualquer contradição com o plano de negócios e com a implementação técnica atual, a projeção adota rigorosamente os seguintes parâmetros:

1. **Ticket Médio por Serviço Concluído:** **R$ 180,00** (valor de referência médio entre diárias de limpeza/faxina e reparos elétricos/hidráulicos, alinhado aos protótipos `R$ 150,00` a `R$ 180,00`).
2. **Comissão da Plataforma (*Take Rate*):** **12% sobre o GMV** (Volume Bruto Transacionado), exatamente como codificado na coluna `payments.fee_amount` e nas RPCs `pay_job_mock` / `complete_job_with_pin` (R$ 21,60 de receita bruta para a plataforma a cada serviço de R$ 180,00, sendo R$ 158,40 repassados ao profissional via *split*).
3. **Receita Adicional de *Cross-Sell* (Garantia/Seguro Contra Danos):** A partir do **Mês 7** (início da fase de tração pós-MVP), projeta-se a ativação da taxa opcional de proteção residencial (validada por **92,9%** dos clientes na pesquisa de mercado), gerando uma receita líquida média adicional de **R$ 12,00** em 30% dos pedidos concluídos.
4. **Enquadramento Tributário (Simples Nacional — CNAE `7490-1/04`):** Conforme especificado em [`Planos de Negocio e Tributação.md`](./Planos%20de%20Negocio%20e%20Tributação.md), a tributação (DAS: ISS, IRPJ, CSLL, PIS/COFINS) incide **apenas sobre a receita da plataforma** (*Take Rate* + *Cross-Sell*), e não sobre o repasse do profissional, com alíquota inicial de **6,0% (Anexo III)**.
5. **Custos Variáveis de Transação (*Gateway Split* Pix/Cartão):** Na transição do *mock* acadêmico para operação real com *split* de pagamento, considera-se uma taxa média ponderada (Pix + Cartão) de **1,5% sobre o GMV** absorvida na operação financeira.
6. **Estrutura de Custos Fixos (Evolução Cenário Lean $\rightarrow$ Tração Inicial):**
   * **Investimento Inicial (Mês 0 / Setup):** **R$ 2.500,00** de capital inicial dos sócios para cobrir taxas de publicação nas lojas (**Google Play Console** US$ 25 $\approx$ R$ 140 taxa única; **Apple Developer Program** US$ 99/ano $\approx$ R$ 550), registro do domínio `desperrengue.tech` e formalização inicial/reserva de caixa.
   * **Meses 1 a 6 (Cenário Lean / Validação Hiperlocal):** Equipe em regime *Sweat Equity* (sem retirada de pró-labore), infraestrutura em nuvem **Supabase Pro** (~US$ 25/mês $\approx$ **R$ 140,00/mês**), contabilidade digital MEI/Simples (**R$ 160,00/mês**) e verba de marketing hiperlocal em condomínios/Google Ads (**R$ 300,00/mês** nos meses 1–3, subindo para **R$ 500,00/mês** nos meses 4–6). Custo fixo mensal entre **R$ 600,00 e R$ 800,00**.
   * **Meses 7 a 12 (Cenário de Tração Regional):** Expansão para bairros adjacentes com aumento gradual do investimento em tráfego pago (**R$ 1.000,00 a R$ 1.800,00/mês**), ferramentas de verificação KYC / suporte (**R$ 350,00/mês**) e início de ajuda de custo operacional / pró-labore enxuto (**R$ 1.500,00/mês**).

---

## 2. Demonstrativo de Fluxo de Caixa Projetado — Ano 1 (Mês 1 ao Mês 12)

*(Valores expressos em Reais — R$)*

| Rubrica / Indicador | Mês 1 | Mês 2 | Mês 3 | Mês 4 | Mês 5 | Mês 6 | Mês 7 | Mês 8 | Mês 9 | Mês 10 | Mês 11 | Mês 12 | **TOTAL ANO 1** |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Nº de Serviços Concluídos** | 15 | 25 | 40 | 55 | 75 | 95 | 120 | 150 | 180 | 210 | 230 | 250 | **1.445** |
| **GMV (Volume Transacionado)** | 2.700,00 | 4.500,00 | 7.200,00 | 9.900,00 | 13.500,00 | 17.100,00 | 21.600,00 | 27.000,00 | 32.400,00 | 37.800,00 | 41.400,00 | 45.000,00 | **260.100,00** |
| Repasse aos Profissionais (88% GMV) | (2.376,00) | (3.960,00) | (6.336,00) | (8.712,00) | (11.880,00) | (15.048,00) | (19.008,00) | (23.760,00) | (28.512,00) | (33.264,00) | (36.432,00) | (39.600,00) | **(228.888,00)** |
| **1. RECEITA BRUTA DA PLATAFORMA** | **324,00** | **540,00** | **864,00** | **1.188,00** | **1.620,00** | **2.052,00** | **3.024,00** | **3.780,00** | **4.536,00** | **5.292,00** | **5.796,00** | **6.300,00** | **35.316,00** |
| (+) Comissão *Take Rate* (12% GMV) | 324,00 | 540,00 | 864,00 | 1.188,00 | 1.620,00 | 2.052,00 | 2.592,00 | 3.240,00 | 3.888,00 | 4.536,00 | 4.968,00 | 5.400,00 | 31.212,00 |
| (+) *Cross-Sell* Garantia/Seguro | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 432,00 | 540,00 | 648,00 | 756,00 | 828,00 | 900,00 | 4.104,00 |
| **2. DEDUÇÕES E CUSTOS VARIÁVEIS** | **(59,94)** | **(99,90)** | **(159,84)** | **(219,78)** | **(299,70)** | **(379,62)** | **(505,44)** | **(631,80)** | **(758,16)** | **(884,52)** | **(968,76)** | **(1.053,00)** | **(6.020,46)** |
| (-) Impostos Simples Nacional (6% s/ Rec.) | (19,44) | (32,40) | (51,84) | (71,28) | (97,20) | (123,12) | (181,44) | (226,80) | (272,16) | (317,52) | (347,76) | (378,00) | (2.118,96) |
| (-) Taxa de Gateway e Split (1,5% GMV) | (40,50) | (67,50) | (108,00) | (148,50) | (202,50) | (256,50) | (324,00) | (405,00) | (486,00) | (567,00) | (621,00) | (675,00) | (3.901,50) |
| **3. MARGEM DE CONTRIBUIÇÃO (1 - 2)** | **264,06** | **440,10** | **704,16** | **968,22** | **1.320,30** | **1.672,38** | **2.518,56** | **3.148,20** | **3.777,84** | **4.407,48** | **4.827,24** | **5.247,00** | **29.295,54** |
| **4. DESPESAS E CUSTOS FIXOS** | **(1.290,00)** | **(600,00)** | **(600,00)** | **(800,00)** | **(800,00)** | **(800,00)** | **(3.150,00)** | **(3.150,00)** | **(3.450,00)** | **(3.650,00)** | **(3.950,00)** | **(3.950,00)** | **(26.190,00)** |
| (-) Nuvem Supabase Pro + Domínio/E-mail | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (140,00) | (1.680,00) |
| (-) Taxas Lojas (Google Play + Apple Dev) | (690,00) | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | (690,00) |
| (-) Marketing Hiperlocal (Ads / Condomínios) | (300,00) | (300,00) | (300,00) | (500,00) | (500,00) | (500,00) | (1.000,00) | (1.000,00) | (1.300,00) | (1.500,00) | (1.800,00) | (1.800,00) | (10.800,00) |
| (-) Contabilidade e Taxas Administrativas | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (160,00) | (1.920,00) |
| (-) Ferramentas de KYC e Suporte | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | (350,00) | (350,00) | (350,00) | (350,00) | (350,00) | (350,00) | (2.100,00) |
| (-) Ajuda de Custo Operacional / Equipe | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 | (1.500,00) | (1.500,00) | (1.500,00) | (1.500,00) | (1.500,00) | (1.500,00) | (9.000,00) |
| **5. FLUXO DE CAIXA LÍQUIDO MENSAL** | **(1.025,94)** | **(159,90)** | **104,16** | **168,22** | **520,30** | **872,38** | **(631,44)** | **(1,80)** | **327,84** | **757,48** | **877,24** | **1.297,00** | **3.105,54** |
| **6. SALDO DE CAIXA ACUMULADO** *(c/ Aporte Inicial R$ 2.500)* | **1.474,06** | **1.314,16** | **1.418,32** | **1.586,54** | **2.106,84** | **2.979,22** | **2.347,78** | **2.345,98** | **2.673,82** | **3.431,30** | **4.308,54** | **5.605,54** | **5.605,54** |

---

## 3. Análise de Indicadores de Viabilidade Econômica

1. **Aporte Inicial Necessário (*Seed Capital* Próprio):** Com apenas **R$ 2.500,00** de capital inicial, o saldo de caixa acumulado **nunca fica negativo** ao longo dos 12 meses (o ponto mínimo de caixa ocorre no Mês 2 com **R$ 1.314,16** em conta, garantindo folga financeira ou *runway* seguro).
2. **Ponto de Equilíbrio Operacional (*Break-Even Point*):**
   * **Na Fase Lean (Meses 1 a 6):** O *Break-Even* é atingido já no **Mês 3** (com apenas **35 a 40 serviços concluídos/mês**, gerando R$ 104,16 de caixa líquido positivo).
   * **Na Fase de Tração com Custos Expandidos (Meses 7 a 12):** Mesmo após triplicar a verba de marketing, contratar ferramentas de KYC e iniciar remuneração operacional no Mês 7, a operação volta ao azul no **Mês 8/9** (~150 a 180 serviços/mês) e encerra o Mês 12 gerando **R$ 1.297,00/mês de geração de caixa livre**.
3. **Payback (Retorno do Capital Inicial):** O capital inicial de R$ 2.500,00 é integralmente recuperado no **Mês 6** (quando o caixa acumulado atinge R$ 2.979,22) e encerra o Ano 1 com **R$ 5.605,54** em caixa (**ROI de +124,2%** no primeiro ano).
4. **Eficiência Tributária do Split:** Graças ao modelo de intermediação no Simples Nacional (CNAE `7490-1/04`), sobre um GMV anual de **R$ 260.100,00**, a plataforma recolhe apenas **R$ 2.118,96** em tributos (6% sobre a receita própria de R$ 35.316,00), evitando a bitributação sobre os R$ 228.888,00 que pertencem aos trabalhadores autônomos.
