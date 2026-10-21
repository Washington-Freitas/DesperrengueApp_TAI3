## Resumo

<!-- O QUÊ muda e POR QUÊ (o contexto, não só o diff). Vincule a issue. -->

Closes #

## Tipo de mudança

<!-- Marque uma. O título do PR deve seguir Conventional Commits: tipo(escopo): descrição -->

- [ ] `feat` — nova funcionalidade
- [ ] `fix` — correção de defeito
- [ ] `db` — migration / RLS / função SQL
- [ ] `refactor` / `perf` — sem mudança de comportamento / desempenho
- [ ] `docs` / `test` / `ci` / `chore`
- [ ] **Quebra de compatibilidade** (descreva a migração abaixo)

## Como testar

<!-- Passos objetivos para o revisor reproduzir. Informe dispositivo/emulador e conta de teste usada. -->

1.
2.

## Evidências

<!-- UI: capturas de tela/GIF antes e depois. Banco: saída do security_smoke.sql (OK=… FALHAS=0). -->

## Checklist do autor

**Qualidade**
- [ ] `flutter analyze` sem avisos e `flutter test` verdes (local e CI)
- [ ] Testes novos/atualizados cobrem o comportamento (ver [TESTING](../TESTING.md))
- [ ] Verifiquei estados de **carregamento, erro e vazio**, e textos em pt-BR
- [ ] Sem `print`/logs de dados pessoais; sem código morto ou comentado

**Banco de dados** *(marque N/A se não houver mudança de banco)*
- [ ] N/A
- [ ] Migration em `supabase/migrations/` com `BEGIN … COMMIT`, **sem editar migration já aplicada**
- [ ] **Ensaiei com `ROLLBACK`** antes de aplicar; apliquei e **registrei a versão** em `schema_migrations`
- [ ] Nova tabela tem **RLS**, `REVOKE` para `anon` e **teste de acesso negado** em `security_smoke.sql`
- [ ] Funções de domínio: `SECURITY DEFINER`, `search_path` fixo, `REVOKE`/`GRANT` explícitos
- [ ] Nenhum `UPDATE` direto concedido em `status`, `payment_status`, `verification_status`, notas ou contadores
- [ ] `security_smoke.sql` com **`FALHAS=0`** (saída anexada)

**Segurança e privacidade**
- [ ] **Nenhum segredo** (service_role, senhas, chaves, tokens) no diff nem no histórico do PR
- [ ] Dado pessoal/sensível está na tabela/bucket adequado e exposto só pelo mínimo necessário ([ADR-0007](../docs/adr/0007-privacidade-por-minimizacao-de-dados.md))
- [ ] Regras de negócio ficam no **banco/servidor**, não só na UI ([ADR-0003](../docs/adr/0003-regras-de-negocio-no-banco-via-rpc.md))

**Documentação**
- [ ] [CHANGELOG](../CHANGELOG.md) atualizado em **Não lançado**
- [ ] README/ARCHITECTURE/SETUP/ADR atualizados quando aplicável (mudança estrutural exige ADR)

## Riscos, impacto e plano de reversão

<!-- O que pode dar errado? Como reverter? (ex.: migration compensatória). Impacto em dados existentes? -->

## Notas para a revisão

<!-- Onde focar; decisões discutíveis; dívida técnica criada (com issue). -->

## Uso de IA

- [ ] Houve apoio de IA; **li, entendi e validei** todo o código gerado (ver [CONTRIBUTING §9](../CONTRIBUTING.md#9-código-assistido-por-ia))
