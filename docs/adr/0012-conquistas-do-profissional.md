# ADR-0012 — Conquistas do profissional: catálogo no app, desbloqueio no banco

* **Status:** Aceito
* **Data:** 2026-10-23
* **Decisores:** Desenvolvedor
* **Tags:** gamificação, reputação, banco de dados, UX

## Contexto

Os selos do [ADR-0011](0011-avaliacoes-cegas-bayes-e-selos.md) premiam *qualidade percebida* (pílulas), mas o profissional não tinha marcos de **progresso** (estilo troféus) para volume de trabalho, e o cliente não via essa trajetória no perfil. Era necessário um sistema **escalável** (do 1º serviço aos milhares), **sóbrio** (nomes factuais), **inviolável** (não editável pelo app) e **barato** (sem custo financeiro nem dependência de imagens de terceiros).

## Decisão

1. **Catálogo no app, estado no banco.** `core/models/achievements.dart` define 9 categorias × 10 níveis (nomes, descrições, metais); o banco guarda **apenas desbloqueios** (`provider_achievements`, código `<categoria>_<limite>`). Mudar um texto ou metal não exige *migration*.
2. **Limites universais** `1, 10, 25, 50, 100, 500, 1.000, 2.500, 5.000, 10.000`, 2 níveis por metal (Bronze → Diamante). Limites duplicados em SQL e Dart, protegidos por teste.
3. **Contagem a partir de dados auditados:** serviços concluídos por PIN, avaliações **reveladas**, pílulas elogiadas, emergências e clientes recorrentes (`_achievement_counts`).
4. **Desbloqueio automático e idempotente:** `AFTER UPDATE OF status ON jobs` e `reveal_job_reviews()` chamam `refresh_provider_achievements()`; notificação uma vez por nível; *backfill* silencioso.
5. **Privacidade/segurança:** RLS somente leitura (dono, equipe e vitrine de profissionais **ativos**); contadores só do próprio usuário (`my_achievement_counts()`); sem `INSERT/UPDATE/DELETE` para o app.
6. **Medalhas vetoriais** desenhadas em Flutter (anel metálico em degradê + ícone), sem imagens externas.
7. **Onde aparece:** perfil do profissional → "Minhas conquistas" (progresso completo); perfil público → seção "Conquistas" (melhor medalha por categoria + tela completa); tela de serviço finalizado → cartões de novas conquistas.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Catálogo inteiro no banco (tabela de definições) | *Migration* a cada ajuste textual; mais joins | Conteúdo é apresentação, não regra de negócio |
| Calcular tudo na leitura (sem tabela de desbloqueios) | Sem data de desbloqueio, sem notificação, custo por abertura de perfil | Perde histórico e "uma vez só" |
| Imagens/ícones de bancos de imagens | Licenciamento, peso, inconsistência visual | Vetor próprio é consistente e gratuito |
| Pontos (XP) agora | Sem recompensa real, gera fadiga ([GAMIFICACAO](../GAMIFICACAO.md)) | Postergado para a Fase 2/3 |

## Consequências

* (+) Escala natural: novas categorias = nova linha no catálogo + novo `union all` no contador.
* (+) Zero custo financeiro; reforça a retenção (a vitrine auditada só existe no app).
* (−) Duplicação dos limites SQL/Dart (mitigada por testes) e um *union* por categoria.
* (−) O contador `repeat_clients` faz agregação por consulta (aceitável no volume atual; materializar quando crescer).

## Referências

* Migration `20261023200000_achievements.sql`; testes `supabase/tests/achievements_smoke.sql` (22) e `app/test/achievements_test.dart`.
* [GAMIFICACAO](../GAMIFICACAO.md) — modelagem matemática e *unit economics* das fases seguintes.
