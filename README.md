# Desperrengue: Marketplace de Serviços Residenciais

Projeto acadêmico desenvolvido para as disciplinas de Trabalho Acadêmico Integrado, Engenharia de Software e Gestão de Startups. O **Desperrengue** é um aplicativo mobile focado em conectar clientes a prestadores de serviços de manutenção residencial com segurança, rapidez e um modelo de comissionamento justo (fim da cobrança por orçamentos).

## 📖 Documentação da Etapa 1

Toda a documentação acadêmica e de design exigida encontra-se estruturada na pasta `docs/`. Pode acessá-la diretamente pelos links abaixo:

- [📄 Documento de Contexto](./docs/Documento%20de%20Contexto.md) (Problema, Solução, Lean Canvas e Missão, Visão e Valores)
- [📋 Especificação do Projeto](./docs/Especificação%20do%20Projeto.md) (Personas, Histórias de Usuário, Requisitos Funcionais/Não-Funcionais e Restrições)
- [📱 Protótipos de Interface (UI/UX)](./docs/ui_ux/hi-fi_prototyping/) (Telas de Login, Autenticação e Fluxo de Agendamento)
- [💼 Plano de Negócio e Tributação](./docs/Planos%20de%20Negocio%20e%20Tributação.md) (Planejamento dos Planos de Negócio e Tributação)

---

## 🛠️ Tecnologias Utilizadas (MVP)

A arquitetura do Desperrengue foi desenhada para garantir escalabilidade, segurança e desenvolvimento rápido (conforme detalhado na nossa [Especificação Técnica](./build/desperrengue_app/README.md)). As principais tecnologias escolhidas são:

- **Frontend Mobile:** Flutter (Dart 3.x)
- **Gestão de Estado:** Riverpod 2.x
- **Roteamento:** GoRouter
- **Backend (BaaS):** Supabase
  - **Database:** PostgreSQL com RLS (Row Level Security)
  - **Autenticação:** GoTrue Auth
  - **Armazenamento:** Supabase Storage
