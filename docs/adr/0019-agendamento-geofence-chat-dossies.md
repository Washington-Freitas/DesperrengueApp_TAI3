# ADR-0019 — Serviço agendado x em execução, dupla trava (horário + geofence), chat idempotente/arquivado e dossiês

* **Status:** Aceito
* **Data:** 2026-11-05
* **Decisores:** Desenvolvedor
* **Tags:** máquina de estados, geolocalização, tempo real, privacidade, UX
* **Relacionado:** altera o ciclo do [ADR-0006](0006-pagamento-mock-com-custodia-e-pin.md) (o pagamento deixa de iniciar o serviço), segue o [ADR-0003](0003-regras-de-negocio-no-banco-via-rpc.md) (regras no banco) e o [ADR-0007](0007-privacidade-por-minimizacao-de-dados.md) (privacidade)

## Contexto

Testes de campo com dois aparelhos (cliente e profissional) revelaram:

1. **Serviço agendado para 31/10 aparecia "em execução" em 29/10**, com cronômetro rodando e "Finalizar" liberado, longe da casa do cliente. O pagamento levava direto a `in_progress`.
2. **Chat com ordem invertida** (o `.order('created_at')` do `supabase_flutter` é *descendente* por padrão e a lista não era `reverse`), **mensagem duplicada** (sem idempotência de envio) e **cabeçalho com o e-mail do cliente** (`profiles.full_name` era um e-mail).
3. Falta de **dossiê** do serviço para o profissional (carteira e "Minhas avaliações") e de **histórico** com conversa arquivada para o cliente.
4. **Cortes de UI** (barra de navegação do Android) e telas de encerramento pobres ("Serviço finalizado" e "Obrigado pela sua avaliação").

## Decisão

1. **Novo estado `scheduled`** (`jobs.status`). `pay_job_mock` deixa serviços agendados em `scheduled` (emergência continua indo a `in_progress`, com `started_at` no aceite). **Só a RPC `start_job`** leva `scheduled → in_progress`. Como evidências, PIN e conclusão já exigiam `in_progress`, o servidor passa a **recusar finalizar um serviço que nunca começou** (falha fechada). Os pontos *permissivos* ganharam `scheduled`: bloqueio de exclusão de conta, abertura de chamado, agenda ocupada do profissional.
2. **Dupla trava no servidor** em `start_job(job, lat, lng, accuracy, simulate)`:
   * **Horário:** relógio do **servidor** (`now()`), a partir de **15 min antes** de `scheduled_for`. O app só antecipa a UI com um relógio sincronizado (`ServerClock`).
   * **Geofence:** distância de **Haversine** entre a posição enviada e o destino ≤ raio (**100 m**; **250 m** se o ponto veio só da rua; **0** se veio só do bairro/cidade, impreciso demais). Precisão do GPS > 100 m é recusada.
   * Erros tipados (`START_TOO_EARLY|iso`, `START_TOO_FAR|dist|raio`, …) viram mensagens claras no app. O início grava `started_at`, `start_distance_m` e `start_simulated`.
3. **Destino confiável (`job_geo`, privado), gravado só pelo CLIENTE.** Prioridade: **pino confirmado pelo cliente** (`set_job_location`, `client_pin`) > coordenadas do pedido > geocodificação **Nominatim feita no app do cliente** (`client_geocode`, com a qualidade `house`/`street`/`locality`, que define o raio). A geocodificação **não** roda no servidor: uma Edge Function testada em produção recebeu **403** do Nominatim público (bloqueia IPs de datacenter), então a função foi removida. Além disso o OSM não conhece muitas ruas brasileiras (a do teste só resolve até a cidade), por isso o **cliente confirma o pino no mapa** (OSM/CARTO + `flutter_map`); o app sempre incentiva isso enquanto o ponto não é um pino do cliente, e o pagamento notifica o cliente (`confirm_location`).
4. **Homologação:** `start_job(..., p_simulate := true)` ignora horário e GPS **somente** com `app_settings.checkin_sandbox = 'true'` (e o app mostra o botão "🧪 Simular dia/hora e GPS no local" com `CHECKIN_SANDBOX=true`). Em produção: desligar a flag e compilar com `CHECKIN_SANDBOX=false`.
5. **Mapa e rota 100 % gratuitos:** `flutter_map` com OpenStreetMap (claro) e CARTO Dark Matter (escuro); rota real nas ruas, distância e ETA pelo **OSRM** público; atalhos para Google Maps/Waze por `url_launcher`.
6. **Chat:** ordem `ASC` explícita; **idempotência** por `messages.client_message_id` (UUID v4 gerado no clique) + `UNIQUE (job_id, sender_id, client_message_id)`; UI otimista (🕒 → ✓✓) que **substitui** a mensagem pelo eco do banco, sem duplicar; `23505` = sucesso. **Arquivo morto:** gatilho recusa INSERT quando o serviço está `completed`/`canceled` (`CHAT_ARCHIVED`), mas o profissional contratado e o cliente continuam **lendo** (`can_chat` ampliado). Cabeçalho via RPC `chat_counterpart`.
7. **Dossiês privados** por RPC: `provider_job_dossier` (bruto, taxa, líquido, endereço, relatório, evidências, avaliação **respeitando a regra cega**: antes da revelação só informa que existe), `client_job_dossier` (valor pago, sem taxa/líquido) e `my_received_reviews` (com `job_id`, só para o dono). A visão pública (`public_reviews`) **não ganhou** `job_id` nem campo financeiro (verificado por teste em `information_schema`).
8. **Nomes seguros:** `safe_name()`/`_short_name()` no banco e `friendlyName()` no app trocam qualquer nome que pareça e-mail por "Cliente"/"Profissional".
9. **Telas finais:** *Serviço finalizado e pago* (SafeArea + rolagem + coluna de botões protegida, card de conquista com contraste WCAG e animação única) e *Obrigado pela sua avaliação* (`ReviewThanksView`, linha do tempo da avaliação cega), compartilhada por cliente e profissional.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| "Agendado" derivado de `started_at is null` (sem novo status) | Evidência/PIN/conclusão teriam de ganhar um *gate* extra em cada RPC; esquecer um abre brecha | Um status novo falha fechado: tudo que exige `in_progress` já recusa |
| Validar horário e GPS só no app | Relógio e GPS do celular são adulteráveis | O servidor decide; o app só antecipa |
| Geocodificar no servidor (Edge Function) | O Nominatim público devolve 403 a IP de datacenter (comprovado) | Geocodificação no app do **cliente** (dono do endereço, confiável) + pino |
| Aceitar coordenadas enviadas pelo profissional | Ele poderia "mover a casa" para onde está | Só o cliente dono grava (`set_job_location`) |
| Confiar apenas no Nominatim | OSM incompleto no Brasil → geofence inalcançável | Pino confirmado pelo cliente tem prioridade; `locality` não vale para validar |
| Pacote `uuid` para o `client_message_id` | Dependência para ~10 linhas | `Random.secure` + teste de formato/versão/variante |
| Google Maps SDK | Chave, cobrança, cota | OSM/CARTO/OSRM são gratuitos |

## Consequências

* (+) Serviço agendado não tem cronômetro nem "Finalizar" até estar **no horário e no local**; o servidor impõe, e há 183 asserções SQL cobrindo bordas (14/15/16 min, 99/101 m, raio de rua, sandbox ligado/desligado).
* (+) Chat sem duplicatas, na ordem certa e arquivado de forma segura; privacidade dos dossiês verificada.
* (−) O GPS vem do aparelho: um GPS falso (*mock location*) ainda engana o geofence. Mitigações futuras: Play Integrity e leitura de QR do PIN (ROADMAP).
* (−) O OSRM público é um servidor de demonstração (baixo volume); falhando, a UI mostra a distância em linha reta.
* (−) Aparelhos com versões anteriores do app tratam `scheduled` como "aberto" até atualizar (o aviso de atualização do beta resolve).
* (−) Antes de produção: desligar `checkin_sandbox`, avaliar um provedor de mapas/rotas com SLA e revisar a política de cancelamento de serviços `scheduled` pagos.

## Verificação

`supabase/tests/scheduled_start_smoke.sql` (183), `security_smoke.sql` (63, incl. início do serviço agendado), `test/scheduling_test.dart` (31), `test/geocode_test.dart` (12), `test/chat_test.dart`, `test/client_history_test.dart`, `test/dossier_test.dart`, `test/completion_redesign_test.dart`.

## Referências

* Migrations `20261030120000_scheduled_start_chat_dossier.sql`, `20261030130000_job_location_pin.sql` e `20261105100000_client_geocode_location.sql`.
* `app/lib/core/models/scheduling_models.dart`, `core/utils/geo.dart`, `core/services/scheduling_service.dart`, `features/shared/presentation/{scheduled_service_screen,service_map_widgets,chat_screen,review_thanks_view}.dart`.
* Nominatim Usage Policy; OSRM HTTP API; documentação do `flutter_map`.
