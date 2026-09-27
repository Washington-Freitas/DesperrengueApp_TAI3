# Especificação do Projeto

## 1. Perfis de Usuários (Personas)

**👩 Persona 1: O Cliente (Ex: Ana)**

- **Perfil:** Mãe de família, trabalha fora o dia todo, reside num condomínio ou apartamento.
- **Necessidades:** Precisa resolver problemas domésticos (ex: consertar vazamentos, montar móveis) de forma rápida e pragmática.
- **Dores:** Tem medo de deixar estranhos entrarem em casa; não tem tempo para pesquisar dezenas de profissionais e negociar preços individualmente.

**👷 Persona 2: O Profissional (Ex: Carlos)**

- **Perfil:** Eletricista e encanador autônomo, 10 anos de experiência prática.
- **Necessidades:** Conseguir mais clientes na sua região sem precisar gastar dinheiro com publicidade incerta.
- **Dores:** Frustrado com aplicativos que cobram caro por "moedas" apenas para ele enviar um orçamento a clientes fantasmas ou que não respondem.

**👨‍💻 Persona 3: O Administrador (Equipe Interna)**

- **Perfil:** Gerente de Operações e KYC da Startup.
- **Necessidades:** Manter o nível de qualidade e segurança da plataforma.
- **Dores:** Dificuldade em escalar a aprovação de milhares de documentos e certidões sem ferramentas apropriadas e fluxos automatizados.

---

## 2. Histórias de Usuários (User Stories)

| ID    | Persona      | História (Eu quero...)                                                 | Motivo (Para que...)                                                                    |
| :---- | :----------- | :--------------------------------------------------------------------- | :-------------------------------------------------------------------------------------- |
| US-01 | Cliente      | ...publicar um problema com foto e categoria.                          | ...os profissionais entendam rapidamente o escopo do que eu preciso.                    |
| US-02 | Cliente      | ...receber no máximo 3 orçamentos gratuitos.                           | ...eu possa comparar preço e reputação sem lidar com leilões infinitos.                 |
| US-03 | Cliente      | ...pagar o serviço através de um sistema integrado no aplicativo.      | ...eu tenha a segurança de que o dinheiro será repassado corretamente via custódia.     |
| US-04 | Profissional | ...receber notificações de demandas urgentes na minha região.          | ...eu possa enviar propostas de forma ágil para serviços perto de mim.                  |
| US-05 | Profissional | ...enviar orçamentos gratuitamente (sem moedas).                       | ...eu só pague comissão caso o serviço seja efetivamente fechado.                       |
| US-06 | Profissional | ...enviar foto do meu documento e selfie para auditoria.               | ...eu possa receber o selo de profissional verificado e aumentar as minhas conversões.  |
| US-07 | Admin        | ...visualizar documentos enviados por novos profissionais no Supabase. | ...eu possa aprovar ou rejeitar o onboarding deles na plataforma, garantindo segurança. |

---

## 3. Requisitos Funcionais (RF)

| ID    | Descrição                                                                                                              | Prioridade |
| :---- | :--------------------------------------------------------------------------------------------------------------------- | :--------- |
| RF-01 | O sistema deve gerir sessões de utilizadores, diferenciando `role` de Clientes e Prestadores (via Supabase Auth).      | Alta       |
| RF-02 | O sistema deve permitir que o Cliente publique uma Demanda (Job) associada a uma categoria específica.                 | Alta       |
| RF-03 | O sistema deve permitir que Prestadores verificados enviem orçamentos (Quotes) para Demandas em aberto.                | Alta       |
| RF-04 | O sistema deve limitar e bloquear o envio de orçamentos após uma Demanda receber 3 respostas.                          | Média      |
| RF-05 | O sistema deve permitir ao Cliente aceitar um orçamento e transitar a Demanda para o status `in_progress`.             | Alta       |
| RF-06 | O sistema deve suportar um fluxo de aprovação de documentos armazenados no Supabase Storage.                           | Alta       |
| RF-07 | O sistema deve impedir (via RLS - Row Level Security) que Prestadores sem o status de verificação submetam orçamentos. | Alta       |

---

## 4. Requisitos Não Funcionais (RNF)

| ID     | Descrição                                                                                                                                    | Categoria       |
| :----- | :------------------------------------------------------------------------------------------------------------------------------------------- | :-------------- |
| RNF-01 | O aplicativo móvel deve ser desenvolvido no framework **Flutter (Dart 3.x)**, garantindo builds nativos e alta performance em iOS e Android. | Tecnologia      |
| RNF-02 | A gestão de estado global e injeção de dependências deve utilizar **Riverpod 2.x** para assegurar escalabilidade reativa.                    | Arquitetura     |
| RNF-03 | O back-end, banco de dados e autenticação devem assentar no ecosistema **Supabase (PostgreSQL 15+)**.                                        | Infraestrutura  |
| RNF-04 | As regras de segurança de nível de linha (**RLS** do PostgreSQL) devem impedir a visualização de orçamentos concorrentes.                    | Segurança       |
| RNF-05 | A navegação interna da aplicação deve ser feita via **GoRouter**, baseada no estado de autenticação reativo do utilizador.                   | UX / Tecnologia |

---

## 5. Restrições e Limitações do MVP

1. **Prazo Escopo MVP:** A primeira versão funcional (MVP) deverá ser concluída e entregue impreterivelmente até a primeira semana de Dezembro de 2026.
2. **Gateway de Pagamento:** O ambiente de pagamento no MVP será um Mock visual (simulação de Checkout/Handshake), não realizando integrações diretas com gateways reais (Stripe/Pagar.me) na primeira fase acadêmica.
3. **Escopo Geográfico:** A validação e métricas iniciais serão contidas de forma hiperlocal para facilitar a aquisição mútua de clientes e prestadores (Marketplace Liquidity).
4. **Recursos de Equipe:** O desenvolvimento técnico ficará sob responsabilidade de 1 desenvolvedor assistido por IA (AI Pair Programming), com 1 PO responsável pela estrutura de requisitos e regras de negócio.
