# ADR-0005 — Modelo multi-modo (cliente e profissional) por *flags*

* **Status:** Aceito (substitui o papel único introduzido no [ADR-0004](0004-unificacao-de-perfis-e-nomes-em-ingles.md))
* **Data:** 2026-10-19
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** domínio, identidade, UX

## Contexto

A primeira unificação manteve `profiles.role ∈ {client, provider, admin}`, **definido uma única vez**. O requisito de produto é que **a mesma pessoa** possa pedir serviços e prestá-los, escolhendo "como quer usar o app hoje" (protótipo `01_b_selecao_de_sessao`). Um papel único forçaria **duas contas** (dois e-mails) ou perderia histórico.

Os dois papéis têm **ciclos de vida distintos**: o profissional passa por KYC e ativação; o cliente apenas completa nome e endereço.

## Decisão

1. Substituir `role` por **flags independentes**: `is_client`, `is_provider`, com `client_setup_done`, `provider_setup_done` e `last_mode`. `role` permanece **apenas** para `admin`.
2. **A escolha de modo é estado de sessão do cliente** (`AppSession`), não de banco; o banco registra apenas `last_mode` para conveniência.
3. As flags só mudam por RPC (`enroll_mode`, `complete_setup`); *trigger* de proteção impede alteração direta.
4. A função pura `destinationFor(profile, mode, forceSelection)` decide a tela: quem possui **um** modo entra direto; quem possui **dois** escolhe; "Trocar de modo" reabre a seleção.
5. Helpers de RLS passam a usar as flags: `is_client()` e `is_active_provider()` (`is_provider` ∧ `verification_status = 'ACTIVE'`).

## Alternativas consideradas

| Alternativa | Vantagens | Desvantagens | Motivo da rejeição |
| :-- | :-- | :-- | :-- |
| Papel único imutável | Simples | Duas contas por pessoa; fricção | Contraria o requisito |
| Tabelas separadas `clients` / `providers` | Isolamento | Duplicação de dados comuns; *joins* | Excesso de estrutura para atributos quase idênticos |
| Array `roles text[]` | Extensível | Constraints e índices menos claros; grants por coluna mais difíceis | Flags booleanas são mais simples e verificáveis |

## Consequências

**Positivas:** uma conta, dois modos; histórico unificado; onboarding incremental.
**Negativas:** o profissional mantém o KYC próprio; mais combinações a testar.
**Riscos:** vazamento entre modos (ex.: cliente vendo dados de profissional) → views mínimas e RLS por relação com o pedido.

## Verificação

Testes `destinationFor` (7 cenários) e itens 05–07 do teste de fumaça (mesma conta vira cliente **e** profissional).

## Referências

`supabase/migrations/20261019120000_multi_mode_service_flow.sql` · `app/lib/core/models/user_profile.dart`
