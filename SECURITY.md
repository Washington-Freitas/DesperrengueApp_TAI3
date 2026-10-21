# Política de Segurança

A segurança do Desperrengue — que trata **identidade, documentos, endereços residenciais e fluxo financeiro (simulado no MVP)** — é prioridade. Este documento informa **quais versões recebem correções**, **como reportar vulnerabilidades de forma confidencial** e **o que esperar do processo**. Alinha-se às práticas da ISO/IEC 27001 (Anexo A: gestão de vulnerabilidades técnicas, A.8.8) e à ISO/IEC 29147 (divulgação de vulnerabilidades).

## 1. Versões suportadas

O projeto está em **fase pré-1.0 (MVP acadêmico)**. Somente a linha mais recente recebe correções de segurança.

| Versão / ramo | Suporte a correções de segurança |
| :-- | :-: |
| `main` (última versão publicada) | ✅ |
| Candidata `0.2.x` (ramo `fix/foundation-hardening` até o *merge*) | ✅ |
| `0.1.x` e anteriores | ❌ (contêm falhas já corrigidas; atualize) |

O **backend** (Supabase) é implantado de forma contínua: correções de banco/Edge Functions valem para todos os clientes imediatamente, sem versionamento por cliente.

## 2. Como reportar uma vulnerabilidade

> **Não abra *issue*, *pull request* ou discussão pública** para relatar vulnerabilidades.

Use **um** dos canais confidenciais:

1. **GitHub Private Vulnerability Reporting** — na aba *Security → Report a vulnerability* do repositório `Washington-Freitas/DesperrengueApp_TAI3` (preferencial: cria um aviso privado com os mantenedores).
2. **E-mail:** `suporte@desperrengue.tech` com o assunto **`[SECURITY] <resumo curto>`**.

**Inclua, se possível:**

* descrição e **impacto** (que dado/ação é afetado; quem pode explorar);
* **passos de reprodução** ou prova de conceito mínima (*sem* extrair dados reais de terceiros);
* versão/commit, plataforma (Android/iOS), endpoint/RPC/tabela envolvidos;
* sugestão de mitigação, se houver;
* se deseja **crédito** público e como.

*Ainda não mantemos chave PGP. Se precisar de canal cifrado, peça no primeiro contato — combinaremos uma troca segura.*

## 3. O que você pode esperar (SLA)

| Etapa | Prazo-alvo |
| :-- | :-- |
| Confirmação de recebimento | ≤ **3 dias úteis** |
| Triagem e classificação (CVSS v3.1/v4) | ≤ **7 dias corridos** |
| Mitigação de severidade **Crítica** (dados/dinheiro/identidade) | ≤ **72 horas** |
| Correção de severidade **Alta** | ≤ **14 dias** |
| Correção de severidade **Média/Baixa** | ≤ **60 / 90 dias** |
| Divulgação coordenada | Após a correção, ou em até **90 dias** do relato (o que ocorrer primeiro), de comum acordo |

Manteremos você informado(a) do andamento e, com sua autorização, creditaremos a descoberta no [CHANGELOG](CHANGELOG.md).

## 4. Escopo

**No escopo**

* Aplicativo Flutter (Android/iOS) deste repositório.
* Esquema do banco, **políticas RLS**, *grants*, funções RPC e *triggers* em `supabase/migrations/`.
* Edge Function `enviar-email-aprovacao`.
* Configuração de Storage (*buckets* e políticas) e de Auth documentada.

**Fora do escopo**

* Vulnerabilidades em **serviços de terceiros** (Supabase, Resend, Google, ViaCEP, Abstract API) — reporte aos respectivos fornecedores.
* Engenharia social, *phishing* contra a equipe ou usuários, ataques físicos.
* **Negação de serviço** volumétrica e testes de carga contra o ambiente compartilhado.
* Achados puramente teóricos sem impacto demonstrável; ausência de cabeçalhos/boas práticas sem exploração.
* O **pagamento é simulado**: não há fluxo financeiro real a atacar; relatos sobre o *mock* só interessam se afetarem a integridade do domínio (ex.: liberar custódia sem PIN).

## 5. Regras de engajamento e *safe harbor*

Se agir de **boa-fé** e respeitar as regras abaixo, **não tomaremos ação legal** nem acionaremos autoridades por sua pesquisa:

* Teste **apenas com contas próprias** (ou de teste); **não acesse, modifique ou exclua dados de terceiros**; pare ao provar o impacto.
* Não degrade o serviço; não execute *scans* automatizados agressivos.
* Não retenha nem divulgue dados obtidos; relate-os e exclua-os.
* Não explore a vulnerabilidade além do necessário para demonstrá-la; não pivote para outros sistemas.
* Respeite a [privacidade dos usuários](#7-proteção-de-dados-pessoais-lgpd) e o [Código de Conduta](CODE_OF_CONDUCT.md).

## 6. Controles de segurança implementados (resumo)

Detalhes em [ARCHITECTURE §8](ARCHITECTURE.md#8-modelo-de-segurança) e nos ADRs [0003](docs/adr/0003-regras-de-negocio-no-banco-via-rpc.md), [0007](docs/adr/0007-privacidade-por-minimizacao-de-dados.md) e [0010](docs/adr/0010-webhook-autenticado-por-segredo-no-vault.md).

| Domínio | Controle |
| :-- | :-- |
| Autorização | RLS em todas as tabelas; `anon` sem acesso; `GRANT UPDATE` por coluna; *triggers* de proteção de colunas sensíveis |
| Integridade de domínio | Estados e dinheiro **só por RPC** `SECURITY DEFINER` (`search_path` fixo, `REVOKE`/`GRANT` explícitos) |
| Autenticação | Supabase Auth: e-mail+senha (≥ 8 caracteres) com OTP de 6 dígitos (validade 10 min), Google OAuth; confirmação de e-mail obrigatória |
| Dados sensíveis | KYC em *bucket* privado por pasta do usuário; endereço e PIN em tabelas de acesso restrito; URLs assinadas (1 h) |
| Anti-abuso | Limite de 3 orçamentos e 3 convites; 5 tentativas de PIN persistidas; convites expiram (cron) |
| Webhook | Segredo no Vault, comparação em tempo constante, e-mail obtido no servidor, link sem credencial |
| Segredos | Fora do repositório; app usa apenas a *publishable key*; rotação documentada |
| Verificação | Teste de fumaça com 62 asserções; ensaio de migrations com `ROLLBACK` |

## 7. Proteção de dados pessoais (LGPD)

* **Princípios aplicados:** finalidade, necessidade (minimização), segurança e transparência.
* **Dados tratados:** nome, e-mail, telefone, endereço, localização, documentos de identificação e selfie (KYC), fotos de serviços, mensagens.
* **Eliminação:** FKs em cascata permitem remover a conta e seus dados; **o processo formal de atendimento a direitos do titular ainda será definido** (ROADMAP E-11).
* **Incidentes:** em caso de violação com risco relevante a titulares, a equipe avaliará e comunicará à **ANPD** e aos afetados nos termos do art. 48 da LGPD.

## 8. Gestão de segredos e credenciais

* **Nunca** versionar `service_role`, senha do banco, `RESEND_API_KEY`, tokens pessoais (PAT) ou `.env`.
* Tokens de operação são **temporários, de escopo mínimo e revogados** ao final.
* **Suspeita de vazamento:** (1) revogue/rotacione imediatamente; (2) avalie o histórico do Git (segredos removidos de arquivos continuam no histórico); (3) registre o incidente.
* **Ação pendente conhecida:** uma chave de API de terceiros (validação de e-mail) esteve versionada em *commits* antigos e **deve ser rotacionada** — o código atual a recebe por `--dart-define`.

## 9. Limitações conhecidas (transparência)

| Item | Situação |
| :-- | :-- |
| Pagamento e repasses | **Simulados** (sem gateway) — ver [ADR-0006](docs/adr/0006-pagamento-mock-com-custodia-e-pin.md) |
| Aprovação de KYC | **Automática (mock)** habilitada por `app_settings.kyc_auto_approve`; desativar em produção e adotar revisão administrativa |
| Ambientes | Único projeto (sem *staging*) |
| Testes de intrusão | Ainda **não realizados** por terceiros; revisão interna + teste automatizado de RLS |
| *Certificate pinning*, detecção de *root/jailbreak*, ofuscação | Não implementados |
| *Rate limiting* na API | Dependente dos limites padrão do Supabase |
| Bucket legado `kyc_documentos` | Privado; 19 objetos de teste a remover |

## 10. Higiene de dependências

* Atualizações em PRs dedicados (`chore(deps)`); revisar *changelogs* e permissões nativas adicionadas.
* `flutter pub outdated` periodicamente; avaliar `dependabot`/Renovate (ROADMAP).
* Preferir pacotes mantidos e com publicador verificado.

## 11. Reconhecimentos

Agradecemos a quem reporta de forma responsável. Com seu consentimento, listaremos os créditos aqui:

*(ainda sem relatos externos)*
