# ROADMAP — Desperrengue

> **Natureza do documento.** Plano vivo de produto e engenharia, revisado ao final de cada *sprint*. Datas são **metas**, não compromissos contratuais. O que *já existe* está em [CHANGELOG.md](CHANGELOG.md); o *como* está em [ARCHITECTURE.md](ARCHITECTURE.md).
> **Última revisão:** 2026-10-21 · **Marco acadêmico fixo:** entrega do MVP na **primeira semana de dezembro de 2026**.

## 1. Visão e tese de produto

**Visão.** Ser a forma mais segura e transparente de contratar reparos e serviços residenciais no Brasil, eliminando a cobrança por orçamento e a assimetria de informação entre cliente e prestador.

**Tese.** O atrito do mercado não está na *descoberta* de profissionais, e sim na **confiança** (identidade, preço, execução, pagamento). O Desperrengue ataca-a com: (i) **verificação de identidade e registro profissional** (KYC); (ii) **orçamento gratuito** limitado a 3 propostas; (iii) **custódia do pagamento** liberada por **prova de presença** (PIN) e **evidências fotográficas**; (iv) **mediação** de disputas; (v) reputação bidirecional. Receita: **comissão de 12–15 % apenas sobre serviço concluído e pago pelo app** (ver `docs/Planos de Negocio e Tributação.md`).

**Métricas-guia (*North Star* e apoio)** — *hipóteses a calibrar com dados reais*:

| Métrica | Definição operacional | Meta inicial (hipótese) |
| :-- | :-- | :-- |
| **Serviços concluídos pagos por semana** (*North Star*) | `count(jobs where status='completed')` por semana | crescimento semanal sustentado |
| Taxa de resposta a convites | `quoted+accepted / convites` | ≥ 60 % |
| Tempo até 1º orçamento | `min(quotes.created_at) − jobs.created_at` (mediana) | ≤ 2 h |
| Conversão pedido → serviço concluído | `completed / jobs criados` | ≥ 25 % |
| Disputas por 100 serviços | `support_tickets(job) / completed × 100` | ≤ 3 |
| NPS de cliente e profissional | pesquisa pós-serviço | ≥ 50 |

## 2. Legenda e priorização

Priorização por **MoSCoW** (**M**ust, **S**hould, **C**ould, **W**on't-now) dentro de cada horizonte, refinada por **RICE** (*Reach × Impact × Confidence ÷ Effort*) na grooming. Estados: ✅ concluído · 🟡 em andamento · ⬜ planejado · 🧪 experimento/hipótese.

## 3. Horizonte atual — **Agora** (out/2026) — *em desenvolvimento / concluído*

| Épico | Descrição | Status |
| :-- | :-- | :-: |
| **E-01 Fundação e segurança** | Perfil único, RLS, `GRANT` por coluna, RPCs, KYC por bucket privado, Edge Function autenticada, migrations versionadas, teste de fumaça | ✅ |
| **E-02 Multi-modo** | Mesma conta como cliente e profissional; seleção de modo; tema por modo | ✅ |
| **E-03 Ciclo do serviço (mock financeiro)** | Pedido, convites (2 h/5 min), orçamentos (máx. 3), aceite, custódia, PIN, 4 evidências, avaliação, emergência com estorno, chat, notificações, suporte/disputa, carteira | ✅ |
| **E-04 Governança de engenharia** | README, ARCHITECTURE, ADRs, SETUP, CONTRIBUTING, TESTING, SECURITY, templates, CI (análise, testes e verificação de links dos `.md`); documentação organizada em `docs/` e `.github/` | ✅ |
| **E-05 Validação em dispositivos reais** | Roteiro de testes em Android físico e iOS; OAuth Google; OTP; deep link; câmera | 🟡 |
| **E-05b Reputação e conquistas (Fase 1)** | Avaliação guiada por pílulas e **cega** (48 h), ranking Bayesiano, selos e **conquistas escalonadas** (9 categorias × 10 níveis), visíveis no perfil público ([ADR-0011](adr/0011-avaliacoes-cegas-bayes-e-selos.md), [ADR-0012](adr/0012-conquistas-do-profissional.md)) | ✅ |
| **E-05d Carteira do cliente** | Ledger de partida dobrada, custódia por gatilhos, trava de saldo e recarga Pix sandbox com webhook e simulação de 1 toque ([ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)) | ✅ |
| **E-05c Conta, tema e vitrine** | Exclusão de conta LGPD com trava financeira e Dossiê PDF; saque Pix (simulado); tema Automático/Claro/Escuro com tokens; splash coreografada; sessão no Keystore; último perfil; **vitrine LIFO** e Case de Sucesso (vídeo, fotos, relatório) | ✅ |

## 4. Curto prazo — até a entrega do MVP (nov – 1ª semana/dez 2026)

**Objetivo do horizonte:** *produto demonstrável de ponta a ponta, estável e seguro o bastante para avaliação acadêmica e testes controlados com usuários reais.*

| Épico | Itens principais | Prioridade | Critério de aceite |
| :-- | :-- | :-: | :-- |
| **E-06 Qualidade automatizada** | Testes de *widget* das telas críticas; `integration_test` do fluxo feliz; meta de cobertura (ver [TESTING](TESTING.md)); CI com cobertura | M | CI verde; cobertura ≥ 60 % em `core/` e ≥ 40 % global |
| **E-07 Operação segura do KYC** | Desligar `kyc_auto_approve`; **painel de revisão** (lista, documentos por URL assinada, aprovar/recusar com motivo) | M | Nenhum KYC aprovado sem ação de admin; auditoria em `kyc_submissions.reviewed_by` |
| **E-08 Staging e pipeline de banco** | Segundo projeto Supabase; script de aplicação de migrations com *dry-run*; checagem de *drift* | M | Migrations testadas em *staging* antes de produção |
| **E-09 Recuperação de senha e Apple Sign-In** | Fluxo de reset; botão Apple funcional (iOS) | S | Reset ponta a ponta; revisão de conformidade das lojas |
| **E-10 Links universais** | *App Links* (Android) e *Universal Links* (iOS) em `desperrengue.tech`, substituindo o esquema `desperrengue://` (frequentemente filtrado por clientes de e-mail) | S | E-mail de aprovação abre o app em ≥ 95 % dos testes |
| **E-11 Conformidade LGPD (base)** | Termos e política **versionados** com registro de aceite; fluxo de **exclusão de conta**; mapeamento de dados | S | Aceite versionado em banco; exclusão remove perfil e mídia |
| **E-12 Observabilidade mínima** | Registro de erros do app; painel de logs/consultas lentas do Supabase; alertas de falha da Edge Function | C | Falhas visíveis em < 5 min |

## 5. Médio prazo (1º semestre/2027) — *da demonstração ao piloto*

| Épico | Itens principais | Prioridade |
| :-- | :-- | :-: |
| **E-13 Pagamentos reais** | Gateway (Pix e cartão) com *split* de comissão, **webhooks assinados**, conciliação, estorno real; saque Pix do profissional; dados bancários; nota fiscal/tributação (Simples Nacional — ver plano de negócio) | M |
| **E-14 Matching e geolocalização** | Mapa com *hotspots* de demanda, raio de atendimento efetivo, ordenação por proximidade/tempo de resposta, check-in por GPS no local | M |
| **E-15 Comunicação** | Notificações *push* (FCM/APNs) com *deep link* para o pedido; chamada de voz (VoIP) intermediada; mídia no chat | S |
| **E-16 Navegação declarativa e estado** | Migração para `go_router`; adoção de Riverpod para estado compartilhado ([ADR-0009](adr/0009-roteamento-por-funcao-pura-e-authgate.md)) | S |
| **E-17 Reputação e gamificação (Fases 2–3)** | ✅ *Já entregue:* avaliações cegas, pílulas, ranking Bayesiano, selos e **conquistas** (90 troféus). 🧪 *Próximo:* multiplicador de SLA/*streak* (β = 0,12), Índice de Confiança, Saúde do Lar, Medidor de Diagnóstico; depois, em teste A/B: ligas de *take-rate* regressivo, Cofre da Casa e indicação — **com guarda-corpo de ≤ 10 % da margem** (ver [GAMIFICACAO](GAMIFICACAO.md)) | S |
| **E-18 Tema escuro completo** | Migrar Login, Cadastro e KYC aos tokens e remover `LightIsland`; revisar pastéis de categoria | S | Nenhuma tela com cor literal de superfície/texto |
| **E-19 Pix real (PSP)** | Trocar o Pix **sandbox** da carteira ([ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)) e o saque simulado por um provedor (Mercado Pago/Asaas/Efí): adaptador que traduz o webhook do PSP para o payload normalizado de `pix-webhook`; remover o crédito inicial e desligar `pix_sandbox`; titularidade pelo CPF do KYC; conciliação | L | Recarga e saque reais com comprovante e conciliação diária |
| **E-18 Agenda do profissional** | Disponibilidade por dia/horário, bloqueios, sincronização com calendário | S |
| **E-19 Qualidade de serviço** | Garantia de serviço, reabertura, reagendamento/cancelamento com regras de multa e estorno | C |

## 6. Longo prazo (2º semestre/2027 em diante) — *escala e defensibilidade*

| Tema | Hipóteses a validar |
| :-- | :-- |
| **Expansão geográfica** | Replicação por cidade; precificação regional; parcerias com condomínios |
| **Monetização adicional** 🧪 | Assinatura premium para profissionais (destaque), cupons e *cashback* para clientes, seguros/garantia estendida |
| **Matching inteligente** 🧪 | Recomendação por histórico, sazonalidade e reputação; estimativa de preço assistida por modelo a partir de fotos |
| **Plataforma B2B** 🧪 | Administradoras e síndicos como clientes recorrentes; contratos e faturamento mensal |
| **Antifraude** | Detecção de colusão (cliente × profissional), *device fingerprinting*, análise de evidências |
| **Plataforma web** | Painel web para administração e para profissionais |
| **Arquitetura** | Reavaliar BaaS vs. serviços dedicados (filas, *search*, *event bus*) conforme carga — via novo ADR |

## 7. Riscos e dependências

| Risco | Probabilidade | Impacto | Mitigação |
| :-- | :-: | :-: | :-- |
| Equipe de 1 dev + 1 PO (fator ônibus = 1) | Alta | Alto | Documentação (este conjunto), ADRs, testes, automação |
| Ambiente único (sem *staging*) | Média | Alto | E-08; ensaio com `ROLLBACK` até lá |
| Mock de KYC/pagamento percebido como real | Média | Alto | Avisos na UI; E-07 e E-13 |
| Limites do plano gratuito (Supabase/Resend) | Média | Médio | Monitorar; plano pago quando houver tração |
| Mudanças regulatórias (LGPD, meios de pagamento, enquadramento fiscal) | Média | Alto | E-11; consultoria jurídica/contábil antes do piloto |
| Dependência do domínio gratuito (`desperrengue.tech`, expira em 2027, renovação automática desativada) | **Certa** | Alto | **Renovar ou migrar o domínio antes do vencimento** |
| Rejeição nas lojas (login social, permissões) | Baixa | Médio | E-09; checklist de revisão |

## 8. Como este documento é mantido

* Alterações por *pull request* (`docs:`); o PO valida prioridades, o desenvolvedor valida viabilidade.
* Item concluído **migra** para o [CHANGELOG](CHANGELOG.md) e é marcado ✅ aqui.
* Decisões estruturais geram [ADR](adr/README.md).
