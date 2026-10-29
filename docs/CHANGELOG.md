# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.

O formato segue o [Keep a Changelog 1.1.0](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto adota o [Versionamento Semântico 2.0.0](https://semver.org/lang/pt-BR/) (`MAJOR.MINOR.PATCH`). Enquanto `MAJOR = 0`, a API (esquema de banco e contratos RPC) **pode mudar** entre versões `MINOR`; mudanças incompatíveis são sempre listadas em **Alterado** ou **Removido**, com marcação **(quebra de compatibilidade)**.

> **Nota sobre versões e tags.** O `pubspec.yaml` do app ainda declara `0.1.0+1` e **não há *tags* Git**. Ao publicar a próxima versão, atualize o `pubspec.yaml`, mova o conteúdo de *Não lançado* para a nova seção e crie a *tag* `vX.Y.Z`. As datas abaixo derivam do histórico do Git.

Categorias: **Adicionado** · **Alterado** · **Descontinuado** · **Removido** · **Corrigido** · **Segurança**.

---

## [Não lançado] — candidata a `0.2.0`

### Adicionado

**Carteira do cliente, ledger e Pix sandbox (ADR-0018)**
- **Ledger de partida dobrada** (`ledger_txns`/`ledger_lines`, valores em **centavos**, cada transação soma zero, `idempotency_key` única) e **extrato** do cliente em tempo real (`wallet_statement`, Realtime).
- **Carteira** com `available_balance` e `escrow_balance`; **crédito inicial de testes** de R$ 1.200,00 (fictício, lançado no ledger) para todo cliente.
- **Custódia por gatilhos em `payments`**: reter ao pagar (`SELECT … FOR UPDATE`, erro `INSUFFICIENT_FUNDS`), liberar ao profissional (líquido + comissão) com o PIN e estornar ao cancelar/expirar/disputa — sem reescrever as RPCs existentes.
- **Trava de saldo**: `InsufficientFundsBottomSheet` ("Saldo insuficiente para este serviço", Valor | Seu saldo | Faltam) com CTA "Adicionar R$ X agora ➔" que abre a recarga já com o valor que falta.
- **Telas** `CarteiraClienteScreen` (saldo, 👁️ privacidade, pílula "Valor protegido em custódia", extrato com ícones semânticos) e `AdicionarSaldoScreen` (máscara BRL, atalhos +50/+100/+200/+500, QR + copia-e-cola, "aguardando confirmação", **"Simular pagamento Pix agora"** e animação de sucesso). Chip de saldo no cabeçalho do cliente.
- **Pix (sandbox)**: BR Code EMV com chave fictícia (nenhum banco consegue pagar), `create_topup`/`confirm_topup` idempotentes e Edge Function **`pix-webhook`** (`x-webhook-secret`, payload normalizado) — pronta para um adaptador de PSP real (ROADMAP E-19).

**Distribuição beta e atualização automática (ADR-0017)**
- **CI de beta** (`beta-release.yml`): a cada push em `main`/`fix/foundation-hardening` (e por botão manual) roda análise + testes, compila o APK **assinado com a chave beta** e publica no release rolante `beta-latest` (link fixo de download). Falhou na análise/teste = nada é publicado.
- **Aviso de versão nova dentro do app** (`UpdateGate`/`UpdateService`): consulta o release com ETag a cada ~2 min, ao abrir e ao voltar ao app; cartão "Nova versão disponível → Atualizar". Ativo só em builds `BETA_UPDATES=true`.
- Guia para testadores e para o desenvolvedor: [TESTE_COM_AMIGOS.md](TESTE_COM_AMIGOS.md).

**Conta, carteira e privacidade (ADR-0013)**
- **Excluir conta (LGPD)** com **trava financeira**: saldo > 0 abre o aviso "Você possui fundos retidos… transfira via Pix"; custódia/serviço em andamento também bloqueiam. Confirmação por digitação ("EXCLUIR").
- **Edge Function `excluir-conta`**: gera o **Dossiê de Despedida (PDF, `pdf-lib`)** em memória, envia pelo Resend e **só então** apaga os dados, os arquivos e a conta de autenticação. Dossiê com histórico, orçamentos, avaliações, **total gasto, total economizado e total de lucro**.
- **Saque Pix (simulado)**: tela com validação de CPF/CNPJ/e-mail/celular/chave aleatória, declaração de titularidade e chave guardada só mascarada; saldo calculado no servidor (`my_wallet`).
- **Modo privacidade (👁️)** no painel e na carteira: "R$ •••••" em saldo, custódia e faturamento; preferência lembrada.

**Vitrine de cases e Case de Sucesso (ADR-0016)**
- **Portfólio automático LIFO**: os 4 últimos serviços concluídos e avaliados (≥ 4★) no painel do profissional e no perfil público; o 5º cai para o histórico.
- **Fixar (📌)** até 3 serviços de 5★ (tela "Gerenciar vitrine").
- **Case de Sucesso**: vídeo (opcional), galeria de 4 fotos, **relatório técnico** escrito pelo profissional, avaliação do cliente e resposta. O profissional anexa o vídeo e o relatório na tela de evidências.

**Abertura, tema e navegação (ADR-0014, ADR-0015)**
- **Splash coreografada**: splash nativa (#1E3B70) → animação do símbolo (traço, brilho, nome, confetes) em 1,8 s → FadeOut. Inicialização **em paralelo** (`Future.wait`).
- **Tema Automático/Claro/Escuro** com **design tokens semânticos**, fundo #121212, elevação tonal e cores dessaturadas; contraste WCAG verificado por teste. Seletor em Perfil → Aparência.
- **Sessão no armazenamento seguro** (Keystore/Keychain), com migração sem deslogar e *fallback* para Login se corrompida; app abre offline com o perfil em cache.
- **Último perfil usado** (por conta): quem tem os dois perfis prontos abre direto no último.
- **Seleção de perfil redesenhada** (vidro/*glassmorphism*, sem clip-art): pílulas "Perfil Ativo", "Criar Perfil", "Termine o seu cadastro" e "Em análise"; seta de voltar.
- Painel do profissional: seta para voltar à seleção de perfil e card de **Saldo disponível**.

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
- **Avaliações v2** ([ADR-0011](adr/0011-avaliacoes-cegas-bayes-e-selos.md)): pílulas de contexto que mudam com a nota (1–3 ⭐ "O que deu errado?", 4–5 ⭐ "O que mais te impressionou?"); **avaliação bidirecional cega** (revelada quando as duas partes avaliam ou 48 h depois); **ranqueamento por Média Bayesiana** (`WR = v/(v+m)·R + m/(v+m)·C`, com peso de recência) calculado no banco; **selos automáticos** (Mestre da Organização, Sempre Pontual, Super Profissional…); **fotos "antes e depois"** com selo "Verificado" e aba "Fotos de clientes"; **direito de resposta** público (uma vez); **trava de retenção de crise** (garantia/suporte antes de publicar nota 1–2 com "Problema não resolvido"); reputação do cliente visível aos profissionais envolvidos; tela "Minhas avaliações" do profissional.
- Testes: `supabase/tests/review_system_smoke.sql` (30 asserções, `FALHAS=0`) e 44 testes unitários.
- **Conquistas do profissional** ([ADR-0012](adr/0012-conquistas-do-profissional.md)): 9 categorias × 10 níveis (**90 conquistas**) com limites 1, 10, 25, 50, 100, 500, 1.000, 2.500, 5.000 e 10.000 e metais Bronze → Diamante — serviços concluídos, avaliações 5 estrelas, pontualidade, organização, preço justo, qualidade do trabalho, cortesia, emergências e clientes recorrentes. Desbloqueio automático por *trigger* (idempotente, com notificação), medalhas vetoriais, tela **"Minhas conquistas"** (progresso por categoria), seção **"Conquistas"** no perfil público (visível ao cliente) e cartões de "Conquista desbloqueada" ao finalizar um serviço. Migration `20261023200000_achievements.sql`; testes `achievements_smoke.sql` (22) e `achievements_test.dart`; total de **55 testes unitários**.
- **[GAMIFICACAO](GAMIFICACAO.md)**: modelagem matemática do ranking (escolha de `m` por Bayes empírico, índice de confiança, multiplicador de SLA limitado, recência contínua), *unit economics* das recompensas financeiras com as premissas do Fluxo de Caixa (ligas, Cofre da Casa, Salva-Vizinho, Escudo), riscos jurídicos e plano de experimentos; simulação reproduzível em `scripts/sim-gamificacao.mjs`.
- `docs/README.md` (índice da documentação por assunto) e `scripts/check-md-links.mjs` (verificador de links, executado no CI).
- Entregáveis acadêmicos da **Etapa 3** (colaboradores): Projeto de Interface, Template/Design System, Arquitetura do Sistema, Análise de Ambientes/SWOT, Balanced Scorecard e Fluxo de Caixa (12 meses) com planilhas CSV.

### Alterado

- **(quebra de compatibilidade no banco)** FKs de `jobs.client_id/provider_id`, `payments.client_id/provider_id`, `reviews.reviewer_id` e `kyc_submissions.reviewed_by` agora são `ON DELETE SET NULL` e nuláveis (histórico da outra parte preservado ao excluir uma conta).
- `AppColors.*` e cores literais das telas migraram para `context.tk.*` (tokens); `PostAuthRouter`/`destinationFor` aceitam o último perfil usado; a carteira passa a descontar saques.
- Bucket `job-media` aceita `video/mp4` e `video/quicktime` (até 25 MB).
- Removidos os clip-arts `casa_lupa.png` e `caixa_ferramentas.png`.
- Login, cadastro e KYC rodam em `LightIsland` (tema claro) até migrarem aos tokens.
- **Organização do repositório:** a raiz passa a conter apenas o `README.md` (e a `LICENSE.md`, que o GitHub só detecta na raiz). `ARCHITECTURE`, `ROADMAP`, `CHANGELOG`, `SETUP` e `TESTING` foram para `docs/`; `CONTRIBUTING`, `SECURITY` e `CODE_OF_CONDUCT` para `.github/` (padrão de *community health files*). Todos os links entre documentos foram reescritos (78) e passam a ser verificados no CI.
- `ProviderCard.isSuper` passa a vir do selo concedido pelo banco (20 últimas avaliações nota 5), em vez da regra local "nota ≥ 4,8 com 10 avaliações"; a busca "Melhor avaliados" ordena pela nota Bayesiana (`rank_score`).
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
- Endereço completo e PIN em tabelas com política restritiva ([ADR-0007](adr/0007-privacidade-por-minimizacao-de-dados.md)).
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
