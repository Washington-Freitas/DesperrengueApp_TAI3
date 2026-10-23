# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.

O formato segue o [Keep a Changelog 1.1.0](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto adota o [Versionamento Semântico 2.0.0](https://semver.org/lang/pt-BR/) (`MAJOR.MINOR.PATCH`). Enquanto `MAJOR = 0`, a API (esquema de banco e contratos RPC) **pode mudar** entre versões `MINOR`; mudanças incompatíveis são sempre listadas em **Alterado** ou **Removido**, com marcação **(quebra de compatibilidade)**.

> **Nota sobre versões e tags.** O `pubspec.yaml` do app ainda declara `0.1.0+1` e **não há *tags* Git**. Ao publicar a próxima versão, atualize o `pubspec.yaml`, mova o conteúdo de *Não lançado* para a nova seção e crie a *tag* `vX.Y.Z`. As datas abaixo derivam do histórico do Git.

Categorias: **Adicionado** · **Alterado** · **Descontinuado** · **Removido** · **Corrigido** · **Segurança**.

---

## [Não lançado] — candidata a `0.2.0`

### Adicionado

**Produto — modos de uso**
- **Multi-modo**: a mesma conta pode ser **cliente** e **profissional**; tela de seleção de modo ("Como você deseja usar o Desperrengue hoje?"), atalho para o outro modo no Perfil e "Trocar de modo". Tema laranja (cliente) e azul (profissional).

**Produto — cliente**
- Home com categorias, busca, serviço em andamento e endereço ativo; cadastro inicial (nome, telefone, **endereço por CEP via ViaCEP** ou GPS).
- Busca e listagem de profissionais com ordenação (proximidade, nota, taxa de visita); **perfil público** (sobre, especialidades, portfólio, avaliações).
- **Assistente de pedido em 3 passos** (descrição + até 4 fotos → quando → revisão), em duas modalidades: **agendado** (calendário e horários) e **emergência** ("Para agora").
- Pedido **direto** (convite 2 h) e **público** (até 3 profissionais orçam); comparação de orçamentos; adicionar outros profissionais (até 3 no total).
- Orçamento recebido (aceitar/recusar), **checkout simulado** (Pix/cartão) com aviso de ambiente de demonstração, acompanhamento com linha do tempo, endereço, fotos do serviço e **PIN de confirmação**.
- Radar de emergência (5 min) e alerta "Temos um Match!".
- Resumo de conclusão, **avaliação** (estrelas, etiquetas, comentário, gorjeta simulada), relato de problema com protocolo e SLA de 24 h; **Meus Pedidos** (em andamento/concluídos/cancelados).

**Produto — profissional**
- Painel (disponibilidade online/offline, faturamento, serviços concluídos, nota, valor em custódia, solicitações), **Oportunidades** (convites diretos e pedidos abertos por especialidade).
- Detalhes do chamado e **orçamento** com **comissão de 12 % calculada ao vivo**; espera pela resposta com anel de contagem; **aceitar/recusar emergência**; retirar proposta.
- **Execução**: cronômetro, endereço completo (após contratado), **4 evidências fotográficas obrigatórias** (câmera/galeria), **liberação por PIN** com teclado numérico e limite de 5 tentativas, tela "Serviço finalizado e pago", avaliação do cliente (5 critérios).
- **Garantia e segurança** ("Tive um problema") e mediação com protocolo.
- **Carteira**: saldo, custódia, lançamentos futuros (inclui "em mediação"), desempenho da semana, últimos serviços.
- Edição de perfil (foto, título, bio, especialidades, taxa de visita, valor/hora, raio), **portfólio** e **cofre de certificados**; fluxo de **configuração inicial** pós-KYC (3 passos).

**Compartilhado**
- Chat por demanda (Realtime) com compartilhamento de localização; central de notificações (Realtime) com contador; central de ajuda e chamados.
- Design system (`core/ui`): tokens por modo, botões, cartões, banners, anel de contagem, radar, avatar, estados de erro/vazio/carregando; formatação pt-BR (R$, datas, tempo relativo, distância); **localização pt-BR** (`flutter_localizations`).

**Banco de dados (migrations `20261019120000` … `20261019160000`)**
- Tabelas: `provider_profiles`, `provider_portfolio`, `provider_certificates`, `job_addresses`, `job_invites`, `job_secrets`, `job_evidence`, `payments`, `reviews`, `messages`, `notifications`, `support_tickets`.
- Views mínimas: `provider_public_profiles`, `job_client_cards`, `public_reviews`, `provider_busy_slots`.
- RPCs: `enroll_mode`, `set_last_mode`, `complete_setup`, `invite_providers`, `decline_invite`, `accept_emergency`, `request_emergency_mock`, `pay_job_mock`, `complete_job_with_pin`, `withdraw_quote`, `reject_quote`, `submit_review`, `create_support_ticket`, `admin_resolve_dispute`, `expire_invites`.
- *Jobs* `pg_cron`: `expire-invites` (1/min). *Buckets*: `job-media` (privado) e `public-media`. Realtime em `jobs`, `quotes`, `job_invites`, `messages`, `notifications`.
- **Teste de fumaça com 62 asserções** (`supabase/tests/security_smoke.sql`), transacional e sem efeitos colaterais.

**Engenharia e documentação**
- `README`, `ROADMAP`, `CHANGELOG`, `ARCHITECTURE`, `SETUP`, `CONTRIBUTING`, `TESTING`, `SECURITY`, `LICENSE`, `CODE_OF_CONDUCT`, ADRs 0001–0010, *templates* de PR/issue e *workflow* de CI.
- Especificação das telas derivada dos protótipos hi-fi em `docs/specs/`.
- 16 testes unitários (roteamento multi-modo, formatação, modelos).
- **Seleção de modo com estado do cadastro**: cada cartão mostra "Criar conta…", **"Termine o seu cadastro"** (com botão "Continuar cadastro"), "Em análise" ou "Já cadastrado". Primeiro acesso (Google ou e-mail) e cadastros pela metade sempre passam pela seleção, nunca caem direto no KYC.
- **Rascunho automático do cadastro** (`DraftStore`, local por conta): nome/telefone/endereço do cliente, perfil do profissional e registro profissional são recuperados ao voltar. Fotos e documentos não são guardados.
- **Endereço automático**: ao digitar os 8 dígitos do CEP o formulário preenche rua, bairro, cidade e UF (ViaCEP, com BrasilAPI de reserva) e leva o cursor ao **número**. "Usar minha localização atual" captura o GPS, descobre o endereço (OpenStreetMap Nominatim + refinamento por CEP) e preenche os campos. APIs gratuitas, **sem cadastro nem chave**.
- O cliente que também é profissional **se vê** nos resultados de busca (etiqueta "Você" e aviso "Visão do cliente"), mas não pode contratar a si mesmo (UI, assistente de pedido e banco).
- Migration `20261022100000_self_service_guards` (`accept_emergency` recusa o próprio pedido).
- Testes unitários: 36 (estágios do cadastro, parsers de CEP/GPS, rascunhos).
- **Avaliações v2** ([ADR-0011](docs/adr/0011-avaliacoes-cegas-bayes-e-selos.md)): pílulas de contexto que mudam com a nota (1–3 ⭐ "O que deu errado?", 4–5 ⭐ "O que mais te impressionou?"); **avaliação bidirecional cega** (revelada quando as duas partes avaliam ou 48 h depois); **ranqueamento por Média Bayesiana** (`WR = v/(v+m)·R + m/(v+m)·C`, com peso de recência) calculado no banco; **selos automáticos** (Mestre da Organização, Sempre Pontual, Super Profissional…); **fotos "antes e depois"** com selo "Verificado" e aba "Fotos de clientes"; **direito de resposta** público (uma vez); **trava de retenção de crise** (garantia/suporte antes de publicar nota 1–2 com "Problema não resolvido"); reputação do cliente visível aos profissionais envolvidos; tela "Minhas avaliações" do profissional.
- Testes: `supabase/tests/review_system_smoke.sql` (30 asserções, `FALHAS=0`) e 44 testes unitários.

### Alterado
- **(quebra de compatibilidade)** `profiles.role` deixa de aceitar `client`/`provider`; passa a existir só para `admin`. Os papéis são as *flags* `is_client`/`is_provider`.
- **(quebra de compatibilidade)** `accept_quote` leva o pedido a `awaiting_payment` (antes `in_progress`); o pagamento simulado é que inicia o serviço.
- `cancel_job` aceita pedidos `open` ou `awaiting_payment` e **estorna** a reserva de emergência.
- Limite de três orçamentos passa a ignorar propostas `withdrawn`.
- Estrutura do repositório: o app saiu de `build/desperrengue_app/` para **`app/`**.
- Roteamento centralizado em `destinationFor(profile, mode, forceSelection)` + `AuthGate`/`PostAuthRouter` (o perfil é recarregado sem "piscar").
- Documentação de ambiente: JDK 11 → **17** (exigência do Gradle 9/AGP 9).

### Descontinuado
- Estado `awaiting_approval` e as RPCs `provider_finish_job`/`client_approve_job`: mantidos no banco, **sem uso** pelo fluxo atual (conclusão por PIN).

### Removido
- Tabela `perfis` e colunas/enum legados (`tipo_perfil`, `document_submitted_at`, `user_verification_status`).
- Arquivos vazios de `profile_setup/` (substituídos pelos fluxos reais) e `app/database/database_schema.sql` (a fonte da verdade são as migrations).
- Constante de chave de terceiros do código-fonte (Abstract API passa a vir de `--dart-define`).

### Corrigido
- **Permissão de localização ausente** no manifesto Android (e descrição no `Info.plist`): o botão "Usar minha localização atual" não conseguia funcionar.
- Excluir foto do portfólio não funcionava e exibia `setState() callback argument returned a Future`; o mesmo padrão foi corrigido em Certificados, Oportunidades, Carteira, Suporte e busca de profissionais.
- Profissional não aparecia como cliente na busca (a própria conta era excluída da lista).
- Quem já tinha `is_provider` sem KYC enviado era levado direto às fotos de verificação ao logar.- **Divergência entre duas tabelas de perfil**, que desconectava o fluxo automático de KYC.
- Brecha de **auto-aprovação do KYC** e de **escalada de papel** pela API.
- Navegação pós-OAuth executada antes de a sessão existir; ausência de guarda de sessão; deep link sem efeito.
- Permissão `INTERNET` ausente no manifesto Android de release; descrições de câmera/fotos e esquemas de URL ausentes no iOS.
- **PIN nunca bloqueava** (o `RAISE EXCEPTION` desfazia o contador de tentativas) — agora persistido.
- Estado `withdrawn` rejeitado pelo `CHECK` de `quotes.status`.
- Cancelar emergência paga **não estornava** a reserva.
- Calendário e datas em inglês (faltava localização pt-BR); tema de telas empilhadas não seguia o modo; avatar coberto no perfil público; chips com texto ilegível; navegação "voltar" após enviar pedido.

### Segurança
- Políticas RLS `TO authenticated` e `REVOKE` para `anon`; `GRANT UPDATE` **por coluna**; *triggers* de proteção (`profiles_protect_columns`, `provider_profiles_protect`).
- Edge Function `enviar-email-aprovacao`: **autenticação por `x-webhook-secret`** (Vault), e-mail obtido por `auth.admin`, *link* sem credencial, HTML escapado.
- Buckets privados com URLs assinadas; `kyc_documentos` legado tornado privado.
- Endereço completo e PIN em tabelas com política restritiva ([ADR-0007](docs/adr/0007-privacidade-por-minimizacao-de-dados.md)).
- Configuração de Auth: OTP com validade de 10 min, *redirect URLs* revisadas, templates em pt-BR.
- Recomendação operacional: **rotacionar a chave da Abstract API** presente no histórico do Git.

---

## [0.1.0] — 2026-10-04

Linha de base consolidada na *merge* do PR #13 (`feat/auth-and-infra-setup`).

### Adicionado
- Aplicativo Flutter com **cadastro por e-mail e senha com OTP de 6 dígitos**, **login com Google** e escolha de papel (cliente/profissional).
- **Fluxo de KYC do profissional** (7 etapas: frente e verso do documento, selfie, registro CREA/CFT/CNPJ, termos, envio, acompanhamento e ativação).
- Integração com Supabase (Auth, PostgreSQL, Storage) e **Edge Function** de e-mail de aprovação via Resend, com domínio `desperrengue.tech` verificado (DKIM/SPF).
- Documentação acadêmica: contexto, especificação (RF/RNF, personas, histórias), plano de negócio e tributação, guias de ambiente (Windows/macOS/Linux), protótipos hi-fi.

[Não lançado]: https://github.com/Washington-Freitas/DesperrengueApp_TAI3/compare/main...fix/foundation-hardening
