# Especificação do Projeto

## 1. Perfis de Usuários (Personas)

**Persona 1: O Cliente (Ex: Ana)**
- **Perfil:** Mãe de família, trabalha fora o dia todo, mora em apartamento.
- **Necessidades:** Precisa resolver problemas domésticos (ex: consertar vazamentos, montar móveis) de forma rápida.
- **Dores:** Tem medo de deixar estranhos entrarem em casa; não tem tempo para pesquisar dezenas de profissionais e negociar preços.

**Persona 2: O Profissional (Ex: Carlos)**
- **Perfil:** Eletricista e Encanador autônomo, 10 anos de experiência.
- **Necessidades:** Conseguir mais clientes na sua região sem precisar gastar dinheiro com publicidade incerta.
- **Dores:** Frustrado com aplicativos que cobram caro por "moedas" apenas para ele enviar um orçamento para um cliente que muitas vezes nem responde.

**Persona 3: O Administrador (Ex: Equipe Interna)**
- **Perfil:** Gerente de Operações da Startup.
- **Necessidades:** Manter o nível de qualidade e segurança da plataforma.
- **Dores:** Dificuldade em escalar a aprovação de milhares de documentos sem uma ferramenta apropriada.

---

## 2. Histórias de Usuários

| ID | Persona | História (Eu quero...) | Motivo (Para que...) |
|---|---|---|---|
| US-01 | Cliente | ...publicar um problema com foto e categoria | ...os profissionais entendam rapidamente o que eu preciso. |
| US-02 | Cliente | ...receber até 3 orçamentos gratuitos | ...eu possa comparar preço e reputação sem leilões infinitos. |
| US-03 | Cliente | ...pagar o serviço através do aplicativo | ...eu tenha a segurança de que o dinheiro será repassado corretamente. |
| US-04 | Profissional | ...receber notificações de demandas na minha região | ...eu possa enviar propostas apenas para serviços que me interessam. |
| US-05 | Profissional | ...enviar orçamentos gratuitamente | ...eu só pague comissão caso o serviço seja efetivamente fechado. |
| US-06 | Profissional | ...enviar foto do meu documento e selfie | ...eu possa receber o selo de profissional verificado. |
| US-07 | Admin | ...visualizar documentos enviados por novos profissionais | ...eu possa aprovar ou rejeitar a entrada deles na plataforma. |

---

## 3. Requisitos Funcionais (RF)

| ID | Descrição | Prioridade |
|---|---|---|
| RF-01 | O sistema deve permitir o cadastro de usuários diferenciando Clientes e Prestadores. | Alta |
| RF-02 | O sistema deve permitir que o Cliente publique uma Demanda (Job) associada a uma categoria (ex: Elétrica). | Alta |
| RF-03 | O sistema deve permitir que Prestadores enviem orçamentos (Quotes) para as Demandas em aberto. | Alta |
| RF-04 | O sistema deve limitar a 3 o número máximo de orçamentos recebidos por Demanda. | Média |
| RF-05 | O sistema deve permitir ao Cliente aceitar um orçamento, o que direcionará para um checkout (Mock) de pagamento. | Alta |
| RF-06 | O sistema deve conter um painel administrativo web para visualizar e aprovar documentos dos Prestadores. | Alta |
| RF-07 | O sistema deve impedir que Prestadores não aprovados enviem orçamentos. | Alta |

---

## 4. Requisitos Não Funcionais (RNF)

| ID | Descrição | Categoria |
|---|---|---|
| RNF-01 | O aplicativo móvel deve ser desenvolvido utilizando o framework React Native (Expo) para rodar nativamente em iOS e Android. | Tecnologia |
| RNF-02 | O back-end e o banco de dados devem utilizar a plataforma Supabase (PostgreSQL). | Arquitetura |
| RNF-03 | O sistema deve possuir tempo de resposta inferior a 2 segundos nas interações de tela, garantindo uma navegação fluida. | Desempenho |
| RNF-04 | As regras de segurança de nível de linha (RLS) do Supabase devem garantir que um cliente só veja seus próprios dados e os orçamentos que lhe foram enviados. | Segurança |

---

## 5. Restrições

1. **Prazo:** O MVP deverá ser concluído e entregue impreterivelmente até a primeira semana de Dezembro de 2026.
2. **Ambiente:** O ambiente de pagamento no MVP será um Mock (simulação), não processando cartões de crédito reais em ambiente de produção na primeira etapa.
3. **Equipe:** O desenvolvimento técnico ficará sob responsabilidade de apenas 1 desenvolvedor assistido por IA, com 1 PO estruturando as regras de negócio.
