# Desperrengue: Marketplace de Serviços Residenciais

Projeto acadêmico desenvolvido para as disciplinas de Trabalho Acadêmico Integrado, Engenharia de Software e Gestão de Startups. O **Desperrengue** é um aplicativo mobile focado em conectar clientes a prestadores de serviços de manutenção residencial com segurança, rapidez e um modelo de comissionamento justo (fim da cobrança por orçamentos).

## 📖 Documentação da Etapa 1

Toda a documentação acadêmica e de design exigida encontra-se estruturada na pasta `docs/`. Pode acessá-la diretamente pelos links abaixo:

- [📄 Documento de Contexto](./docs/Documento%20de%20Contexto.md) (Problema, Solução, Lean Canvas e Missão, Visão e Valores)
- [📋 Especificação do Projeto](./docs/Especificação%20do%20Projeto.md) (Personas, Histórias de Usuário, Requisitos Funcionais/Não-Funcionais e Restrições)
- [📱 Protótipos de Interface (UI/UX)](./docs/ui_ux/hi-fi_prototyping/) (Telas de Login, Autenticação e Fluxo de Agendamento)
- [💼 Plano de Negócio e Tributação](./docs/Planos%20de%20Negocio%20e%20Tributação.md) (Planejamento dos Planos de Negócio e Tributação)
- [🪪 Onboarding Profissional (KYC)](./docs/onboarding_profissional.md) · [✉️ Domínio e e-mail (Resend)](./docs/registro_dominio_resend.md)
- Ambiente de desenvolvimento: [Windows](./docs/setup/windows.md) · [macOS](./docs/setup/macos.md) · [Linux](./docs/setup/linux.md)

---

## 🛠️ Tecnologias Utilizadas (MVP)

A arquitetura do Desperrengue foi desenhada para garantir escalabilidade, segurança e desenvolvimento rápido (detalhes em [`app/README.md`](./app/README.md) e [`supabase/README.md`](./supabase/README.md)). As principais tecnologias escolhidas são:

- **Frontend Mobile:** Flutter (Dart 3.x)
- **Gestão de Estado:** Riverpod 2.x
- **Roteamento:** GoRouter
- **Backend (BaaS):** Supabase
  - **Database:** PostgreSQL com RLS (Row Level Security)
  - **Autenticação:** GoTrue Auth
  - **Armazenamento:** Supabase Storage
  - **Edge Functions:** Deno (envio de e-mail de aprovação via Resend)

> **Estado atual da implementação:** autenticação (e-mail/senha com OTP e Google), escolha de papel e o fluxo completo de KYC do profissional estão implementados. A navegação ainda usa `Navigator` com um `AuthGate` central; a migração para GoRouter e o uso mais amplo de Riverpod estão no roadmap.

## 🗂️ Estrutura do repositório

| Pasta | Conteúdo |
| :-- | :-- |
| `app/` | Aplicativo Flutter (`lib/`, `test/`, plataformas Android/iOS) |
| `supabase/migrations/` | **Fonte da verdade do banco** (schema, RLS, funções, storage) |
| `supabase/functions/` | Edge Functions (`enviar-email-aprovacao`) |
| `supabase/tests/` | Teste de fumaça de segurança do banco (SQL) |
| `docs/` | Documentação acadêmica, UI/UX e guias de ambiente |

## 🚀 Como rodar o app

```bash
cd app
flutter pub get
flutter run
```

Configuração opcional por `--dart-define` (os padrões apontam para o projeto Supabase do MVP):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=ABSTRACT_API_KEY=<opcional>   # validação extra de e-mail no cadastro
```

Verificação de qualidade: `flutter analyze` e `flutter test` devem passar sem avisos.

## 🔐 Segurança em resumo

- O status de verificação do profissional **não pode ser alterado pelo app** (permissão de coluna + trigger); só o servidor muda (RPCs/cron/admin).
- Documentos de KYC ficam num bucket **privado**, em pasta por usuário, e são lidos por _signed URL_.
- Regras de negócio críticas vivem no banco: máximo de **3 orçamentos** por demanda, só **prestador ativo** orça, aceite de orçamento atômico.
- Nenhum segredo é versionado. Chaves de terceiros entram por `--dart-define` ou como _secret_ do Supabase.
