# Desperrengue — Telas comuns (fichas de UI/UX)

> Fonte: `docs/ui_ux/hi-fi_prototyping/`. Hex são aproximados (estimados visualmente). Mockups mostram o celular segurado por mão; o conteúdo útil é só a tela.
> Contexto: app Flutter; um mesmo usuário pode atuar como **cliente** OU **profissional** (seleção de sessão após login).

---

## BLOCO 0 — Login / Roteamento / Cadastro

### 0.1 `00_login_acesso.jpg`
1. **Propósito**: login por e-mail/senha ou social. Início da jornada, ator: ambos (usuário ainda sem sessão definida).
2. **Textos**: "Desperrengue" (logotipo/título); "Acesse sua conta"; placeholders "E-mail", "Senha"; link "Esqueci minha senha?"; botão "Entrar"; divisor "ou"; "Continuar com Google"; "Continuar com Apple"; rodapé "Não tem conta? **Cadastre-se**".
3. **Layout**: status bar; seta voltar (azul `<`) no topo-esq.; título grande "Desperrengue" centrado; subtítulo; campo E-mail (ícone envelope); campo Senha (ícone cadeado + olho riscado p/ mostrar/ocultar); link "Esqueci minha senha?" alinhado à direita; botão primário; divisor "— ou —"; botão Google (branco, borda cinza); botão Apple (preto); rodapé com link.
4. **Cores/raios**: fundo `#EEEEF2`; título/botão primário/seta azul `#0B4FA8`; subtítulo cinza `#555`; campos branco com borda `#9A9A9A`, raio ~12px; botão Entrar raio ~12px texto branco bold; Google branco borda `#DDD` raio ~12; Apple `#000` texto branco raio ~12; links azul-marinho `#0A2A6B`.
5. **Ações**: Voltar → tela anterior (splash/onboarding, a confirmar); Olho → alterna visibilidade da senha; "Esqueci minha senha?" → fluxo de recuperação (não prototipado); **Entrar** → autentica e vai a 01_b Seleção de sessão; Google/Apple → OAuth e depois seleção de sessão (ou cadastro se novo); "Cadastre-se" → 0.3 Cadastro dados básicos.
6. **Dados**: nenhum exibido; envia e-mail/senha ao Auth (Supabase/Firebase — a definir).

### 0.2 `01_b_selecao_de_sessao.jpg` (tela-chave)
1. **Propósito**: escolher o papel da sessão atual (cliente ou profissional) para o mesmo usuário. Logo após login/cadastro e ao trocar de perfil. Ator: ambos.
2. **Textos**: logotipo "Desperrengue" (ícone de seta/D estilizado + texto); "Olá, Ana!" / "Como você deseja usar o Desperrengue hoje?"; Card 1: "Preciso de um serviço" / "Encontre profissionais para resolver seu problema" / chip "Cliente"; Card 2: "Quero trabalhar" / "Acesse seu painel, veja pedidos e gerencie ganhos" / chip "Profissional".
3. **Layout**: logo topo-esq.; saudação em 2 linhas (grande, marrom); dois cards lado a lado, verticais: metade superior ilustração (casa com lupa / caixa de ferramentas), botão circular branco com seta `>` no canto inferior-dir. da ilustração, metade inferior branca com título bold, descrição, e na base um chip com avatar circular da usuária + rótulo do papel.
4. **Cores/raios**: fundo `#EEEFF3`; títulos/saudação marrom `#7A2E12`; card Cliente: topo verde `#5B7F5F`; card Profissional: topo terracota `#B05A35`; parte inferior branca `#FFFFFF`; raio dos cards ~32px; botão `>` círculo branco 48px, ícone na cor do card; chip Cliente azul-marinho `#1F3A66`, chip Profissional verde-escuro `#2F5A3C`, pílula (raio total) com avatar sobreposto à esquerda.
5. **Ações**: Card/seta/chip "Cliente" → Home do cliente (busca/nova demanda); Card "Profissional" → Painel do profissional (pedidos, ganhos). Se o usuário não tem perfil profissional → onboarding de profissional (não prototipado).
6. **Dados**: primeiro nome do usuário (`usuarios.nome`), foto de perfil (avatar), flags de papéis disponíveis (tem perfil cliente / profissional).

### 0.3 `01_cadastro_dados_basicos.jpg`
1. **Propósito**: criar conta nova. Jornada: onboarding. Ator: ambos (usuário novo, sem papel ainda).
2. **Textos**: "Desperrengue"; "Crie sua conta"; rótulos "Nome Completo", "E-mail", "Senha", "Confirmação de Senha"; placeholders "Digite seu nome completo", "Digite seu e-mail", "Crie sua senha", "Repita sua senha"; ajuda "Conter 8 caracteres. Use letras, caracteres especiais e números."; checkbox "Li e concordo com os **Termos de Uso** e **Política de Privacidade**"; botão "Cadastrar"; "Já tem uma conta? **Faça Login**".
3. **Layout**: botão voltar circular cinza topo-esq.; título + subtítulo centrados; 4 campos com rótulo acima e ícone à esquerda (pessoa, envelope, cadeado, cadeado; olho nos de senha); texto de ajuda sob Senha; checkbox marcado; botão primário largo; rodapé link.
4. **Cores/raios**: fundo branco `#FFFFFF`; título/botão/checkbox azul-marinho `#0F1B4C`; subtítulo cinza `#666`; campos borda `#C8C8CC`, raio ~10px; botão raio ~20px (quase pílula), texto branco bold; ajuda `#555` 11px.
5. **Ações**: Voltar → login; olho → mostra/oculta; links Termos/Política → páginas legais; **Cadastrar** (exige checkbox e validação) → 0.4 OTP; "Faça Login" → 0.1.
6. **Dados**: envia nome, e-mail, senha; aceite dos termos (versão + timestamp devem ser gravados). Regra de senha: ≥8 caracteres, letras, números e especiais.

### 0.4 `02_cadastro_verificacao_otp.jpg`
1. **Propósito**: verificar e-mail com código de 6 dígitos. Onboarding. Ator: ambos.
2. **Textos**: "Verifique seu e-mail"; "Digite o código de 6 dígitos enviado para o seu e-mail"; dígitos exemplo "1 2 3 _ _ _"; "Não recebeu o código?"; "Reenviar código (00:59)"; botão "Confirmar Código". (Rótulo da imagem: "Ecrã 2: 02_cadastro_verificacao_otp.jpg" — não é UI.)
3. **Layout**: seta voltar topo-esq.; título centrado; subtítulo 2 linhas; 6 caixas de dígito (4ª em foco com borda escura e cursor azul); texto "Não recebeu"; link reenviar com contador regressivo; botão fixo na base.
4. **Cores/raios**: fundo branco; título/botão azul-marinho `#0A2F63`; caixas borda `#D5D5DA`, foco borda `#0F1B4C`, raio ~10px, ~36×44px; botão raio ~8px.
5. **Ações**: Voltar → 0.3; digitar → avança foco (auto-submit opcional); Reenviar (habilitado após 0:00) → novo e-mail e reinicia 60s; **Confirmar Código** → 0.5 sucesso/roteamento.
6. **Dados**: e-mail destino (não aparece mascarado — sugerir exibir), token OTP, contador 60s.

### 0.5 `03_cadastro_sucesso_routing.jpg`
1. **Propósito**: confirmação transitória de cadastro + redirecionamento automático. Fim do onboarding. Ator: ambos.
2. **Textos**: "Conta criada!"; "Sua identidade digital no Desperrengue foi validada."; "Direcionando para a seleção de perfil...".
3. **Layout**: fundo branco, círculo azul com check branco (centro-alto); título; subtítulo 2 linhas; na base spinner circular + texto cinza pequeno.
4. **Cores**: círculo `#17407A` (~94px); título `#12315F` bold; subtítulo `#555`; spinner azul-marinho com trilho cinza; legenda `#888`. Sem botões.
5. **Ações**: nenhuma; auto-navega (~1,5–2s) → 0.2 Seleção de sessão.
6. **Dados**: nenhum (estado de sessão recém-criada).

---

## BLOCO 2 — Detalhes da Demanda (lado cliente)

### 2.1 `01_cliente_lista_orcamentos.jpg`
1. **Propósito**: demanda publicada + propostas recebidas; cliente compara e aceita. Momento: pós-publicação, pré-contratação. Ator: **cliente**.
2. **Textos**: header logo "Marketplace de Serviços" (sic na arte; usar logo Desperrengue) + "Detalhes do Serviço"; "Olá, Ana!"; card demanda: "Montagem de Estante de Livros" / "Instalação de estante de parede de 3 metros na sala de estar. Materiais fornecidos. Necessário ferramentas." / "Copacabana, Rio de Janeiro" / "Data publicado: há 2 dias" / "Aberto - Aguardando Propostas"; seção "3 Orçamentos Recebidos"; cards: Roberto Silva ★4.8 (95) R$ 180,00 "Consigo fazer na sexta pela manhã. Tenho todas as ferramentas necessárias." (selo "Profissional Verificado"); Carlos Santos ★4.5 (60) R$ 150,00 "Instalação rápida e limpa. Disponível quinta ou sexta."; Maria Oliveira ★4.9 (120) R$ 210,00 "Experiência com móveis de luxo. Garantia de 3 meses na instalação."; em cada: "Ver Perfil" (outline) e "Aceitar Proposta" (preenchido).
3. **Layout**: app bar (logo esq., título centro, avatar do usuário dir.); saudação; card da demanda (título bold, descrição, 3 linhas com ícone: pin, calendário, status com ponto verde); título da seção; lista vertical de cards de proposta: foto quadrada 96px (selo verde sobreposto na base) + nome/nota à direita, preço bold, mensagem; abaixo dois botões lado a lado.
4. **Cores/raios**: fundo `#EEF0F4`; cards branco, borda `#E3E6EB`, raio ~12–14px; azul primário `#1565C0`; botão outline borda `#1565C0` texto azul; selo `#3FA66B` texto branco; estrela `#F5B400`; botões raio ~8px.
5. **Ações**: avatar → perfil/menu; "Ver Perfil" → 2.4 perfil completo; "Aceitar Proposta" → 2.2 confirmação de aceite (do profissional escolhido); card de demanda → detalhes/edição (inferido).
6. **Dados**: nome do cliente; `demanda` (título, descrição, bairro/cidade, data de publicação relativa, status); contagem de propostas; por proposta: foto, nome, nota média, nº de avaliações, preço, mensagem, flag verificado. (Inconsistência: Roberto aparece com 95 aval. aqui, 125 em 2.2/2.3.)

### 2.2 `02_cliente_confirmacao_aceite.jpg`
1. **Propósito**: resumo antes de aceitar; explica próximos passos e custos. Ator: **cliente**.
2. **Textos**: título "Confirmação de Aceite"; "Olá, Ana!"; card: "Roberto Silva ★4.8 (95)" / "R$ 180,00" / "Total propostas: 125" / "Preço proposto: R$ 180,00" (selo "Profissional Verificado"); "Confirmação Detalhada"; card "Próximos Passos": "1. Agendar via Chat — Confirme a data e horário final com o Roberto."; "2. Pagamento Seguro — O valor é bloqueado no app até a conclusão do serviço."; "Resumo dos Custos" (sic "Resumo" grafado "Resumo"): "Serviço R$ 180,00"; "Taxa do App R$ 10,00"; "Custo Total R$ 190,00"; botão "Confirmar e Abrir Chat Seguro"; nota "*Este é um Mock de Checkout. O pagamento real será nas etapas seguintes."
3. **Layout**: app bar igual a 2.1; saudação; card do profissional; seção "Confirmação Detalhada" com card de passos numerados; seção de custos (linhas chave/valor, divisor, total bold); rodapé fixo com botão primário largo + nota pequena.
4. **Cores/raios**: igual 2.1; botão `#1565C0` raio ~8px, texto branco; rodapé branco fixo.
5. **Ações**: **Confirmar e Abrir Chat Seguro** → cria o vínculo (demanda → "profissional aceito") e abre 4.1 Chat; avatar → perfil. (Back do sistema → 2.1.)
6. **Dados**: profissional (foto, nome, nota, nº aval., nº "propostas" — ambíguo), valor do serviço, taxa do app (R$ 10,00 fixa ou %? a definir), total.

### 2.3 `03_cliente_status_servico_em_andamento.jpg`
1. **Propósito**: tela de status da demanda com profissional aceito; permite ver perfil e confirmar agendamento (mock). Ator: **cliente**.
2. **Textos**: "‹ Voltar"; "Detalhes do Serviço"; ícone engrenagem azul; "Olá, Ana!"; "Montagem de Estante de Livros" / descrição (arte com erros de texto: "estanto de paroda de 2 metros na sela de estar" — usar o texto correto de 2.1) / "Copacabana, Rio de Janeiro"; pílula "Em Andamento | Profissional Aceito"; card: "Roberto Silva" "(Eletricista/Encanador)" "★ 4,8 (125 avaliações)" "Valor Total: R$ 180,00" (selo "Profissional Verificado"); botões "Ver Perfil Completo" (outline) e "Confirmar Agendamento (Mock)".
3. **Layout**: app bar com voltar à esq. e engrenagem à dir.; avatares sobrepostos cliente→profissional com seta curva; "Olá, Ana!" centrado; card da demanda com pílula de status azul-claro; card do profissional; rodapé fixo com 2 botões empilhados.
4. **Cores/raios**: pílula fundo `#DCEAFB` texto `#1565C0` com check azul; resto como 2.1.
5. **Ações**: Voltar → lista; engrenagem → opções da demanda (cancelar/ajuda, não prototipado); "Ver Perfil Completo" → 2.4; "Confirmar Agendamento (Mock)" → 2.5 / 3.1 agendamento.
6. **Dados**: status da demanda (enum: aberto / em andamento…), profissional (foto, nome, categoria(s), nota, nº aval., valor total), cliente (foto).

### 2.4 `04_cliente_perfil_profissional_completo.jpg`
1. **Propósito**: perfil público completo do profissional (confiança) com atalho ao chat. Ator: **cliente** (vendo o profissional).
2. **Textos**: "‹" + "Perfil Completo de Roberto Silva" + engrenagem; selo "Verificado"; "Roberto Silva"; "(Eletricista/Encanador)"; "4.8 ★ (125 avaliações)"; pílula verde "Em Andamento | Profissional Azeito" (sic; correto: "Aceito"); "Sobre mim:" — "10+ Anos de Experiência", "Especialista Elétrico e Hidráulico", "Foco em Soluções Ágeis e Limpas"; "Testemunhos Recentes" (chips Maria G. ★★★★★, João ★★★★★, Pedro ★★★…) + "Maria G.: Instalação rápida e limpa! Recomendo muito." ★ 5 + link "Ver todas as avaliações"; "Trabalhos anteriores:" + link "Ver galeria completa" (4 miniaturas: estante, sifão, quadro elétrico, prateleiras); "Especialidades:" chips "Montagem de Móveis (Estantes, Armários)", "Elétrica Residencial", "Hidráulica & Reparos"; botão "Ir para Chat Seguro"; legenda "Combine os detalhes finais e o horário diretamente com o Roberto."
3. **Layout**: app bar (voltar, título, engrenagem); avatar circular 120px com selo "Verificado" no canto sup.-dir.; nome, categoria, nota; pílula de status; seções com rolagem; carrossel horizontal de depoimentos; faixa de 4 miniaturas; chips de especialidades com emoji/ícone; rodapé fixo com CTA + legenda.
4. **Cores/raios**: fundo branco; selo/pílula `#DDF3E4` texto `#1E7A3C`; CTA `#2B67B0` raio ~8px; links `#1565C0`; chips `#EEF0F3` raio ~16; miniaturas raio ~8; estrelas `#F5B400`.
5. **Ações**: voltar → 2.3/2.1; engrenagem (? ambíguo); "Ver todas as avaliações" → lista de avaliações; "Ver galeria completa" → galeria; **Ir para Chat Seguro** → 4.1 chat.
6. **Dados**: `profissional` (foto, nome, categorias, bio/destaques, anos de experiência, verificado), agregados de avaliação, avaliações recentes (autor, nota, texto), portfólio (fotos), especialidades, status da demanda.

### 2.5 `05_cliente_finalizar_agendamento_mock.jpg`
1. **Propósito**: tela pré-chat de confirmação de data/período + estimativa de custo (mock). Ator: **cliente**.
2. **Textos**: "Finalizar Agendamento"; "Roberto Silva"; chip "Aguardando Confirmação Final"; "1. Detalhes Operacionais": "Data Proposta: Sexta-feira, [Current Mock Date] (e.g., 25/09)", "Período: Manhã (e.g., 08h - 12h)", "Confirme ou ajuste estes detalhes no chat."; "2. Resumo de Custos (Estimativa Mock)": "Serviço (Roberto Silva) R$ 150,00", "Taxa (Plataforma Mock) R$ 10,00", "Custo Total Estimado R$ 160,00", "Este é um resumo estimado para sua referência. O custo final e o pagamento serão formalizados após o chat."; "Próximos Passos": "Revise os detalhes acima. Se tudo estiver correto, avance para o chat seguro para os últimos ajustes."; botão "Confirmar e Ir para Chat"; legenda "Página de confirmação pré-chat."
3. **Layout**: app bar (voltar, título, engrenagem); avatar 80px + nome + chip; dois cards numerados; bloco Próximos Passos; rodapé fixo CTA + legenda.
4. **Cores/raios**: fundo branco; cards `#F5F6F8` borda `#DDD` raio ~10px; ícones calendário/relógio azuis `#1565C0`; CTA `#2B67B0` raio ~8px.
5. **Ações**: voltar; **Confirmar e Ir para Chat** → 4.1 chat. (Placeholders literais "[Current Mock Date]" e "e.g." são marcações de protótipo — substituir por dados reais.)
6. **Dados**: profissional, data proposta e período (da proposta), valor serviço, taxa, total. ⚠ Valores divergem de 2.1–2.3 (R$150 vs R$180).

---

## BLOCO 3 — Agendamento e Checkout

### 3.1 `01_agendamento_selecao_data_hora.jpg`
1. **Propósito**: escolher data/horário com o profissional. Momento: após aceite, antes do pagamento. Ator: **cliente**.
2. **Textos**: "Agendar Serviço"; "Setembro 2026"; dias "D S T Q Q S S"; dias numerados 1–30 (arte tem erros: "22" repetido, "26" duplicado); "Horários Disponíveis (Sexta-feira, 25 Set)"; botões de hora 08:00, 09:00 (selecionado), 10:00, 11:00, 12:00, 13:00, 14:00, 15:00, 16:00 (+ linha cortada); "Resumo do Agendamento: Roberto Silva - R$ 180,00"; "Custódia Protegida: Liberado após conclusão."; botão "Agendar".
3. **Layout**: app bar (voltar, título centrado, avatar do profissional c/ ponto verde online); cartão de calendário com setas de mês `‹ ›`; grade 7 colunas de dias circulares; bottom sheet (alça) com título e grade 3 colunas de pílulas de horário; rodapé fixo com resumo + CTA.
4. **Cores/raios**: fundo `#F2F3F6`; dias passados cinza `#808080`; dias com pouca disponibilidade amarelo `#F3DB6B`; disponíveis azul-claro `#D9E3F7`; selecionado azul-marinho `#1F4E8C` com ponto abaixo; pílulas de hora outline azul-marinho raio total (~28px), selecionada preenchida `#3A6AA5`; CTA `#3A6AA5` raio ~8px.
5. **Ações**: setas mês; tocar dia → atualiza horários; tocar hora → seleciona; **Agendar** → 3.2 revisão/checkout.
6. **Dados**: disponibilidade do profissional por dia/hora (agenda), dias bloqueados/passados, profissional (foto, online), valor. Legenda de cores do calendário ausente (lacuna). Nota: mês "Setembro 2026" mostra 21–30 como futuros enquanto hoje seria ≈ 20.

### 3.2 `02_checkout_resumo_escrow.jpg`
1. **Propósito**: revisão final + explicação do escrow (custódia). Ator: **cliente**.
2. **Textos**: "Revisão do Agendamento"; "Revise os Detalhes"; "Roberto Silva" / "Especialização: Montador" (arte: "Especializaão"); "Serviço: Montagem de Estante"; "Data e Hora: Sexta, 25 Set @ 09h00"; "Previsão de Duração: 2h"; "Valor Total: R$ 180,00"; card "Pagamento Protegido Desperrengue: Custódia" / "Sua segurança acima de tudo." / "O valor total (R$ 180,00) ficará retido com segurança pela Desperrengue até que você aprove o serviço concluído no local. O profissional só recebe após o Handshake final."; "Revise as informações acima e continue para escolher como deseja realizar o pagamento em custódia."; botão "Escolher Forma de Pagamento"; chevron duplo ˄˄ abaixo.
3. **Layout**: app bar (voltar, título, avatar profissional); card de detalhes (avatar+nome+especialização; divisor; linhas chave/valor; divisor; total bold); card escrow teal com escudo/cadeado; texto; CTA.
4. **Cores/raios**: card detalhes `#F7F7F9` raio ~14px; card escrow fundo `#DDF2F2` borda `#9FCFCB` raio ~14px, escudo azul `#2B5C9A` + cadeado verde `#6BCB77`; CTA `#3A6AA5`.
5. **Ações**: voltar → 3.1; **Escolher Forma de Pagamento** → 3.3 input financeiro.
6. **Dados**: profissional, serviço, data/hora escolhidas, duração prevista, valor total.

### 3.3 `03_checkout_input_financeiro.jpg`
1. **Propósito**: pagamento do valor em custódia (PIX recomendado). Ator: **cliente**.
2. **Textos**: "Pagamento Seguro"; "Total a Pagar: R$ 180,00"; abas "Saldo em Conta" (badge "0"), "PIX (Recomendado)" (selecionada), "Cartão de Crédito" (logos Visa/Mastercard); card "Pagar com PIX Cópia e Cola"; código "00020101021126600014br.gov.bcb.pix012498dbf5-678c-4b5a-93be-3…"; botão "Copiar Código PIX"; "Cole o código no app do seu banco e pague."; card "Tempo Limite do Agendamento:" "14:59" "Seu horário ficará reservado por 15 minutos até a identificação do pagamento."; "O agendamento será confirmado automaticamente após o pagamento."; chevron ˅ no rodapé.
3. **Layout**: app bar (voltar, título, avatar profissional c/ ponto online); card total (label esq., valor bold dir.); segmented control de 3 métodos (ícone + rótulo); card teal do PIX (título, caixa do código truncado, botão, dica); card do cronômetro (ícone relógio azul à esq., contagem grande); texto final.
4. **Cores/raios**: fundo `#F0F1F5`; cards `#F7F7F9` raio ~14px sombra suave; aba selecionada `#3F6498` texto branco; card PIX `#D9F0EF` borda `#A5D3CF`; botão copiar `#3F6498` raio ~8px; relógio círculo `#3A6AA5`.
5. **Ações**: voltar → 3.2; trocar aba → Saldo (saldo 0, desabilitada na prática) / Cartão (formulário, não prototipado); **Copiar Código PIX** → copia para área de transferência (+ snackbar); polling/webhook de pagamento → 3.4 sucesso; expiração do cronômetro → libera o horário e volta a 3.1.
6. **Dados**: total, saldo da carteira, código PIX copia-e-cola (gerado pelo gateway), `expira_em` (15 min), status do pagamento.

### 3.4 `04_checkout_sucesso_handover.jpg`
1. **Propósito**: confirmação do pagamento em custódia e passagem ao chat. Ator: **cliente** (profissional recebe notificação equivalente — não prototipada).
2. **Textos**: "Desperrengue" (título); "Agendamento Confirmado"; "PAGAMENTO RECEBIDO!"; "Seu serviço com **Roberto Silva** está agendado:"; "Roberto Silva" / "Montagem de Estante"; "Sexta, 25 Set @ 09h00"; "Valor de **R$ 180,00** retido com segurança."; "Valor em custódia até a conclusão e sua aprovação."; botão "Abrir Chat com Roberto"; link "Voltar para o Início".
3. **Layout**: app bar (título central, avatar profissional); título; círculo verde 120px com check; "PAGAMENTO RECEBIDO!"; card (frase, avatar+nome+serviço, data/hora, valor); nota; CTA; link sublinhado.
4. **Cores/raios**: círculo `#3E9B58`; CTA `#3A5782` raio ~8px texto branco; card `#F5F3F6` raio ~14px; link `#2A2F6B` sublinhado.
5. **Ações**: **Abrir Chat com Roberto** → 4.1 chat; **Voltar para o Início** → Home do cliente.
6. **Dados**: profissional, serviço, data/hora, valor em custódia, id do pedido/escrow.

---

## BLOCO 4 — Chat pré-serviço

### 4.1 `01_chat_ativo_roberto.jpg`
1. **Propósito**: conversa cliente↔profissional após pagamento em custódia. Ator: **ambos** (aqui visão do cliente Ana).
2. **Textos**: "Desperrengue" (título); "Roberto Silva" + ponto online; ícone telefone "VoIP"; card info "Serviço: **Montagem de Estante** | Agendado: Sexta, 25 Set @ 09h00"; mensagem de sistema "Pagamento em custódia confirmado. Boa conversa!"; msg enviada (azul) "Oi Roberto, Ana aqui. Já cadastrei seu nome na portaria, bloco B, apto 102." 08:35h; msg recebida (cinza) "Olá Ana! Tudo certo. Estou no trânsito, chego em 10 minutos." 08:38h; input "Digitar mensagem...".
3. **Layout**: app bar (voltar, título, avatar do usuário logado); cabeçalho do contato (avatar 64px com online, nome bold, ponto verde, botão VoIP à dir.); card fixo de contexto do serviço; card de mensagem de sistema; bolhas (enviadas à direita, recebidas à esquerda) com hora abaixo; barra de composição: clipe, microfone, campo pílula, botão enviar circular.
4. **Cores/raios**: fundo `#EDEBF2`; bolha enviada `#3A5787` texto branco, raio ~20px (canto inferior-dir. reto); recebida `#C9C7CD` texto escuro, raio ~20px; cards de sistema `#F5F3F6` raio ~12px; botão enviar `#2F4A7C` círculo; horas `#777`.
5. **Ações**: voltar → lista de conversas / detalhe; VoIP → 4.2 chamada; clipe → anexos (foto, localização → 4.3); microfone → áudio; enviar → mensagem.
6. **Dados**: contato (foto, nome, presença), resumo do serviço (título, data/hora agendada), mensagens (texto, autor, timestamp), mensagens de sistema por evento (pagamento confirmado etc.).

### 4.2 `02_chat_chamada_voip.jpg`
1. **Propósito (esperado)**: chamada VoIP. **Conteúdo real**: é praticamente a MESMA tela de chat de 4.1, só com o nome "Wagner" no lugar de "Ana" nas mensagens ("Oi Roberto, Wagner aqui…" / "Olá Wagner! Tudo certo…"). **Não há UI de chamada** (sem botões de mudo/viva-voz/encerrar, sem cronômetro) — lacuna. Ator: ambos.
2. **Textos**: idênticos a 4.1 (substituir Ana→Wagner).
3–6. Mesmos de 4.1. Ação VoIP: apenas o ícone "VoIP" no cabeçalho inicia a chamada (destino: tela de chamada inexistente no protótipo).

