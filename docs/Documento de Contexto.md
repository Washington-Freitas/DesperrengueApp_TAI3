# Documento de Contexto

## 📌 Introdução

A prestação de serviços residenciais e de manutenção é um mercado com alta demanda constante, porém marcado por informalidade e fricção na conexão entre quem precisa de um serviço e quem o oferece. O aplicativo **Desperrengue** surge para intermediar essa relação de forma segura, digital e eficiente, modernizando a contratação de serviços autônomos.

## 🚨 O Problema

Atualmente, as maiores plataformas do mercado (como GetNinjas) utilizam modelos de negócios que punem o prestador de serviço: estes precisam comprar "moedas" ou créditos antecipadamente apenas para ter o direito de enviar um orçamento, sem qualquer garantia de fechamento do negócio. Para o cliente final, persiste a insegurança de colocar um desconhecido dentro de casa sem a devida triagem prévia.

## 💡 A Solução

Um aplicativo de marketplace mobile, com foco em serviços residenciais, baseado num modelo de "Oferta Direcionada". O cliente publica a sua necessidade (ex: vazamento hidráulico), e o algoritmo notifica os profissionais mais qualificados da região. Apenas os 3 primeiros profissionais podem enviar orçamentos gratuitamente. A plataforma garante segurança através de verificação documental dos profissionais (KYC) e rentabiliza a operação apenas retendo uma comissão (_Escrow_) caso o serviço seja de fato agendado e finalizado através do aplicativo.

---

## 📊 Lean Canvas

| Bloco do Canvas                | Descrição no Desperrengue                                                                                                         |
| :----------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| **1. Problema**                | Prestadores pagando para fazer orçamento sem garantia; Clientes com receio de contratar desconhecidos.                            |
| **2. Segmentos de Clientes**   | Proprietários de residências ou inquilinos que necessitam de manutenção; Profissionais autônomos.                                 |
| **3. Proposta de Valor (UVP)** | Contrate profissionais seguros. Para o prestador: Pague comissão apenas quando efetivamente fechar o serviço.                     |
| **4. Solução**                 | Match direcionado (até 3 orçamentos), verificação de documentos rigorosa (Supabase Auth) e retenção de comissão via app.          |
| **5. Canais**                  | Redes sociais, anúncios hiperlocais (Google Ads geolocalizado) e parcerias com síndicos e condomínios.                            |
| **6. Fontes de Receita**       | Comissão percentual sobre o valor total do serviço agendado, gerido através de pagamentos em custódia.                            |
| **7. Estrutura de Custos**     | Desenvolvimento e manutenção (Flutter), infraestrutura de nuvem (Supabase), marketing hiperlocal e taxas de Gateway de Pagamento. |
| **8. Métricas-Chave**          | Custo de Aquisição (CAC), Taxa de conversão de orçamentos (Match Rate) e Volume Bruto de Mercadorias (GMV).                       |
| **9. Vantagem Injusta**        | Eliminação total do risco financeiro para o trabalhador autônomo (não paga por leads) e foco em nicho hiperlocal inicial.         |

---

## 🧭 Missão, Visão e Valores

A nossa fundação estratégica garante que as operações e o desenvolvimento da plataforma estejam sempre alinhados com o objetivo de gerar valor real para a sociedade.

- 🎯 **Missão:** Democratizar e garantir segurança no acesso a serviços residenciais, valorizando o profissional autônomo através de relações comerciais mais justas e transparentes.
- 🔭 **Visão:** Ser o principal aplicativo de serviços domésticos do país, reconhecido por erradicar o pagamento injusto por leads e por ser o sinônimo de confiança para as famílias.
- ⭐ **Valores:**
  - **Justiça:** O profissional não deve pagar para tentar trabalhar.
  - **Confiança:** Segurança em primeiro lugar através da verificação documental de todos os usuários prestadores.
  - **Simplicidade:** Uma experiência de utilizador (UX) fluida e de alta performance, assegurada por uma arquitetura moderna (Flutter e Riverpod).
