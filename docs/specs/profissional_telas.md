# Desperrengue — Telas do PROFISSIONAL (análise UI/UX)

> Fonte: `docs/ui_ux/hi-fi_prototyping/profissional/*.jpg` (não existe 6.jpg) e `7_Gestao_de_Perfil_e_Gamificacao/`.
> Todas as telas são mockups de iPhone (status bar 09:41) sobre fundo bege. Cores em hex aproximado. Fonte de títulos: condensada (tipo Roboto Condensed Bold) azul-marinho; corpo: sans (Roboto/Inter).
> **Paleta comum:** primário azul `#5B8DE0` (botões), azul-marinho texto/título `#1B2F5E`, fundo `#FFFFFF`/`#FBFBF8`, cinza placeholders `#E5E5E8`, azul-claro de destaque `#E6EEFB`, verde sucesso `#2FB67C` (fundo `#E3F6EC`).

---

## 1.jpg — Serviço em execução (cronômetro)
1. **Propósito:** tela ativa durante o serviço, após check-in GPS no local. Momento: execução (meio da jornada).
2. **Textos:** logo "Desperrengue" (topo, centralizado, azul-marinho bold); sino com ponto vermelho; faixa "Check-in realizado via GPS ✔"; card verde "Pagamento Retido e Garantido: R$ 150,00"; cronômetro "00:45:12"; chip "● Serviço em execução..."; card cliente: "Cliente: Ana" / "Troca de Disjuntor Principal"; endereço "Rua Augusta, 1400, Apto 42" / "Consolação, São Paulo - SP" / "Ref: Portão de madeira ao lado da padaria"; botão "Finalizar Serviço".
3. **Layout:** app bar (logo central + ícone sino com badge vermelho à direita) → faixa azul-clara full-width com pin azul + texto + check verde → card verde com cadeado → cronômetro grande centralizado (HH:MM:SS, ~56sp bold) → chip pill azul-claro com bolinha → card branco (avatar circular da cliente + nome + serviço; sub-card com pin outline e endereço em 3 linhas) → rodapé fixo com botão largo. Sem bottom nav.
4. **Cores/raios:** faixa `#DDE9FA`; card pagamento borda/fundo `#E3F6EC`/`#2FB67C`, raio ~16; cronômetro `#1B2F5E`; chip borda `#8FB0EA` raio pill; cards raio ~20 borda `#E3E6EC`; sub-card endereço raio ~12 fundo `#F6F8FB`; botão `#5B8DE0` raio ~14, altura ~56.
5. **Ações:** "Finalizar Serviço" → tela 2 (Garantia e Portfólio); sino → notificações (não mostrada).
6. **Dados dinâmicos:** timestamp de check-in/estado GPS, valor retido (escrow) da proposta, tempo decorrido (desde check-in), nome/foto do cliente, título do serviço, endereço completo + referência, contagem de notificações não lidas.

## 2.jpg — Garantia e Portfólio (intro)
1. **Propósito:** tela explicativa antes das evidências; incentiva fotos/vídeo para garantia e portfólio público. Momento: pós-"Finalizar Serviço".
2. **Textos:** título app bar "Garantia e Portfólio"; headline "Mostre o seu talento para o mundo!"; corpo "As próximas 4 fotos e o vídeo de conclusão garantem a finalização do serviço e vão direto para o seu perfil público. Mostre o seu trabalho para fechar ainda mais clientes!"; dica "Dica: acenda as luzes, limpe a lente e mostre o antes/depois." (💡); botão "Tirar Fotos e Gravar Vídeo →".
3. **Layout:** app bar (seta voltar + título centralizado) → ilustração 3D (prancheta com foto, troféu dourado, estrelas, círculo azul claro ~170px) → headline grande centralizada (2 linhas, ~32sp bold condensada) → parágrafo centralizado → card dica (ícone lâmpada + texto) → botão primário full-width com seta.
4. **Cores/raios:** card dica `#E6EEFB` raio ~16; botão `#5B8DE0` raio ~14; troféu `#E8B23A`.
5. **Ações:** voltar → tela 1; "Tirar Fotos e Gravar Vídeo" → tela 3.
6. **Dados dinâmicos:** número de fotos exigidas (4) possivelmente configurável por categoria; resto estático.

## 3.jpg — Evidências do Serviço (checklist de fotos)
1. **Propósito:** hub com 4 slots obrigatórios + vídeo opcional. Momento: coleta de evidências.
2. **Textos:** app bar "Evidências do Serviço"; título "Capture as 4 fotos obrigatórias"; subtítulo "Fotos obrigatórias (0/4)"; slots "Visão Geral", "Detalhes da Peça", "Outro Ângulo", "Ambiente Limpo" (cada um com ícone câmera e "+"); card "Vídeo do funcionamento (Até 15s) - Opcional" (ícone câmera de vídeo); botão desabilitado "Finalizar Serviço →".
3. **Layout:** app bar (voltar + título) → título 2 linhas → contador → grid 2×2 de cards quadrados tracejados → card faixa azul-clara com ícone vídeo → rodapé fixo com botão desabilitado.
4. **Cores/raios:** slots fundo `#E5E5E8` borda tracejada `#B8BCC6` raio ~18; ícone câmera cinza `#8A8F9C`, "+" azul-marinho; card vídeo `#E6EEFB` raio ~16; botão desabilitado `#A9BEE5` texto branco.
5. **Ações:** tocar slot → câmera (tela 4, com índice correspondente); tocar card vídeo → gravação (provável tela 7+); "Finalizar Serviço" habilitado só com 4/4 → próxima etapa (tela de envio/conclusão).
6. **Dados dinâmicos:** miniaturas capturadas, contador n/4, estado do botão, rótulos dos slots (por categoria?), duração máxima do vídeo.

## 4.jpg — Câmera: Visão Geral (1 de 4)
1. **Propósito:** câmera guiada para a foto 1. Momento: captura.
2. **Textos:** app bar "Fotos do Serviço (1 de 4)", "Pular"; instrução "Enquadre a Visão Geral do local"; dica inferior "Busque mostrar todo o ambiente de trabalho."
3. **Layout:** tela cheia escura com preview da câmera (quadro de disjuntores) → app bar translúcida (voltar, título, "Pular" à direita) → título branco bold 2 linhas → moldura de enquadramento com cantos tracejados brancos (centro) → botão obturador circular branco (~80px) → dica em texto branco pequeno.
4. **Cores/raios:** overlay gradiente preto `#000000` ~60%; texto `#FFFFFF`; obturador anel branco; cantos da moldura raio ~20.
5. **Ações:** voltar → tela 3; "Pular" → próximo slot (inconsistente: slots são "obrigatórios"); obturador → captura e avança para 2 de 4.
6. **Dados dinâmicos:** índice atual/total, rótulo e dica por slot, feed da câmera.

## 5.jpg — Evidências do Serviço (4/4 completas)
1. **Propósito:** mesmo layout da 3.jpg, estado preenchido. Momento: evidências completas, pronto para finalizar.
2. **Textos:** "Evidências do Serviço"; "Capture as 4 fotos obrigatórias"; "✓ Fotos obrigatórias (4/4)" (verde); miniaturas com legenda "Visão Geral", "Detalhes da Peça", "Outro Ângulo", "Ambiente Limpo"; "Vídeo do funcionamento (Até 15s) - Opcional"; botão "Finalizar Serviço →" (habilitado).
3. **Layout:** igual à 3.jpg; cada slot = foto com gradiente escuro inferior, legenda branca na base, badge circular verde ✔ (canto sup. esq.) e botão circular claro com lixeira (canto sup. dir.). Card de vídeo agora cinza-claro `#EBEEF4` (sem estado "gravado" mostrado).
4. **Cores/raios:** contador `#1E8E4E`; badge `#2FA55A`; botão ativo `#5B8DE0` raio ~14; miniaturas raio ~18.
5. **Ações:** lixeira → remove foto e volta slot a vazio (4→3, botão desabilita); tocar miniatura → reabrir câmera/preview (suposição); card vídeo → gravação; "Finalizar Serviço →" → tela 7 (Liberar Pagamento).
6. **Dados dinâmicos:** URLs/thumbs das 4 fotos, estado por slot, contador, vídeo (se gravado).

## 7.jpg — Liberar Pagamento (PIN)
1. **Propósito:** validar conclusão com PIN de 4 dígitos informado pelo cliente (ou QR Code). Momento: encerramento/pagamento.
2. **Textos:** app bar "Liberar Pagamento"; título "Insira o código de liberação"; "Peça à Ana o PIN de 4 dígitos para validar a transação."; botão outline "Ler QR Code da Ana" (ícone QR); teclado 1–9, ⌫, 0; link vermelho sublinhado "Tive um problema / Ana não tem o código".
3. **Layout:** app bar (voltar + título) → título + subtítulo centralizados → 4 caixas de PIN (quadrados ~52px) → botão outline com ícone QR → teclado numérico customizado (grid 3 colunas, teclas pill; última linha: ⌫, 0, vazio) sobre fundo cinza-claro → link de ajuda no rodapé.
4. **Cores/raios:** caixas borda `#B8BCC6` raio ~12 fundo branco; botão QR borda/texto `#5B8DE0` raio ~12; teclas `#E5E7EB` raio pill, números `#1B2F5E` bold; link `#9B1C1C`.
5. **Ações:** 4º dígito correto → tela 8 (sucesso); QR → scanner (não mostrado); "Tive um problema…" → fluxo de disputa/suporte (não mostrado); voltar → tela 5.
6. **Dados dinâmicos:** nome do cliente, PIN esperado (validação servidor), tentativas/erros (sem estado de erro mostrado).

## 8.jpg — Serviço Finalizado e Pago!
1. **Propósito:** confirmação de sucesso e crédito na carteira. Momento: fim da execução.
2. **Textos:** logo "Desperrengue" + sino (sem badge); "Serviço Finalizado e Pago!"; "O código foi validado e suas fotos já estão no portfólio. R$ 150,00 foram adicionados com segurança à sua carteira!"; card "Seu novo saldo é de" "R$ 350,00" (ícone olho cortado); botão "Avaliar Atendimento da Ana →"; link "Ir para a Minha Carteira".
3. **Layout:** app bar igual à tela 1 → ilustração 3D escudo azul com check verde e confete → título → parágrafo → card verde-claro com saldo e toggle de ocultar → espaço → botão primário → link texto secundário.
4. **Cores/raios:** card `#E3F6EC` borda `#2FB67C` raio ~16; saldo `#0B5B3A` bold ~36sp; botão `#4A83E4` raio ~14; link `#1B2F5E`.
5. **Ações:** "Avaliar Atendimento da Ana" → tela 9; "Ir para a Minha Carteira" → carteira (provável tela 10+ / não mostrada); olho → oculta/mostra saldo.
6. **Dados dinâmicos:** valor creditado (R$ 150,00), saldo atualizado (R$ 350,00), nome do cliente, estado visível/oculto do saldo.

## 9.jpg — Avaliar Cliente (duas telas lado a lado: topo e rolagem)
1. **Propósito:** profissional avalia a cliente em 5 critérios + comentário. Momento: pós-pagamento.
2. **Textos (tela esq.):** app bar "Avaliar Cliente"; avatar; "Ana" "(Cliente)"; "Como foi sua experiência com a Ana?"; "Avalie a Ana nos 5 critérios abaixo para podermos finalizar."; card "* Todos os critérios são obrigatórios"; "Simpatia *" (6 estrelas desenhadas ✔), "Educação *" (4/5 ✔); rodapé "Role para baixo para continuar ▾". **Tela dir.:** "* Todos os critérios são obrigatórios"; "Recepção *" (4/5 ✔); "Comunicação *" (6 estrelas ✔); "Pontualidade *" (0/5, sem ✔); "Seção 2: Deixe um comentário (Opcional):"; textarea placeholder "Descreva como foi a recepção, o atendimento e a postura da cliente..."; erro vermelho "Selecione todos os critérios para enviar"; botão desabilitado "Enviar Avaliação 🔒".
3. **Layout:** app bar (voltar+título) → avatar circular 76px + nome + papel → título 2 linhas → subtítulo → card de critérios (cabeçalho cinza + linhas: ✔ + rótulo + * vermelho, linha de 5 estrelas, ✔ à direita quando avaliado) → label seção 2 → textarea → mensagem de erro → botão desabilitado fixo.
4. **Cores/raios:** estrelas `#F2B705` / vazias contorno `#B8BCC6`; ✔ `#1E8E4E`; * `#9B1C1C`; card raio ~16 borda `#D9DCE3`; botão desabilitado `#B8BCC6` raio ~14.
5. **Ações:** tocar estrela define nota; com 5 critérios preenchidos botão habilita → "Enviar Avaliação" → provável home/painel do profissional (não mostrado); voltar → tela 8.
6. **Dados dinâmicos:** nome/foto da cliente, 5 notas, comentário, validade do formulário.

## 10.jpg — Obrigado pela sua avaliação!
1. **Propósito:** confirmação pós-avaliação. Momento: fim do fluxo feliz.
2. **Textos:** logo "Desperrengue" + sino (preenchido, sem badge); "Obrigado pela sua avaliação!"; "Seu feedback ajuda a manter a comunidade da Desperrengue segura, transparente e justa para todos os profissionais."; botão "Buscar Novos Serviços →"; link "Ir para o Painel".
3. **Layout:** app bar (logo + sino) → ilustração (aperto de mãos com coração verde ✔ e confete) → título 2 linhas → parágrafo → espaço → botão primário → link texto azul.
4. **Cores/raios:** botão `#5B8DE0` raio ~14; link `#4A7FD6`; ilustração azul/verde.
5. **Ações:** "Buscar Novos Serviços" → feed/lista de oportunidades (não mostrado); "Ir para o Painel" → dashboard do profissional (não mostrado).
6. **Dados dinâmicos:** praticamente estática; notificações não lidas.

## 11.jpg — Garantia e Segurança (problema com o código)
1. **Propósito:** ramo de exceção a partir de "Tive um problema / Ana não tem o código" (tela 7). Tranquiliza o profissional e oferece chat com mediação. Momento: impasse no pagamento.
2. **Textos:** app bar "Garantia e Segurança"; "O seu dinheiro está 100% protegido."; "Identificamos o problema com o código. Fique tranquilo: como você está no local (confirmado via GPS), o valor de **R$ 150,00** da Ana está bloqueado em nosso sistema para garantir que você não saia no prejuízo."; alerta âmbar "Recomendamos que você saia do local em segurança. Não há necessidade de discussão. Nossa equipe de mediação assumirá o caso."; botão "Falar com a Mediação Agora (Chat)" (ícone balão).
3. **Layout:** app bar (voltar + título) → ilustração escudo azul com cadeado → título 2 linhas → parágrafo → card alerta (ícone escudo com "!") → rodapé fixo com botão.
4. **Cores/raios:** alerta fundo `#FBE8CC` texto `#8A5A12` raio ~16; botão `#5B8DE0` raio ~14.
5. **Ações:** botão → abre chat de mediação / tela 12 (Mediação em Andamento); voltar → tela 7.
6. **Dados dinâmicos:** valor retido, nome do cliente, status GPS confirmado.

## 12.jpg — Mediação em Andamento
1. **Propósito:** status do caso aberto; pagamento retido. Momento: pós-abertura de disputa.
2. **Textos:** título (sem voltar) "Mediação em Andamento"; "Pagamento retido para análise."; chip "Protocolo: #DSP-8492" + ícone copiar; "O saldo de **R$ 150,00** da Ana ficará rigorosamente bloqueado conosco. Todo o contexto do serviço, incluindo suas fotos e GPS, já estão seguros e salvos no seu **Histórico de Mediações**."; alerta amarelo "A equipe da Desperrengue assumiu este caso. Recomendamos que você saia do local em segurança. Deixe que nós resolvemos tudo por você."; botão "Acompanhar Caso no Chat →".
3. **Layout:** app bar só título → ilustração (escudo escuro, lupa e documento) → título → chip protocolo (pill cinza-azulado) → parágrafo centralizado com negritos → card alerta com ícone triângulo "!" → botão primário.
4. **Cores/raios:** alerta `#FDEFC0` borda `#E5C566` texto `#7A4A0A` raio ~16; chip `#E9EDF4` raio pill; botão `#4A83E4`.
5. **Ações:** copiar protocolo → clipboard; "Acompanhar Caso no Chat" → chat de mediação (não mostrado).
6. **Dados dinâmicos:** protocolo (#DSP-xxxx), valor retido, nome do cliente, status do caso, link para Histórico de Mediações.

## 13.jpg — Carteira
1. **Propósito:** saldo, atalhos financeiros e lançamentos futuros (inclui valor em mediação). Destino de "Ir para a Minha Carteira" (tela 8).
2. **Textos:** app bar "Carteira"; card "Saldo Disponível" "R$ 350,00"; atalhos "Pix", "Extrato", "Dados Bancários"; seção "Próximos Lançamentos"; item "→ Serviço Agendado (Amanhã)" "R$ 120,00" (verde); item destacado âmbar "⚠ Serviço: Ana (Em Mediação)" "R$ 150,00" "Protocolo: #DSP-8492".
3. **Layout:** app bar (voltar + título) → card de saldo com gradiente azul (~175px) → linha de 3 botões circulares com rótulo → título de seção → lista de lançamentos (linha simples + card de alerta). Sem bottom nav.
4. **Cores/raios:** card saldo gradiente `#2F5596`→`#1B3366` raio ~24, texto branco ~48sp bold; ícones em círculo `#E5E9F1` ícone `#1B2F5E`; valor verde `#1E7A45`; card mediação `#FDF1C8` borda `#E5C566` raio ~14.
5. **Ações:** Pix → saque/chaves Pix; Extrato → histórico; Dados Bancários → cadastro conta; tocar item mediação → tela 12/chat; voltar → tela anterior.
6. **Dados dinâmicos:** saldo disponível, lançamentos futuros (descrição, data relativa, valor), status do lançamento (agendado/em mediação), protocolo.

## 14.jpg — Carteira: Desempenho da Semana / Últimos Serviços
1. **Propósito:** continuação/rolagem (ou aba) da Carteira com faturamento semanal e histórico de serviços com portfólio. Momento: consulta pós-serviço.
2. **Textos:** app bar "Carteira"; "Desempenho da Semana"; card "Você já faturou **R$ 850,00** nesta semana" + gráfico de 5 barras; "Últimos Serviços Realizados"; item "✔ Troca de Disjuntor - Ana" "+ R$ 150,00" "Hoje, 14:30"; 4 miniaturas de fotos + ícone editar (bloco de notas com lápis); rodapé cinza "Problemas com seus repasses? Fale com a central."
3. **Layout:** app bar (voltar + título) → título de seção → card branco (texto à esquerda, mini-gráfico de barras à direita) → título de seção → item de lista (check verde, título, data/hora, valor verde alinhado à direita, fileira de thumbs 4 fotos + ícone de edição) → divisor → texto de suporte centralizado no rodapé. Sem bottom nav, sem rótulos de dias no gráfico.
4. **Cores/raios:** barras azul `#2F5596`, teal `#2A7F86`, verde `#1E9A55` sobre trilho `#E8ECF4`; valor `#1E7A45`; card raio ~16 borda `#E3E6EC`; thumbs raio ~8 (~42px).
5. **Ações:** ícone editar → editar portfólio/descrição do serviço (provável tela 7_Gestao 03); tocar item → detalhe do serviço; "Fale com a central" → suporte; voltar → tela 13.
6. **Dados dinâmicos:** total faturado semanal, série por dia, lista de serviços (título, cliente, data/hora, valor, status), URLs das fotos do portfólio.

## 15.jpg — Home do profissional: Serviços Próximos (mapa)
1. **Propósito:** dashboard/home com mapa de calor de demanda e card de oportunidade. Início da jornada (profissional Roberto online).
2. **Textos:** "Olá, Roberto"; "● Online"; balão no mapa "Alta demanda: +20% no valor base"; bottom sheet "Serviços Próximos"; card "💧 Emergência: Vazamento Intenso"; chip "Aguardando Avaliação"; "📍 Ana • A 2,3 km (Aprox. 8 min)"; "🔥 2 outros profissionais estão visualizando."; botão "Analisar Solicitação →".
3. **Layout:** header (avatar circular + saudação + status Online verde à direita; sem logo) → mapa cinza (ruas) com círculos concêntricos laranja/vermelho (hotspot), pin azul-marinho, rota azul-marinho da posição do profissional até o pin, botão flutuante "localizar" (alvo) à direita → bottom sheet arredondado com handle, título, card de serviço (ícone gota, título 2 linhas, chip âmbar, distância, divisor, linha de urgência laranja, botão azul full-width). Sem bottom nav visível.
4. **Cores/raios:** hotspot `#F4A15D`→`#E5583E`; chip `#FBE3B8` texto `#B26A00`; botão `#1E7BE6` raio ~12 (azul diferente dos demais `#5B8DE0`); sheet raio ~24 topo; card raio ~16; Online `#2FA55A`.
5. **Ações:** "Analisar Solicitação" → tela 16; toggle Online (provável tocar no status); botão alvo → recentralizar; arrastar sheet → lista de mais serviços.
6. **Dados dinâmicos:** nome/foto do profissional, status online, mapa/posição/rota, multiplicador de demanda (+20%), lista de chamados próximos (tipo/ícone, título, status, cliente, distância, ETA, nº de profissionais visualizando).

## 16.jpg — Detalhes do Chamado (enviar orçamento)
1. **Propósito:** analisar o pedido e enviar valor. Momento: pré-aceite.
2. **Textos:** app bar "Detalhes do Chamado"; "Evidências enviadas pela Ana" (carrossel horizontal de fotos/vídeo com play); "Relato da Cliente" (avatar + "O cano da pia estourou do nada e a água não para de sair. O registro principal está emperrado."); "Qual o seu orçamento para resolver isso?"; input "R$ 150,00" (cursor); "Observações (Opcional)" placeholder "Ex: Preço inclui a troca da junta, não inclui quebrar azulejo."; botão "Enviar Orçamento para Ana →".
3. **Layout:** app bar (voltar + título) → título de seção → carrossel de 3+ cards (raio ~12, 3º cortado, 2º com botão play) → título → bolha cinza com avatar + relato → pergunta em 2 linhas → campo valor grande centralizado com borda azul-marinho → label + textarea → rodapé fixo com botão.
4. **Cores/raios:** botão azul-marinho `#1B3A78` raio ~12 (diferente do azul-claro das outras telas); bolha `#E3E6EB` raio ~14; input borda `#1B2F5E` raio ~12; títulos de seção preto/azul-marinho.
5. **Ações:** tocar mídia → visualizador/player; "Enviar Orçamento para Ana" → tela 17; voltar → tela 15.
6. **Dados dinâmicos:** mídias do chamado (fotos/vídeo), relato, nome/foto do cliente, valor digitado (máscara BRL), observações.

## 17.jpg — Aguardando Resposta (timer de 5 min)
1. **Propósito:** espera da aprovação da proposta com contagem regressiva. Momento: pós-envio do orçamento.
2. **Textos:** título (sem voltar) "Aguardando Resposta"; "Orçamento de R$ 150,00 Enviado!"; "A Ana tem 5 minutos para aceitar a sua proposta. Se ela aceitar, o valor será retido no nosso sistema e você poderá ir até o local."; anel "Tempo restante" "04:59" "Aguardando aprovação..."; link "Cancelar Proposta" (vinho `#8A4B55`).
3. **Layout:** app bar só título → ilustração 3D avião de papel → título 2 linhas → parágrafo → anel de progresso (~150px, traço azul gradiente sobre trilho `#DCE4F2`) com tempo mono-condensado → link cancelar. Sem botões primários.
4. **Cores/raios:** anel `#2F6DB5`→`#1B3A78`; tempo `#333`; ilustração azul/teal.
5. **Ações:** "Cancelar Proposta" → cancela e volta à tela 15 (confirmar?); aceite da cliente → check-in GPS e tela 1; expiração → volta à 15 com aviso (não mostrado).
6. **Dados dinâmicos:** valor enviado, nome do cliente, tempo restante (servidor), estado da proposta (pendente/aceita/recusada/expirada).

---
# Pasta `7_Gestao_de_Perfil_e_Gamificacao` (estilo visual diferente: fundo cinza-claro `#EDEEEF`, iPhone com Dynamic Island, fonte Inter, azul-marinho `#0B3A6B`; as telas 1–17 usam fundo bege, notch e fonte condensada)
> Nota: `04_profissional_cofre_certificados.png` está na raiz da pasta 7, não na subpasta `Ecossistema_de_Validacao_Profissional` (esta contém `01_painel_de_conquistas_hub.jpg`, `02_trilha_de_conquistas_detalhe.jpg`, `03_modal_conquista_desbloqueada.png`, não analisados).

## P02 — 02_profissional_identidade_bio.jpg — Editar Perfil
1. **Propósito:** editar foto, bio e especialidades. Momento: gestão de perfil (pós-cadastro/qualquer momento).
2. **Textos:** app bar "Editar Perfil"; avatar com botão câmera; "Sobre Mim"; textarea placeholder "Descreva sua experiência em até 500 caracteres..." contador "0/500"; "Minhas Especialidades"; chips selecionados "✓ Elétrica", "✓ Hidráulica"; não selecionados "+ Pintura", "+ Encanad…", "+ Marcenaria", "+ En…", "+ Pedreiro", "+ Gesso", "+ Montagem…" (cortados na borda — wrap com overflow); botão "Salvar Alterações".
3. **Layout:** app bar (voltar + título) → avatar circular ~150px com FAB câmera azul-marinho no canto inferior direito → label → textarea (raio ~16, fundo `#E9EAEE`) + contador à direita → label → wrap de chips (3 linhas) → rodapé fixo botão full-width pill. Sem bottom nav.
4. **Cores/raios:** chip ativo `#0B3A6B` texto branco pill; chip inativo borda `#B8BCC6` texto `#333`; botão `#0B3A6B` raio pill (~28).
5. **Ações:** câmera → seletor de foto; chips → toggle; "Salvar Alterações" → grava e volta (destino: perfil).
6. **Dados dinâmicos:** foto, bio, contador de caracteres, catálogo de especialidades (do banco) e seleção do profissional.

## P03 — 03_profissional_gestao_portfolio.jpg — Meu Portfólio
1. **Propósito:** gerenciar mídia pública do portfólio (destino do botão editar da tela 14). 
2. **Textos:** app bar "Meu Portfólio"; "Mostre a qualidade do seu trabalho para atrair mais clientes."; selo verde "Último Trabalho" sobre capa em vídeo (play); "Trabalhos Anteriores"; thumbs com ações lápis/lixeira; card tracejado "+ Adicionar" (cortado); toast escuro "Comprimindo vídeo... 45%" (spinner).
3. **Layout:** app bar → subtítulo cinza → card hero (~330px, raio ~20, sombra, play central translúcido, selo canto sup. esq.) → seção "Trabalhos Anteriores" → carrossel horizontal de thumbs quadradas (~125px, raio ~14) com pílula branca [lápis | lixeira] no topo e card "+ Adicionar" tracejado → snackbar flutuante inferior preto `#333` raio ~14.
4. **Cores/raios:** selo `#139B72` raio ~8; título seção `#0B3A6B`; card adicionar borda tracejada `#9FB3C8` fundo `#EEF3F8`.
5. **Ações:** play → player; lápis → editar legenda/serviço; lixeira → excluir (confirmar); "+ Adicionar" → seletor foto/vídeo + compressão; voltar.
6. **Dados dinâmicos:** vídeo/foto do último trabalho, lista de portfólio, progresso de compressão/upload %.

## P04 — 04_profissional_cofre_certificados.png — Meus Certificados (cofre)
1. **Propósito:** cofre de certificações/registros com status de validação. 
2. **Textos:** app bar "Meus Certificados"; ícone escudo com check (halo azul); "Certificações Validadas"; "Aumente até 3x as suas chances de contratação provando as suas qualificações."; card 1 "Técnico em Eletrotécnica" "SENAI • Emitido em 2022" chip "✓ Verificado" (verde, barra lateral verde); card 2 "Engenharia Civil" "CREA-MG • Nº 123456..." chip "🕒 Em Análise" (âmbar); botão outline "+ Adicionar Registro ou Certificado"; nota "🔒 Os seus dados são encriptados de ponta a ponta e protegidos."
3. **Layout:** app bar (voltar + título pequeno) → escudo ~60px → título → subtítulo → lista de cards (ícone circular cinza medalha/carteira à esquerda, título, subtítulo, chip) → botão outline pill → nota de segurança pequena.
4. **Cores/raios:** card branco raio ~12 sombra leve, barra esquerda `#139B72` no verificado; chip verificado `#D7F5EA`/`#0F7A58`; em análise `#FDEBC8`/`#9A6200`; botão borda `#0B3A6B`.
5. **Ações:** tocar card → detalhe/arquivo; "+ Adicionar" → upload (câmera/arquivo); voltar.
6. **Dados dinâmicos:** lista de certificados (título, emissor, ano/nº de registro), status (Verificado / Em Análise / provavelmente Rejeitado), multiplicador "3x" (copy estática?).

---
# Análise final

## (a) Ordem provável da jornada e dependências
`15 Home (Serviços Próximos)` → `16 Detalhes do Chamado (orçamento)` → `17 Aguardando Resposta (5 min)` → *[aceite da cliente + check-in GPS, tela não mostrada]* → `1 Serviço em execução` → `2 Garantia e Portfólio` → `3 Evidências (0/4)` ⇄ `4 Câmera (n de 4)` → `5 Evidências (4/4)` → `7 Liberar Pagamento (PIN)` → `8 Serviço Finalizado e Pago` → `9 Avaliar Cliente` → `10 Obrigado` → (`15` via "Buscar Novos Serviços" ou Painel) ; `8`/`10` → `13 Carteira` → `14 Carteira/Desempenho` → editar → `P03 Portfólio`.
- **Ramo de exceção:** `7` → "Tive um problema / Ana não tem o código" → `11 Garantia e Segurança` → `12 Mediação em Andamento` → chat; reflete na `13 Carteira` (item "Em Mediação", protocolo #DSP-8492).
- **Perfil (pasta 7):** `P02 Editar Perfil`, `P03 Meu Portfólio`, `P04 Meus Certificados` acessados por Perfil/menu (tela de hub/perfil não mostrada); `P03` recebe as fotos geradas na tela 3–5.
- **Dependências:** 7 exige escrow ativo (valor de 17); 3–5 exigem check-in GPS (1); 8 exige PIN válido (7) e 4/4 fotos; 13 depende dos creditos de 8 e disputas de 12; 14 e P03 dependem de fotos das telas 3–5.

## (b) Componentes reutilizáveis
- `AppBarVoltarTitulo` (seta + título centralizado) e `AppBarLogoSino` (logo + sino com badge) e `AppBarSoTitulo` (12, 17).
- `BotaoPrimarioLargo` (rodapé fixo, com seta, estados habilitado/desabilitado) + `LinkTextoSecundario`.
- `CardAlerta` (variantes: verde sucesso/escrow, âmbar aviso, azul-claro dica) com ícone à esquerda.
- `IlustracaoHero3D + Titulo + Paragrafo` (telas 2, 8, 10, 11, 12, 17) — template de estado/feedback.
- `CardCliente` (avatar + nome + serviço + endereço) e `AvatarCliente`.
- `SlotFoto` (vazio tracejado / preenchido com ✔ e lixeira), `GridEvidencias 2×2`, `CardVideoOpcional`.
- `CameraGuiada` (moldura, obturador, dica, "Pular").
- `CampoPIN4` + `TecladoNumerico` + `BotaoQR`.
- `AvaliacaoEstrelas` (rótulo*, 5 estrelas, ✔) + `TextareaComContador`.
- `ChipStatus` (Online, Aguardando Avaliação, Verificado, Em Análise, Protocolo com copiar), `ChipEspecialidade` (toggle).
- `CardSaldo` (gradiente) + `AtalhoCircular` (Pix, Extrato, Dados Bancários) + `ItemLancamento` (normal / em mediação).
- `GraficoBarrasSemanal`, `ItemServicoRealizado` (+ thumbs de portfólio).
- `AnelContagemRegressiva` e `CronometroServico`.
- `MapaComHotspot` + `BottomSheetServicosProximos` + `CardChamado`.
- `CarrosselMidia` (foto/vídeo com play), `ThumbEditavel` (lápis/lixeira), `CardAdicionarTracejado`, `SnackbarProgresso`.
- `CardCertificado` (ícone, título, emissor, status, barra lateral).

## (c) Lacunas e inconsistências
1. **Sem 6.jpg:** falta provavelmente a tela entre 5 e 7 (ex.: confirmação de envio das evidências/upload de vídeo/exibição do PIN-QR para a cliente) — vídeo opcional nunca tem tela de gravação.
2. **Tela 7:** não há estado de erro de PIN, bloqueio por tentativas, nem scanner de QR; "Tive um problema" leva a 11 sem confirmação.
3. **Tela 8 vs 13:** o saldo R$ 350,00 aparece creditado em 8 (fluxo feliz) e em 13 após a mediação com R$ 150,00 retido — saldo e lançamento incoerentes entre ramos (350 inclui ou não os 150?).
4. **Telas 8/10 vs 12:** 12 diz "Histórico de Mediações" mas não há tela dele; sino/notificações, Painel, "Buscar Novos Serviços", chat de mediação, Pix, Extrato, Dados Bancários não existem.
5. **Navegação:** nenhuma tela mostra bottom nav/menu; falta hub de Perfil que leve a P02/P03/P04 e à Gamificação (subpasta Ecossistema_de_Validacao_Profissional).
6. **Botão "Pular" na câmera (4)** contradiz "fotos obrigatórias" e botão desabilitado até 4/4.
7. **9.jpg:** estrelas renderizadas com 6 em "Simpatia" e "Comunicação" (artefato do mock — usar 5); lista mostra apenas 5 critérios (Simpatia, Educação, Recepção, Comunicação, Pontualidade) distribuídos em duas telas — layout longo, sem indicação de progresso; tom "Recepção" repete "Simpatia"; placeholder do comentário fala de "recepção" (redundante).
8. **Estilos divergentes:** azul primário muda entre telas (`#5B8DE0` x `#4A83E4` x `#1E7BE6` x `#1B3A78`/`#0B3A6B`); fonte condensada (1–17) vs Inter (pasta 7); raio de botões (14 vs pill); sino com e sem badge; app bar com logo vs sem — precisa de design tokens únicos.
9. **Tela 1:** nome "Ana" (cliente) e "Roberto" (profissional) consistentes, mas 15 mostra emergência de vazamento e 1 "Troca de Disjuntor" — dados de exemplo distintos para a mesma Ana; valor 150 reaproveitado em 16/17/1/8/12/13/14.
10. **Tela 15:** badge "+20% no valor base" não é refletido na tela 16 (campo vazio sugerido/limites de preço?); falta tempo de expiração do convite, botão recusar e filtros; "2 outros profissionais visualizando" implica concorrência não explicada em 17 (e se a cliente aceitar outro?).
11. **Tela 17:** falta estado de recusa/expirado; "Cancelar Proposta" sem confirmação; anel mostra ~15% decorrido em 04:59 (inconsistente com 5 min).
12. **Tela 14:** mesmo título "Carteira" que 13 sem navegação entre elas (abas?); gráfico sem eixo/dias; "Hoje, 14:30" vs tela 1 em execução 00:45:12 às 09:41 (horário inconsistente).
13. **P04:** só dois status; sem rejeitado/expirado, sem estado vazio; "3x" é claim de marketing sem fonte; "Nº 123456..." truncado.
14. **P03:** banner de compressão sem cancelar; "Último Trabalho" sem associação clara a serviço; "Adicionar" cortado no carrossel.
15. Acessibilidade: textos cinza sobre fundo claro (placeholders, "Fale com a central") com baixo contraste; alvos pequenos (lixeira/lápis ~32px).
