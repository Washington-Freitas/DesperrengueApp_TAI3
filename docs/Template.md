# Template Padrão do Aplicativo (Design System) — Desperrengue

> **Escopo:** Este documento especifica o *Template Padrão* e o *Design System* do aplicativo móvel **Desperrengue**, detalhando os tokens de cores por modo de uso, a hierarquia tipográfica, o grid de espaçamentos, a iconografia e o catálogo de componentes reutilizáveis implementados em **Flutter** (`app/lib/core/ui/`).
> **Código-fonte de referência:** [`app/lib/core/ui/app_theme.dart`](../app/lib/core/ui/app_theme.dart) e [`app/lib/core/ui/widgets.dart`](../app/lib/core/ui/widgets.dart).

---

## 1. Filosofia de Design: Tematização Dinâmica por Modo (*Dual-Mode Theming*)

Durante a análise crítica dos protótipos de alta fidelidade (`docs/specs/`), identificou-se que os mockups originais apresentavam variações sutis de tons (quatro azuis e três laranjas distintos). Na implementação real em Flutter (`AppColors` e `AppTheme`), todos esses valores foram consolidados em um **sistema único de tokens semânticos**.

Como uma mesma conta de usuário pode alternar entre os papéis de **Cliente** e **Profissional** ([ADR-0005](./adr/0005-modelo-multi-modo-por-flags.md)), o `MaterialApp` observa reativamente a sessão (`AppSession.theme`) e aplica três variações de tema baseadas em **Material 3**:

1. **Tema Institucional / Marca (`AppTheme.brand()`):** Utilizado nas telas neutras de pré-sessão (Login, Cadastro, Verificação OTP, Seleção de Modo e Fluxo de KYC). Adota o **Azul Marinho (`#003366`)** para transmitir sobriedade jurídica e segurança institucional.
2. **Tema Modo Cliente (`AppTheme.forMode(UserMode.client)`):** Utilizado em toda a jornada de contratação. Adota o **Laranja Vibrante (`#F26B0F`)**, transmitindo agilidade, acolhimento residencial e resolução rápida de imprevistos ("desperrengues").
3. **Tema Modo Profissional (`AppTheme.forMode(UserMode.provider)`):** Utilizado no painel de trabalho, execução e carteira do prestador. Adota o **Azul Profissional (`#1B3A78` / `#5B8DE0`)**, transmitindo seriedade técnica, organização financeira e confiança operacional.

---

## 2. Paleta de Cores Oficial (`AppColors`)

Todos os códigos hexadecimais abaixo correspondem exatamente às constantes declaradas em [`app/lib/core/ui/app_theme.dart`](../app/lib/core/ui/app_theme.dart):

### 2.1. Cores Primárias e de Identidade por Modo

| Token no Código (`AppColors`) | Hexadecimal | Amostra / Uso Principal |
| :--- | :--- | :--- |
| `navy` | `#003366` | **Marca / Institucional:** Login, Cadastro OTP, Seleção de Modo e cabeçalhos de KYC. |
| `clientAccent` | `#F26B0F` | **Primária Modo Cliente:** Botões principais (CTAs), chips ativos, aba ativa e *steppers* do cliente. |
| `clientSoft` | `#FDE8D8` | **Superfície Suave Cliente:** Fundo de cartões de destaque ("Serviço em Andamento", banners promocionais). |
| `clientInk` | `#0B2A55` | **Contraste Cliente:** Títulos de alto destaque sobre superfícies claras no modo cliente. |
| `providerAccent` | `#1B3A78` | **Primária Modo Profissional:** Tema base, cabeçalhos, teclado numérico de PIN e cartão da Carteira. |
| `providerBright` | `#5B8DE0` | **Ação Modo Profissional:** Botões de ação rápida e destaques interativos no fluxo de execução. |
| `providerSoft` | `#E6EEFB` | **Superfície Suave Profissional:** Fundo de dicas técnicas, faixa de check-in GPS e cartões informativos. |

### 2.2. Cores Semânticas e de Confiança (Feedback de Sistema)

| Token no Código (`AppColors`) | Hexadecimal | Par de Fundo (`Soft`) | Significado Semântico na Interface |
| :--- | :--- | :--- | :--- |
| `success` / `successInk` | `#2FB67C` / `#0B5B3A` | `#E3F6EC` (`successSoft`) | **Sucesso e Pagamento Garantido:** Selo de profissional verificado, check de 4/4 evidências e confirmação de valor creditado. |
| `security` | `#2A7F86` | `#D6EFEF` (`securitySoft`) | **Custódia (*Escrow*) e Proteção:** Banners de "Pagamento Protegido Desperrengue" e retenção via Pix/Cartão. |
| `warning` / `warningInk` | `#E5C566` / `#7A4A0A` | `#FDEFC0` (`warningSoft`) | **Atenção e Mediação:** Chamados em disputa, alertas preventivos de segurança em campo e prazos expirando. |
| `danger` | `#C0262D` | `#FADADD` (`dangerSoft`) | **Erro Crítico / Ação Destrutiva:** Falha de validação de PIN, recusa de documento KYC, cancelamento e botão de pânico/problema. |
| `info` | `#1D6FE0` | `#DCEBFA` (`infoSoft`) | **Informação Operacional:** Tags de agendamento, instruções de SLA (2h para orçamento / 48h para KYC) e selos de verificação. |
| `star` | `#F5B400` | — | **Reputação:** Estrelas de avaliação (1 a 5) de clientes e profissionais. |

### 2.3. Tons Neutros e Estruturais

| Token no Código (`AppColors`) | Hexadecimal | Função Estrutural |
| :--- | :--- | :--- |
| `ink` | `#111827` | Texto principal de alta legibilidade (títulos, preços, rótulos de formulário) — contraste AAA sobre branco. |
| `muted` | `#6B7280` | Texto secundário, legendas, contadores de caracteres (`0/500`), datas relativas e *placeholders*. |
| `line` | `#E5E7EB` | Divisores (`Divider`), bordas sutis de cartões e contorno de chips inativos. |
| `surface` | `#F4F6FA` | Fundo secundário de seções agrupadas, áreas de rolagem e cartões neutros. |
| `scaffoldBackgroundColor` | `#FFFFFF` | Fundo padrão limpo de todas as telas para máxima legibilidade em ambientes externos. |

---

## 3. Tipografia e Hierarquia Visual

O aplicativo adota a família tipográfica nativa do **Material 3** (**Roboto** no Android e **SF Pro** no iOS), garantindo renderização nítida, carregamento instantâneo sem peso extra de assets e suporte completo à localização brasileira (`flutter_localizations` `pt_BR`).

| Nível Hierárquico | Tamanho (`sp`/`px`) | Peso (`FontWeight`) | Cor Padrão | Aplicação nas Telas |
| :--- | :--- | :--- | :--- | :--- |
| **Display / Cronômetro / Preço Hero** | `36` a `48` | `w800` (ExtraBold) | `ink` ou `providerAccent` | Valor do orçamento recebido (`R$ 150,00`), saldo da carteira e cronômetro de execução (`00:45:12`). |
| **Headline H1 (Título de Página)** | `22` a `26` | `w800` (ExtraBold) | `ink` | Saudações principais (`Olá, Ana! 👋`), títulos de conquista e telas de feedback final. |
| **AppBar Title (Cabeçalho)** | `18` | `w700` (Bold) | `ink` (`#111827`) | Título centralizado na barra superior de todas as telas internas. |
| **Section Title (H2)** | `16` a `18` | `w700` (Bold) | `ink` | Cabeçalhos de seções (`Categorias`, `3 Orçamentos Recebidos`, `Próximos Lançamentos`). |
| **Button Label (CTA)** | `15` a `16` | `w700` (Bold) | `#FFFFFF` / `accent` | Texto interno dos botões primários (`FilledButton`) e secundários (`OutlinedButton`). |
| **Body Regular** | `14` a `15` | `w400` / `w500` | `ink` | Descrições de problemas, mensagens de chat, bio do profissional e textos explicativos. |
| **Caption / Metadata** | `12` a `13` | `w500` / `w600` | `muted` (`#6B7280`) | Notas de rodapé, distância (`1,2 km`), tempo relativo (`Há 2 dias`) e protocolos (`#DSP-8492`). |

---

## 4. Layout, Grid, Raios de Borda e Espaçamentos

A estrutura espacial de todas as telas segue um grid consistente baseado em múltiplos de **4 px**:

* **Margens Horizontais de Tela (`Padding`):** `20 px` nas laterais em formulários e rodapés fixos (`BottomBar`); `16 px` em listagens densas de cartões.
* **Estrutura Padrão de Tela (`Scaffold`):**
  1. **Topo (`AppBar`):** Fundo branco (`#FFFFFF`), elevação `0` (`scrolledUnderElevation: 0`), título centralizado em negrito (`18 px`), botão de retorno à esquerda e ação contextual à direita (ex.: sino de notificações com contador em tempo real ou botão de ajuda).
  2. **Corpo Rolável (`SafeArea` + `ListView` / `SingleChildScrollView`):** Conteúdo organizado em cartões semânticos (`SectionCard`, `InfoBanner`) com espaçamento vertical padrão de `12 px` a `16 px` entre blocos.
  3. **Rodapé de Ação Fixa (`BottomBar`):** Barra inferior branca com borda superior `1 px` (`#E5E7EB`), `SafeArea` inferior e botão de chamada para ação (CTA) em largura total (*full-width*), acompanhado opcionalmente de nota legal/explicativa.
  4. **Navegação Principal (`NavigationBar`):** Presente nas telas raiz de cada modo (Home, Meus Pedidos/Oportunidades, Carteira e Perfil).
* **Raios de Arredondamento (`BorderRadius`):**
  * **Botões Primários e Secundários:** `28 px` (formato pílula / *stadium* — altura mínima de `54 px` para toque confortável em campo).
  * **Campos de Entrada (`TextField` / `InputDecoration`):** `14 px`, fundo branco, borda inativa `#D0D5DD` (`1 px`) e borda em foco na cor do modo (`1.8 px`).
  * **Cartões de Conteúdo (`SectionCard`) e Banners:** `16 px` a `20 px` com borda sutil `#E5E7EB`.
  * **Chips de Filtro e Status (`ChipTheme`):** `StadiumBorder` (pílula completa).

---

## 5. Catálogo de Componentes Reutilizáveis (`app/lib/core/ui/widgets.dart`)

Para garantir padronização visual e evitar duplicação de código entre os módulos de Cliente e Profissional, o projeto implementa uma biblioteca própria de *widgets* em [`app/lib/core/ui/widgets.dart`](../app/lib/core/ui/widgets.dart):

| Componente (Classe Dart) | Função no Template Padrão |
| :--- | :--- |
| **`PrimaryButton`** | Botão principal em formato pílula (`height: 54`), largura total, suporte a ícone frontal, seta traseira (`trailingArrow`) e *spinner* integrado durante requisições assíncronas (`loading: true`). |
| **`SecondaryButton`** | Botão contornado (`OutlinedButton`, `height: 50`) que herda automaticamente a cor de destaque do modo ativo (Laranja ou Azul). |
| **`LinkButton`** | Botão textual sublinhado para ações terciárias ou de saída (ex.: *"Cancelar Pedido"*, *"Ir para a Minha Carteira"*). |
| **`BottomBar`** | Contêiner de rodapé fixo com `SafeArea` e suporte a `footnote` (ex.: avisos de ambiente simulado de pagamento ou garantias de custódia). |
| **`StepHeader`** | Barra de progresso fracionada (*stepper* visual) utilizada no Assistente de Pedido (1/3 a 3/3) e no Onboarding KYC (1/7 a 7/7). |
| **`SectionCard`** | Cartão padrão branco com borda `#E5E7EB`, raio `16 px` e preenchimento interno padronizado para agrupar informações de demanda, profissional ou resumo financeiro. |
| **`InfoBanner`** | Faixa de destaque semântico (suporta tons `info`, `security`, `success`, `warning` e `danger`) com ícone à esquerda e texto explicativo (usada nos avisos de *Escrow*, Check-in GPS e Mediação). |
| **`StatusPill` / `VerifiedBadge`** | Pílulas compactas para exibição de status do chamado (`Aberto`, `Aguardando Pagamento`, `Em Execução`, `Em Mediação`) e selo azul/verde de *Profissional Verificado*. |
| **`CountdownRing`** | Anel gráfico animado (renderizado via `CustomPainter`) que exibe a contagem regressiva de 2 horas para recebimento de orçamentos ou 15 minutos para expiração do Pix. |
| **`RadarPulse`** | Animação concêntrica pulsante utilizada na tela de busca de **Emergência ("Para Agora")** com janela de 5 minutos. |
| **`PinPad`** | Teclado numérico customizado e caixas de 4 dígitos para validação presencial do código secreto de conclusão do serviço. |
| **`StarRatingBar`** | Componente interativo e de exibição para notas de 1 a 5 estrelas (`#F5B400`), utilizado nos cartões de busca e nas telas de avaliação pós-serviço. |
| **`EmptyState` / `ErrorState`** | Telas padronizadas para listas vazias, falhas de conexão ou estados sem resultados na busca, com ícone ilustrativo e botão de nova tentativa. |
| **`UserAvatar`** | Avatar circular com suporte a URL pública/assinada do Supabase Storage e fallback automático para as iniciais do usuário sobre fundo colorido. |

---

## 6. Iconografia e Recursos Gráficos

* **Biblioteca de Ícones:** Utilização padronizada do pacote oficial `Material Icons Rounded` (`Icons.*_rounded`), cujas terminações arredondadas harmonizam com os botões em pílula (`28 px`) e cartões (`16 px`).
* **Tratamento de Mídia e Privacidade (`app/lib/core/ui/media_widgets.dart`):**
  * Imagens públicas (avatares e portfólio em `public-media`) são carregadas diretamente com cache.
  * Imagens sensíveis (documentos de KYC em `kyc-documents` e fotos de problemas/evidências em `job-media`) são renderizadas exclusivamente através de **URLs assinadas temporárias** (*Signed URLs*) geradas sob demanda pelo `MediaService`.
* **Formatação Localizada (`app/lib/core/utils/format.dart`):**
  * Valores monetários sempre formatados no padrão brasileiro `R$ 150,00` (`brl()`).
  * Datas, horários e tempos relativos em português (`Há 2 horas`, `Quinta-feira, 15 de Outubro às 14:30`).
  * Distâncias geográficas padronizadas em quilômetros (`1,2 km`).
