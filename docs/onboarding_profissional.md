# Documentação de Interface e Interação: Módulo de Verificação de Profissionais (Onboarding)

## 1. Visão Geral do Módulo

Este documento detalha a arquitetura visual e o fluxo de interação humano-computador (IHC) referente ao módulo de verificação de identidade e qualificação de profissionais da aplicação Desperrengue. O fluxo de _onboarding_ foi estruturado em cinco etapas sequenciais, minimizando a carga cognitiva do usuário através da segmentação de tarefas (micro-interações) e fornecendo visibilidade contínua do estado do sistema através de uma barra de progresso linear.

O repositório armazena os artefatos visuais de alta fidelidade no diretório `assets/images/hi-fi prototyping/1_Telas_de_verificacao_profissional/`.

---

## 2. Detalhamento das Interfaces de Captura e Validação

### 2.1. Etapa 1: Captura da Face Frontal do Documento de Identificação

A primeira interface do fluxo tem como objetivo a aquisição de dados biométricos e civis básicos do usuário[cite: 31].

![Etapa 1 - Frente do Documento](./assets/images/hi-fi%20prototyping/1_Telas_de_verificacao_profissional/1_verificacao_frente_documento.jpg)

**Análise de Usabilidade e Elementos de Interface:**

- **Visibilidade do Estado do Sistema:** O cabeçalho explicita "Etapa 1 de 5", acompanhado por uma barra de progresso fracionada, reduzindo a incerteza quanto à duração do processo[cite: 31].
- **Prevenção de Erros:** A área central apresenta uma representação gráfica (modelo mental) do documento de identidade brasileiro padrão, fornecendo um _affordance_ visual claro sobre o enquadramento esperado[cite: 31].
- **Controle e Liberdade do Usuário:** A interface disponibiliza dois métodos de _input_ distintos para o upload do artefato: seleção via sistema de arquivos local ("Galeria") ou acionamento do hardware de câmera ("Tirar Foto")[cite: 31]. O botão primário "Avançar" encontra-se inativo ou atua como validador da ação anterior.

### 2.2. Etapa 2: Captura do Verso do Documento de Identificação

A segunda interface mantém a consistência arquitetônica estabelecida na etapa anterior, focando na aquisição do verso do documento[cite: 32].

![Etapa 2 - Verso do Documento](./assets/images/hi-fi%20prototyping/1_Telas_de_verificacao_profissional/2_verificacao_verso_documento.jpg)

**Análise de Usabilidade e Elementos de Interface:**

- **Consistência e Padrões:** A disposição dos elementos de controle (botões de galeria e câmera) e a navegação permanecem inalterados, minimizando o tempo de aprendizado (_Learnability_)[cite: 32].
- **Instrucional Contextual:** O elemento gráfico central foi substituído pela representação do verso de um documento civil, enfatizando a presença da impressão digital e dos dados de filiação[cite: 32].

### 2.3. Etapa 3: Aquisição Biométrica Facial (Auto-retrato)

A terceira etapa destina-se à validação de vivacidade (_liveness detection_) e comparação biométrica com a documentação civil fornecida previamente[cite: 33].

![Etapa 3 - Auto-retrato](./assets/images/hi-fi%20prototyping/1_Telas_de_verificacao_profissional/3_verificacao_selfie.jpg)

**Análise de Usabilidade e Elementos de Interface:**

- **Restrição de Input:** Diferente das etapas 1 e 2, o sistema restringe intencionalmente o _input_ exclusivamente à captura em tempo real ("Tirar Foto"), omitindo a opção de galeria para assegurar a autenticidade da requisição e prevenir injeção de imagens estáticas[cite: 33].
- **Orientação ao Usuário:** A instrução em texto estabelece restrições claras para otimização do algoritmo de reconhecimento ("sem óculos, chapéu ou máscara"), acompanhada por um vetor gráfico que ilustra o alinhamento facial ideal[cite: 33].

### 2.4. Etapa 4: Validação de Credenciais Profissionais

A quarta interface transita da validação de identidade civil para a verificação de competência técnica, requerendo dados estruturados[cite: 34].

![Etapa 4 - Registro Profissional](./assets/images/hi-fi%20prototyping/1_Telas_de_verificacao_profissional/4_verificacao_registro_profissional.jpg)

**Análise de Usabilidade e Elementos de Interface:**

- **Componentes de Formulário:** A interface emprega um componente _Dropdown_ (menu suspenso) para a seleção padronizada do órgão emissor (ex: CREA, CFT, CNPJ), reduzindo a taxa de erros de formatação na base de dados[cite: 34].
- **Entrada de Dados Escalar:** Um campo de texto de linha única (_Single-line text input_) é disponibilizado para a inserção alfanumérica do registro[cite: 34].
- **Feedback de Ação:** O _Call to Action_ (CTA) primário sofre mutação semântica de "Avançar" para "Salvar e Avançar", indicando ao usuário que haverá uma persistência de dados no banco antes da transição para a próxima tela[cite: 34].

### 2.5. Etapa 5: Finalização e Submissão do Fluxo

A etapa derradeira conclui a esteira de interações e fornece o diagnóstico final do processo de _onboarding_[cite: 35].

![Etapa 5 - Finalização](./assets/images/hi-fi%20prototyping/1_Telas_de_verificacao_profissional/5_verificacao_finalizacao_envio.jpg)

**Análise de Usabilidade e Elementos de Interface:**

- **Feedback de Conclusão:** O sistema informa o sucesso do armazenamento transitório dos dados ("Seus dados foram salvos com sucesso")[cite: 35].
- **Gerenciamento de Expectativas:** A interface estabelece explicitamente o Acordo de Nível de Serviço (SLA) para a rotina de validação assíncrona executada pelo _back-office_, definindo o tempo de aprovação em até 48 horas[cite: 35].
- **Ação Definitiva:** O botão primário "Enviar para Análise" consolida o pacote de dados e finaliza o escopo de interação do usuário neste fluxo[cite: 35].

---

_Documento gerado para integração na arquitetura do repositório DesperrengueApp_TAI3[cite: 36]. A renderização correta das imagens assume que este arquivo `.md` está localizado no diretório `/docs` e os artefatos no respectivo subdiretório `/assets/images/hi-fi prototyping/1_Telas_de_verificacao_profissional/`._
