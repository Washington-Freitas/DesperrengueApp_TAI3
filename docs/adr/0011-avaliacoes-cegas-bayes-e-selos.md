# ADR-0011 — Avaliações cegas, ranqueamento por Média Bayesiana e selos automáticos

* **Status:** Aceito
* **Data:** 2026-10-23
* **Decisores:** Desenvolvedor
* **Tags:** reputação, produto, banco de dados, UX

## Contexto

O primeiro modelo de avaliação era "estrelas + comentário": a nota era agregada **incrementalmente** no envio (`rating_avg`), a busca ordenava pela média simples e as avaliações eram visíveis na hora. Problemas: (i) baixa conversão (o usuário evita digitar); (ii) `ORDER BY rating DESC` faz **1 serviço nota 5,0 vencer 85 serviços nota 4,88** e é fácil de fraudar; (iii) **avaliações por vingança** (quem avalia depois vê a nota recebida); (iv) cliente insatisfeito sem canal antes de publicar uma crítica.

## Decisão

1. **Pílulas de contexto** (*quick tags*) que mudam com a nota: 1–3 ⭐ → "O que deu errado?"; 4–5 ⭐ → "O que mais te impressionou?" (`ReviewTags`, puro e testado). O profissional avalia o cliente com pílulas de segurança/respeito.
2. **Avaliação bidirecional cega:** `reviews.revealed_at` só é preenchido quando **as duas partes avaliaram** ou **48 h após a primeira avaliação** (`reveal_job_reviews`, `reveal_due_reviews` por `pg_cron` a cada 10 min). Antes disso, a RLS só deixa o **autor** ler a própria avaliação; agregados e *views* públicas só consideram avaliações reveladas.
3. **Ranqueamento por Média Bayesiana** calculado no banco (view `provider_public_profiles.rank_score`):
   $$WR=\frac{v}{v+m}R+\frac{m}{v+m}C$$
   `v` = avaliações reveladas; `m` = 5 (`ranking_min_reviews()`); `R` = média com **peso de recência** (as 10 últimas valem 1,5×, armazenada em `rating_recent_avg`); `C` = média de toda a plataforma (`platform_avg_rating()`, 4,5 sem dados). O app exibe a **média simples** (honesta) e **ordena** por `rank_score`.
4. **Selos automáticos** (`provider_profiles.badges`, só pelo sistema): ≥ 15 marcações da mesma pílula positiva → selo correspondente; **Super Profissional** = 20 últimas avaliações nota 5. Notificação ao conquistar.
5. **Prova visual:** até 3 fotos do serviço por avaliação (`photo_paths`, pasta do próprio usuário validada na RPC), exibidas como "Verificado" e na aba "Fotos de clientes".
6. **Direito de resposta:** `reply_to_review` — só o avaliado, só após revelada, **uma vez**, 3–500 caracteres.
7. **Trava de retenção de crise:** nota 1–2 + "Problema não resolvido" abre o painel "Garantia / Suporte / Enviar mesmo assim" antes de publicar (UI; reaproveita o fluxo de chamados).
8. **Reputação do cliente:** `client_reputation(p_client)` devolve média e quantidade **só** a profissionais com relação ao cliente (contratado, convidado ou que orçou).

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Ordenar por média simples | Injusto com volume; fraudável | Problema que motivou o ADR |
| Calcular `WR` no app | Cada cliente do app precisa de `C` e de todas as notas | Regra de negócio no banco (ADR-0003) |
| Revelar só por tempo (sem "ambos avaliaram") | Atrasa feedback legítimo | Revelação imediata quando ambos avaliaram é melhor UX |
| Mostrar `rank_score` como nota pública | Confunde ("por que 4,78 se tenho 4,88?") | Exibir a média real e usar o score só para ordenar |

## Consequências

* (+) Ordenação justa e difícil de fraudar; menos vingança; mais avaliações completas; reputação com dois lados.
* (+) Toda a regra no banco: testável (`supabase/tests/review_system_smoke.sql`, 30 asserções) e consistente entre clientes.
* (−) Avaliações reveladas com atraso de até 48 h; a nota do profissional pode "não mexer" após um serviço.
* (−) `platform_avg_rating()` é recalculada por consulta (aceitável no volume atual; materializar quando crescer).
* (−) A trava de crise é de UI: um cliente pode contorná-la via API (a avaliação continua válida, só não há desvio para o suporte).

## Referências

* Migration `20261023100000_review_system.sql`; telas `RatingScreen`, `RateClientScreen`, `MyReviewsScreen`, `ProviderPublicProfileScreen`.
* [ADR-0003](0003-regras-de-negocio-no-banco-via-rpc.md), [ADR-0007](0007-privacidade-por-minimizacao-de-dados.md).
