# Plano de Negócios: Desperrengue

Este documento detalha a estrutura financeira, tributária e o modelo de monetização do aplicativo Desperrengue, visando garantir a viabilidade e sustentabilidade do marketplace de serviços residenciais.

---

## 1. Estrutura de Custos e Investimentos

Para o planejamento financeiro, separamos a operação em dois cenários distintos: o cenário de validação (MVP) e o cenário de tração e escala.

### i) Cenário Lean (MVP / Validação Inicial)
Estrutura enxuta focada em validar a dor do mercado e o fluxo do aplicativo com o mínimo de recursos financeiros possível.

*   **Equipe (Sweat Equity):** 1 Desenvolvedor e 1 Product Owner (PO). Sem retirada de pró-labore nesta fase acadêmica/inicial.
*   **Infraestrutura e Nuvem:** 
    *   Supabase (Plano Pro/Hobby): ~US$ 25/mês (banco de dados, storage e auth).
*   **Publicação nas Lojas:**
    *   Apple Developer Program: US$ 99/ano.
    *   Google Play Console: US$ 25 (taxa única).
*   **Gateway de Pagamento:** Mock visual (simulação). Custo R$ 0,00 na fase acadêmica.
*   **Marketing:** Foco orgânico. Parcerias com síndicos de condomínios específicos e panfletagem digital em grupos de bairro (WhatsApp/Facebook). Verba de tráfego pago mínima (ex: R$ 300/mês no Google Ads hiperlocalizado).
*   **Estimativa de Custo Mensal:** Aproximadamente R$ 400 a R$ 600 mensais.

### ii) Cenário Ideal (Tração e Operação do Negócio)
Estrutura necessária após a validação do MVP, visando ganho de mercado, automação de processos de segurança e suporte a milhares de usuários.

*   **Equipe Remunerada:**
    *   Desenvolvedores (Mobile Flutter e Backend).
    *   Analista de Sucesso do Cliente / Suporte.
    *   Analista de KYC e Segurança.
    *   Especialista em Marketing/Growth.
*   **Infraestrutura e Ferramentas:**
    *   Supabase Enterprise ou migração para AWS estruturada.
    *   Integração com API de KYC automatizada (ex: idwall, CAF ou Truora) para verificação de antecedentes e documentos em tempo real.
*   **Gateway de Pagamento Real:** Integração completa com Stripe, Pagar.me ou Mercado Pago (split de pagamento e escrow). Custos em taxas por transação (aprox. 3% a 5% + taxa fixa por boleto/pix).
*   **Marketing Corporativo:** Investimento robusto em Google Ads, Meta Ads, SEO e programas de indicação (Referral).
*   **Estimativa de Custo Mensal:** R$ 50.000 a R$ 150.000+ mensais (dependendo do ritmo de contratações e verba de mídia).

---

## 2. Tributos e Precificação

### i) Enquadramento Tributário e Tributos Envolvidos
Como o Desperrengue atua conectando prestadores a clientes e retém um percentual dessa transação, o modelo de negócios caracteriza-se como **intermediação de negócios**.

*   **Natureza Jurídica Sugerida:** Sociedade Empresária Limitada (LTDA).
*   **Enquadramento Tributário Inicial:** **Simples Nacional**. É o regime mais vantajoso para startups em estágio inicial devido à unificação e simplificação no pagamento de impostos.
*   **CNAE Principal:** `7490-1/04 - Atividades de intermediação e agenciamento de serviços e negócios em geral, exceto imobiliários.` (Geralmente enquadrado no Anexo III ou V do Simples Nacional, dependendo do Fator R).
*   **Principais Tributos Envolvidos (Pagos via DAS - Documento de Arrecadação do Simples Nacional):**
    *   **ISS (Imposto Sobre Serviços):** Tributo municipal básico sobre a taxa de serviço (comissão) cobrada pela plataforma.
    *   **IRPJ (Imposto de Renda da Pessoa Jurídica)** e **CSLL (Contribuição Social sobre o Lucro Líquido)**.
    *   **PIS/COFINS:** Contribuições federais incidentes sobre o faturamento.
    *   *Nota:* A tributação incide **apenas sobre a comissão** (Take Rate) retida pelo Desperrengue, e não sobre o valor total do serviço (GMV), desde que o split de pagamento seja feito corretamente via Gateway.

### ii) Modelo de Precificação
A monetização do Desperrengue foi desenhada para ser justa e resolver a principal dor dos prestadores de serviço (que odeiam pagar por orçamentos não fechados).

*   **Modelo Escolhido:** **Comissionamento por Transação Concluída (Take Rate)**.
*   **Como Funciona:** O cadastro, a visualização de demandas e o envio de orçamentos são **100% gratuitos** para os profissionais aprovados.
*   **A Cobrança:** A plataforma cobra uma taxa fixa de **12% a 15%** (a definir após testes de sensibilidade de preço no MVP) sobre o valor total do serviço, **apenas se** o serviço for aprovado e pago pelo cliente através do aplicativo.
*   **Mecânica Escrow (Custódia):** O cliente paga o valor total via app (Cartão/Pix) no momento do aceite do orçamento. O dinheiro fica retido (custódia). Quando o serviço é finalizado e validado, o Gateway de pagamento divide os fundos automaticamente: o prestador recebe sua parte (85%) na sua conta bancária, e o Desperrengue recebe a sua comissão (15%). 