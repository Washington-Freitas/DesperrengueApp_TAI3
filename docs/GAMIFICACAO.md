# Sistema de Gamificação, Reputação e Economia de Incentivos — Desperrengue

> **Escopo.** Especificação técnico-científica da camada de gamificação do Desperrengue: (i) o que **já está implementado** (conquistas, selos, avaliação cega e ranqueamento Bayesiano); (ii) a **modelagem matemática** do ranking e de seus multiplicadores; (iii) a **análise de *unit economics*** das recompensas financeiras propostas (liga com *take-rate* regressivo, Cofre da Casa, Salva-Vizinho, Escudo do Autônomo), usando **as premissas do [Fluxo de Caixa](./Fluxo%20de%20Caixa.md)**; (iv) riscos jurídicos e o plano de experimentação.
>
> **Reprodutibilidade.** Todos os números das seções 5 e 4.3 saem de uma simulação determinística reproduzível ([`scripts/sim-gamificacao.mjs`](../scripts/sim-gamificacao.mjs)): `node scripts/sim-gamificacao.mjs`.

---

## 1. Sumário executivo

| Camada | Estado | Onde |
| :-- | :-- | :-- |
| Pílulas de contexto (avaliação guiada) | ✅ Implementado | [ADR-0011](adr/0011-avaliacoes-cegas-bayes-e-selos.md) |
| Avaliação bidirecional cega (48 h) | ✅ Implementado | idem |
| Ranqueamento por Média Bayesiana + recência | ✅ Implementado | idem |
| Selos automáticos por pílula (≥ 15) e *Super Profissional* | ✅ Implementado | idem |
| **Conquistas escalonadas** (9 categorias × 10 níveis = 90) | ✅ Implementado | [ADR-0012](adr/0012-conquistas-do-profissional.md) |
| Multiplicador de SLA/*streak* no ranking | 📐 Modelado (seção 4) | Fase 2 |
| Ligas com *take-rate* regressivo | 📐 Analisado — **não** liberar sem teste (seção 5.2) | Fase 3 |
| Cofre da Casa (*cashback*) | 📐 Analisado — exige revisão contábil/jurídica | Fase 3 |
| Salva-Vizinho (indicação R$ 30 + R$ 30) | ⚠️ **Inviável como proposto** com ticket de R$ 180 (seção 5.4) | redesenho |
| Escudo do Autônomo (seguro) | 📐 Depende de cotação com seguradora regulada | Fase 3 |
| Saúde do Lar / Medidor de Diagnóstico | 📐 Modelado (seção 8) | Fase 2 |

**Conclusões principais** (detalhadas adiante):

1. A gamificação **não deve nascer como custo**: ela deve ser financiada pelo **ganho de retenção no *escrow*** (redução do *bypass*). Com ticket de R$ 180 e *take-rate* de 12 %, a contribuição por pedido é de apenas **R$ 17,60**; qualquer recompensa financeira precisa caber nessa margem.
2. **Fase 1 (feita) é de custo marginal zero**: reputação, conquistas e selos são puramente não financeiros e já elevam o custo de sair da plataforma (o profissional perderia a vitrine auditada).
3. A proposta de **R$ 30 + R$ 30 do Salva-Vizinho gera LTV/CAC de 0,70**: o par de bônus custa 3,4 pedidos de contribuição. O teto sustentável é de **≈ R$ 14 no total** (LTV/CAC ≥ 3).
4. A **Liga "Lenda" a 10 %** só se paga se reduzir o *bypass* em **≥ 14,3 p.p.** (de 40 % para 25,7 %). O desconto deve ser **escalonado e condicionado a metas**, não linear.
5. Multiplicadores de ranking devem ser **limitados** (`α ∈ [0,94; 1,06]`), para que SLA nunca supere qualidade comprovada.

---

## 2. Conquistas — especificação implementada

### 2.1 Princípios de design

* **Sóbrias e verificáveis:** nomes factuais ("10 avaliações 5 estrelas"), sem hipérbole. Cada conquista é derivada de **dados reais já auditados pelo *escrow*** (serviço concluído por PIN; avaliações **reveladas**).
* **Escalonamento universal:** limites `1, 10, 25, 50, 100, 500, 1.000, 2.500, 5.000, 10.000` em **todas** as categorias; 2 níveis por metal (**Bronze → Prata → Ouro → Platina → Diamante**).
* **Vitrine dupla:** o profissional vê **todas** com progresso ("Minhas conquistas"); o cliente vê as **desbloqueadas** no perfil público (melhor medalha por categoria + "Ver todas").
* **Sem trapaça possível:** nenhuma escrita pelo app (RLS só de leitura); desbloqueio por *trigger* e função `SECURITY DEFINER`.

### 2.2 Categorias e regra de contagem

| Código | Categoria | O que conta | Fonte |
| :-- | :-- | :-- | :-- |
| `services` | Serviços concluídos | Pedidos `completed` do profissional | `jobs` |
| `five_star` | Avaliações 5 estrelas | Avaliações **reveladas** de clientes com nota 5 | `reviews` |
| `punctual` | Pontualidade | Pílula "Super pontual" | `reviews.tags` |
| `tidy` | Organização | Pílula "Limpou tudo depois" | idem |
| `fair_price` | Preço justo | Pílula "Preço honesto" | idem |
| `skilled` | Qualidade do trabalho | Pílula "Mestre no que faz" | idem |
| `courteous` | Cortesia | Pílula "Educado e confiável" | idem |
| `emergency` | Emergências | Pedidos de emergência concluídos | `jobs.urgency` |
| `repeat_clients` | Clientes recorrentes | Clientes distintos com ≥ 2 serviços concluídos | `jobs` |

Total: 9 × 10 = **90 conquistas**. O 1º nível é nomeado no singular ("Primeira avaliação 5 estrelas"); os demais por quantidade ("25 avaliações 5 estrelas").

### 2.3 Dados e gatilhos

* Tabela `provider_achievements (provider_id, code, unlocked_at)`, `code = <categoria>_<limite>`.
* `AFTER UPDATE OF status ON jobs` (para `completed`) e `reveal_job_reviews()` chamam `refresh_provider_achievements()`, **idempotente**: insere os níveis atingidos (`ON CONFLICT DO NOTHING`) e notifica **uma vez** por nível.
* Backfill do histórico sem notificação.
* Teste: [`supabase/tests/achievements_smoke.sql`](../supabase/tests/achievements_smoke.sql) (22 asserções).

### 2.4 Experiência

* **Serviço finalizado:** cartões "Conquista desbloqueada" com a medalha (tela de sucesso do profissional).
* **Minhas conquistas:** anel de progresso global, uma linha de 10 medalhas por categoria, barra rumo ao próximo nível e *bottom sheet* de detalhe.
* **Perfil público (cliente):** seção "Conquistas" + tela completa.
* **Medalhas vetoriais** (sem imagens externas): anel metálico em degradê por metal + ícone da categoria; bloqueadas em cinza com cadeado. Escolha deliberada: sem dependência de licença de terceiros, nítidas em qualquer densidade de tela e consistentes com o *Design System* ([Template](./Template.md)).

---

## 3. Reputação: o que já está no banco

`WR = v/(v+m)·R + m/(v+m)·C`, com `v` = avaliações reveladas, `m = 5`, `R` = média com peso de recência (10 últimas valem 1,5×) e `C` = média global (4,5 sem dados). A busca ordena por `WR`; o perfil exibe a **média simples** (honestidade para o usuário). Detalhes e justificativas: [ADR-0011](adr/0011-avaliacoes-cegas-bayes-e-selos.md).

---

## 4. Modelagem matemática proposta

### 4.1 Escolha de `m` por Bayes empírico

`m` é a razão entre a variância das notas **dentro** de um profissional (`σ_w²`) e a variância **entre** profissionais (`τ²`):

$$ m = \frac{\sigma_w^2}{\tau^2} $$

Com valores típicos de mercado (`σ_w² ≈ 0,6`; `τ² ≈ 0,15`) ⇒ **`m = 4`**; com `σ_w²=0,5`, `τ²=0,1` ⇒ `m = 5`. O valor em produção (`m = 5`) está, portanto, **na faixa teórica**. Recalibrar mensalmente com os dados reais (estimadores de momentos) quando houver ≥ 200 avaliações.

**Índice de Confiança** (exibível no perfil): `I = v/(v+m)`. Com `m=5`: v=1 → 16,7 %; v=10 → 66,7 %; v=50 → 90,9 %; v=180 → 97,3 %. Para 90 % são necessárias **45** avaliações; para 95 %, **95**.

**Comparação do exemplo clássico** (`m=5`, `C=4,5`): profissional A (1 serviço, 5,0) → **4,583**; B (85 serviços, 4,88) → **4,859**; C (200 serviços, 4,90) → **4,890**. A ordem correta (C > B > A) emerge sem regra especial.

### 4.2 Hierarquia por categoria

Usar `C` global penaliza categorias com notas estruturalmente mais altas/baixas. *Shrinkage* hierárquico:

$$ C_{cat} = \frac{n_{cat}\,\bar r_{cat} + k\,\bar r_{global}}{n_{cat} + k},\qquad k \approx 30 $$

Categorias novas herdam a média global; categorias densas usam a própria.

### 4.3 Multiplicador de SLA e de *streak* — **limitado por construção**

Rank final proposto:

$$ S = q(WR)\cdot \alpha,\quad q(x)=\frac{x-1}{4},\quad \alpha = \operatorname{clip}\!\Big(1+\beta\,(\varphi_{SLA}-\tfrac12)+\gamma\,\mathbb 1_{streak},\;1-\tfrac\beta2,\;1+\tfrac\beta2\Big) $$

* `φ_SLA = exp(−t_resposta/τ)` ∈ (0,1] (τ = 3 min em emergência; 30 min em orçamento comum).
* `1_streak` = *boost* de 7 dias após marcos de pontualidade; `γ` pequeno (0,02).
* **Teorema da dominância da qualidade:** como `α ∈ [1−β/2, 1+β/2]`, um profissional B só ultrapassa A se `q(WR_B)/q(WR_A) ≥ (1−β/2)/(1+β/2)`. Para **A com WR = 4,80**:

| β | Faixa de α | Razão máx. de vantagem | WR mínimo de B para ultrapassar A |
| :-: | :-: | :-: | :-: |
| 0,08 | [0,96; 1,04] | 1,083 | **4,508** |
| **0,12** | **[0,94; 1,06]** | **1,128** | **4,370** |
| 0,20 | [0,90; 1,10] | 1,222 | 4,109 |

Recomendação: **β = 0,12**. Um profissional com nota 4,37 só passa um de 4,80 se for **o mais rápido possível e o outro o mais lento**; rapidez compra posição, **não substitui qualidade**.

### 4.4 Recência contínua (evolução da regra 1,5×)

Substituir o degrau (10 últimas × 1,5) por decaimento exponencial com meia-vida `h` de 180 dias: `w_i = 2^(−Δt_i/h)`; `R = Σ w_i r_i / Σ w_i`. Mantém continuidade (sem "efeito borda") e é monotônica.

### 4.5 Resistência a manipulação

* Só avaliação de **pedido pago em *escrow*** (já vigente); preço mínimo para contar no ranking (ex.: R$ 40).
* **Peso por par cliente–profissional:** a *k*-ésima avaliação do mesmo cliente pesa `1/√k` (reduz *self-dealing*).
* **Detecção de anel** (grafo de avaliações recíprocas entre poucas contas) — fila de revisão manual.
* Avaliação cega (vigente) elimina retaliação.

---

## 5. *Unit economics* das recompensas financeiras

### 5.1 Premissas (idênticas ao [Fluxo de Caixa](./Fluxo%20de%20Caixa.md))

| Parâmetro | Valor |
| :-- | :-: |
| Ticket médio | R$ 180,00 |
| *Take-rate* | 12 % (R$ 21,60) |
| Gateway/split | 1,5 % do GMV (R$ 2,70) |
| Impostos (Simples, Anexo III) | 6 % da **receita** (R$ 1,30) |
| **Contribuição por pedido** `c₀` | **R$ 17,60** |
| GMV Ano 1 / margem de contribuição Ano 1 | R$ 260.100 / R$ 29.295,54 |

(`c(r) = 180·r·(1−0,06) − 180·0,015`; o `c₀` acima reproduz exatamente a planilha: R$ 264,06 ÷ 15 pedidos no Mês 1.)

### 5.2 Ligas com *take-rate* regressivo

| Liga | *Take-rate* | Contribuição/pedido | Custo do desconto | Queda da contribuição |
| :-- | :-: | :-: | :-: | :-: |
| Oficial | 12,0 % | R$ 17,60 | — | — |
| Especialista | 11,5 % | R$ 16,76 | R$ 0,85 | 4,8 % |
| Mestre | 11,0 % | R$ 15,91 | R$ 1,69 | 9,6 % |
| Lenda | 10,0 % | R$ 14,22 | R$ 3,38 | **19,2 %** |

**Condição de neutralidade.** Seja `b` a fração de pedidos recorrentes que "fogem" da plataforma (*bypass*). O desconto só se paga se:

$$ b_{liga} \le 1-\frac{(1-b_0)\,c_0}{c_{liga}} $$

*Redução de *bypass* exigida (p.p.) para empatar:*

| Liga | b₀ = 20 % | b₀ = 30 % | b₀ = 40 % | b₀ = 50 % |
| :-- | :-: | :-: | :-: | :-: |
| Especialista | 4,0 | 3,5 | 3,0 | 2,5 |
| Mestre | 8,5 | 7,4 | 6,4 | 5,3 |
| **Lenda** | **19,0** | **16,7** | **14,3** | **11,9** |

**Impacto no Ano 1** (mix de ligas × GMV R$ 260.100):

| Mix (Oficial/Esp./Mestre/Lenda) | *Take* efetivo | Contribuição perdida | % da margem do Ano 1 | GMV incremental p/ empatar |
| :-- | :-: | :-: | :-: | :-: |
| Inicial 85/10/4/1 | 11,9 % | R$ 268,94 | 0,9 % | R$ 2.779 (1,1 % do GMV) |
| Maduro 50/25/17/8 | 11,5 % | R$ 1.112,45 | 3,8 % | R$ 11.895 (4,6 % do GMV) |

**Leitura:** com mix realista o custo é **suportável (≤ 4 % da margem)**, desde que a Liga reduza *bypass* e crie GMV incremental ≥ 4,6 %. **Recomendação:** começar com **2 ligas** (Oficial 12 % / Mestre 11 %), critérios **objetivos e auditáveis** (nota Bayesiana, taxa de conclusão sem disputa, volume em 90 dias), e **guarda-corpo orçamentário**: gasto total de recompensas ≤ **10 % da margem de contribuição** do mês (se estourar, os limiares de promoção sobem).

### 5.3 Cofre da Casa (*cashback* na conta do cliente)

Custo por pedido = `k · ticket · ρ`, onde `k` é o percentual devolvido e `ρ` a taxa de resgate (*breakage* = `1−ρ`):

| k | ρ = 50 % | ρ = 65 % | ρ = 80 % | ρ = 100 % |
| :-: | :-: | :-: | :-: | :-: |
| 1 % | 5,1 % da contrib. | 6,6 % | 8,2 % | 10,2 % |
| **2 %** | 10,2 % | **13,3 %** | 16,4 % | 20,4 % |
| 3 % | 15,3 % | 19,9 % | 24,5 % | 30,7 % |
| 5 % | 25,6 % | 33,2 % | 40,9 % | **51,1 %** |

**Leitura:** `k = 2 %` custa de 10 % a 20 % da contribuição — **razoável** se o saldo só puder ser usado em pedidos **pagos pelo app** (efeito anti-*bypass*: o cliente perde o saldo se sair). `k = 5 %` consome **metade** da margem: descartado. **Recomendação:** `k = 1–2 %`, validade de 180 dias (reduz passivo), teto de saldo (R$ 100) e registro em ***ledger* contábil de partida dobrada** (não em saldo mutável).

### 5.4 Salva-Vizinho (R$ 30 + R$ 30)

Com 2,4 pedidos/cliente/ano (premissa) o **LTV de contribuição do ano 1** é R$ 42,25.

| Bônus total (indicado + indicador) | LTV/CAC | Pedidos para *payback* |
| :-: | :-: | :-: |
| **R$ 60 (proposta)** | **0,70** | **3,4** |
| R$ 30 | 1,41 | 1,7 |
| R$ 20 | 2,11 | 1,1 |
| R$ 15 | 2,82 | 0,9 |
| R$ 10 | 4,22 | 0,6 |

**Conclusão:** a proposta original **destrói valor** no ticket de R$ 180. O **teto para LTV/CAC = 3 é R$ 14,08**. Redesenho recomendado: **R$ 7 + R$ 7**, ou bônus **proporcional ao ticket** (ex.: 4 % do 1º pedido do indicado, limitado a R$ 15), pago **somente após conclusão por PIN** (já previsto).

### 5.5 Escudo do Autônomo (seguro e benefícios)

Custo do prêmio ÷ contribuição mensal do profissional:

| Prêmio/mês | 4 pedidos | 8 pedidos | 12 pedidos |
| :-: | :-: | :-: | :-: |
| R$ 8 | 11,4 % | 5,7 % | 3,8 % |
| R$ 12 | 17,0 % | 8,5 % | 5,7 % |
| R$ 20 | 28,4 % | 14,2 % | 9,5 % |

Para manter o prêmio ≤ 15 % da contribuição, o profissional precisa de **3,0 pedidos/mês (R$ 8)**, **4,5 (R$ 12)** ou **7,6 (R$ 20)**. Logo, o Escudo funciona como **meta de volume mensal** — exatamente o comportamento desejado — mas **os prêmios são hipóteses a cotar** com seguradora autorizada pela SUSEP.

---

## 6. Anti-*bypass*: modelo de ameaça e métricas

**Ameaça.** Cliente e profissional combinam o 2º serviço por fora para evitar a comissão (12 %).

**Defesas (em ordem de custo):** (1) **valor percebido** do *escrow* (garantia, PIN, fotos, seguro); (2) **vitrine e reputação auditada** que só existem dentro do app (conquistas, selos, ranking); (3) **recompensas atreladas ao canal** (Cofre, Liga, Escudo); (4) fricção contra troca de contatos no chat (aviso educativo, não bloqueio punitivo).

**Medição sem violar privacidade (LGPD):** proxies agregados — taxa de recompra **no app** por par cliente–profissional; queda de pedidos de pares que tinham histórico; mensagens com padrão de telefone **detectado no dispositivo** (sem armazenar conteúdo). Não monitorar conteúdo de conversas no servidor sem base legal e aviso explícito.

**Meta de sucesso:** reduzir `b` em **≥ 5 p.p.** em 90 dias no grupo tratado (teste A/B por bairro) antes de ativar qualquer recompensa financeira para todos.

---

## 7. Riscos jurídicos, fiscais e regulatórios (a validar com profissionais habilitados)

| Tema | Risco | Mitigação |
| :-- | :-- | :-- |
| **Vínculo trabalhista** | Metas, rebaixamento de liga e punições por desempenho podem sugerir **subordinação** | Critérios objetivos e públicos; sem metas obrigatórias de jornada; benefícios opcionais; parecer de advogado trabalhista |
| **Seguro** | Oferecer seguro exige seguradora autorizada (SUSEP) | Contratar apólice coletiva; a plataforma só **estipula** |
| **Cashback/bônus** | Tratamento tributário (desconto condicional × bonificação × despesa de marketing) | Consulta ao contador; ledger rastreável |
| **LGPD** | Perfilamento (Saúde do Lar, scores) | Base legal (execução de contrato/legítimo interesse), transparência, opt-out de personalização |
| **CDC** | Promoções, validade de saldo e publicidade | Regulamento claro, validade ≥ 180 dias, comunicação destacada |
| **Concorrência/ranking** | Transparência do algoritmo de busca | Explicar fatores no app (já há texto em "Minhas avaliações") |

---

## 8. Camadas ainda não implementadas (modelagem)

### 8.1 Saúde do Lar

Para cada pilar `p` (Hidráulica, Elétrica, Climatização, Estrutura/Limpeza): `H_p(t) = 100·exp(−Δt/τ_p)`, `Δt` = dias desde o último serviço do pilar. Sugestão: `τ` = 540 d (hidráulica), 720 d (elétrica), 240 d (climatização), 360 d (estrutura/limpeza). Score geral = média ponderada (0,25 cada). **Restauração:** concluir serviço do pilar reseta `Δt = 0`. Disparar lembrete quando `H_p < 50`.

### 8.2 Medidor de Diagnóstico

Pontuação do chamado: texto (≥ 40 caracteres) = 1; ≥ 2 fotos nítidas = 2; vídeo/3 respostas = 3 (Bronze/Prata/Ouro). Benefício **não financeiro**: destaque "Pedido pronto para execução" e prioridade de notificação. Já existe a base (até 4 fotos no pedido).

### 8.3 Portfólio Vivo "Antes & Depois"

Reaproveita `job_evidence` (4 fotos obrigatórias) + foto de avaliação do cliente. Item público só com **consentimento do cliente** e anonimização do endereço (princípio de minimização — [ADR-0007](adr/0007-privacidade-por-minimizacao-de-dados.md)).

### 8.4 Modelo de dados sugerido (com ajustes)

| Proposta original | Ajuste recomendado | Motivo |
| :-- | :-- | :-- |
| `gamification_profiles.wallet_cashback_balance` | **`wallet_ledger`** (`id, user_id, amount, kind, ref_job, created_at`; saldo = soma) | Auditoria, idempotência e conciliação contábil |
| `xp_points`, `current_tier` mutáveis | Derivar de eventos (`gamification_events`) e materializar | Reprocessável; evita *drift* |
| `home_health_metrics.current_health_score` | Calcular na leitura (`H_p(t)`); armazenar só `last_service_date` | O score é função do tempo |
| `verified_portfolio_items` | Já coberto por `job_evidence` + `reviews.photo_paths` | Evita duplicar mídia |

Todas as escritas por RPC `SECURITY DEFINER` + RLS de leitura (padrão do [ADR-0003](adr/0003-regras-de-negocio-no-banco-via-rpc.md)).

---

## 9. Plano de implantação e experimentos

| Fase | Entrega | Custo variável | Critério de avanço |
| :-: | :-- | :-: | :-- |
| **1 (feita)** | Pílulas, avaliação cega, Bayes, selos, **conquistas** | R$ 0 | Taxa de avaliação completa ≥ 60 % |
| **2** | Multiplicador SLA/*streak* (β = 0,12), Índice de Confiança, Medidor de Diagnóstico, Saúde do Lar | R$ 0 | Redução do *time-to-match* ≥ 15 % sem queda de nota média |
| **3a** | Liga de 2 degraus (12 %/11 %) em **2 bairros** (A/B) | ≤ 10 % da margem | `b` cai ≥ 5 p.p.; contribuição por profissional ≥ controle |
| **3b** | Cofre da Casa (k = 1–2 %), Salva-Vizinho redesenhado | ≤ 10 % da margem | LTV/CAC ≥ 3; recompra no app +10 % |
| **3c** | Escudo (seguro) | prêmio ≤ 15 % da contribuição | Cotação aprovada + parecer jurídico |

**Métricas-guia:** *Time-to-Match*, taxa de conclusão sem disputa, NPS pós-serviço, recompra no app por par, contribuição por pedido, `b` estimado, custo de recompensas ÷ margem.

**Critério de parada:** se, em 60 dias, o custo das recompensas exceder 10 % da margem **sem** redução mensurável de `b`, reverter a fase.

---

## 10. Limitações e premissas a validar

* Os valores de `b₀`, ρ, pedidos/cliente/ano (2,4), prêmios de seguro e variâncias (`σ_w²`, `τ²`) são **premissas** — substituir por dados reais (os do MVP serão escassos).
* As tabelas do item 5 dependem do ticket médio de R$ 180 e do *take-rate* de 12 %; reexecutar `scripts/sim-gamificacao.mjs` ao alterar o plano de negócios.
* A seção 7 **não substitui** parecer jurídico/contábil.

*Referências internas:* [Fluxo de Caixa](./Fluxo%20de%20Caixa.md) · [Balanced Scorecard](./Balanced%20Scorecard%20(BSC).md) · [ROADMAP](./ROADMAP.md) · [ADR-0011](adr/0011-avaliacoes-cegas-bayes-e-selos.md) · [ADR-0012](adr/0012-conquistas-do-profissional.md).
