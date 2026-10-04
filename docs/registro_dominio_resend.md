# Manual de Infraestrutura: Aquisição de Domínio e Integração SMTP
**Projeto:** Desperrengue App  
**Instituição:** PUC Minas (Ciência da Computação)  
**Domínio Oficial:** `desperrengue.tech`  

Este documento mapeia o procedimento técnico executado para a aquisição a custo zero de um domínio de Nível Superior (TLD) utilizando benefícios acadêmicos, seguido pela configuração da Zona DNS e blindagem do servidor de e-mails transacionais (Resend) para o funcionamento de OTPs e comunicações do sistema.

---

## Fase 1: Credenciamento Acadêmico (GitHub Student Developer Pack)
Para viabilizar a arquitetura sem custos iniciais (fase de MVP), utilizamos o ecossistema de benefícios do GitHub voltado para universitários.

1. **Acesso à Plataforma:** Acesso ao portal [GitHub Education](https://education.github.com/pack).
2. **Validação Institucional:** Autenticação utilizando as credenciais padrão do GitHub associadas ao e-mail institucional da PUC Minas (`@sga.pucminas.br`).
3. **Aprovação:** Verificação de elegibilidade acadêmica concluída, destravando o portfólio de parcerias para infraestrutura em nuvem.

---

## Fase 2: Aquisição do Domínio (.TECH Domains)
O TLD `.tech` foi estrategicamente escolhido para posicionar o Desperrengue como uma solução moderna e tecnológica no setor de serviços residenciais.

1. **Seleção do Provedor:** No painel de ofertas do GitHub, localizou-se o benefício do provedor **.TECH Domains** (1 ano de registro gratuito).
2. **Pesquisa e Checkout:** 
   - Consulta pela disponibilidade da marca `desperrengue`.
   - Adição do domínio `desperrengue.tech` ao carrinho.
   - O token de estudante aplicou automaticamente o desconto de 100%, reduzindo o valor de $12.99 para **$0.00**.
3. **Autenticação (Anti-Bot):** O provedor exige a inserção de um método de pagamento válido para processar o registro, mesmo com valor zerado.
   - 🛡️ **Dica de Segurança (Cartão Virtual):** Para garantir segurança financeira, foi utilizado um Cartão de Crédito Virtual de uso único/bloqueável gerado via aplicativo bancário.
4. **Prevenção de Cobranças Futuras:**
   - 🛡️ **Dica de Segurança (Auto-Renew):** Imediatamente após a emissão do recibo, acessou-se o painel da **Namify** (gestora da Radix/.TECH).
   - Na seção *Domain Information*, a chave de **Auto-Renew** foi alterada de *Enabled* para **Disabled**, garantindo que o cartão não sofra a cobrança de renovação automática no ciclo de 2027.

---

## Fase 3: Preparação da Zona DNS (Namify)
Com o domínio assegurado, o passo seguinte foi preparar a rota de comunicação para os servidores de e-mail.

1. **Acesso:** No painel da Namify, navegação até a aba **DNS** > **DNS Records**.
2. **Higienização:** O painel foi inspecionado para garantir a ausência de registros de estacionamento (*parking pages*) conflitantes. A interface "Add new record" foi utilizada para as injeções subsequentes.

---

## Fase 4: Blindagem e Integração SMTP (Resend)
Para garantir que os e-mails do sistema (ex: códigos OTP do Supabase Auth) cheguem à caixa de entrada do usuário sem serem retidos por filtros de *spam* do Gmail ou Outlook, configurou-se a autenticação criptográfica via Resend.

1. **Configuração de Origem:**
   - Criação de conta no [Resend](https://resend.com/).
   - Adição do domínio `desperrengue.tech`.
   - **Estratégia de Latência:** Seleção da região **São Paulo (sa-east-1)**, garantindo respostas de rede (ping) otimizadas para o público-alvo brasileiro.

2. **Injeção de Registos DNS:**
   As chaves geradas pelo Resend foram espelhadas manualmente na Zona DNS da Namify através de 4 registros críticos:

   * **Registo 1: DKIM (DomainKeys Identified Mail)**
     - *Type:* `TXT`
     - *Host name:* `resend._domainkey`
     - *Value:* Chave pública longa (`p=MIGfMA...wIDAQAB`)
     - *Objetivo:* Assinatura digital que garante que o e-mail não foi adulterado em trânsito.

   * **Registo 2: SPF (Sender Policy Framework) - Rota 1**
     - *Type:* `CNAME`
     - *Host name:* `rsend`
     - *Value:* `rsend-sae1.forge.rmta.net`
     - *Objetivo:* Autoriza os servidores do Resend a enviar e-mails em nome do domínio.

   * **Registo 3: SPF (Sender Policy Framework) - Rota 2**
     - *Type:* `CNAME`
     - *Host name:* `send`
     - *Value:* `send.forge.rmta.net`

   * **Registo 4: DMARC (Autenticação e Conformidade)**
     - *Type:* `TXT`
     - *Host name:* `_dmarc`
     - *Value:* `v=DMARC1; p=none;`
     - *Objetivo:* Instrução básica aos provedores de e-mail globais informando que a infraestrutura possui protocolos de segurança ativos.

3. **Validação de Propagação (TTL):**
   - Após salvar as configurações na Namify, o processo de verificação foi acionado no painel do Resend.
   - O período de *Time To Live* (TTL) de propagação global foi concluído com sucesso.
   - **Status Final:** O domínio alcançou o estado **"Verified"** em todos os selos (DKIM e SPF), liberando oficialmente o tráfego SMTP para o MVP.