-- ============================================================================
-- DESPERRENGUE — Teste de fumaça: SERVIÇO AGENDADO (start_job: janela de horário +
-- geofence), PINO DE LOCALIZAÇÃO, CHAT idempotente/arquivado, DOSSIÊS e nomes seguros.
-- Migrations 20261030120000 e 20261030130000.
--
-- Transação SEMPRE abortada (nada é gravado). Relatório na mensagem do erro:
--   supabase db query --linked -f supabase/tests/scheduled_start_smoke.sql
-- Requer >= 5 linhas em public.profiles.
--   c = cliente   c2 = outro cliente (full_name com '@')
--   p1 = profissional contratado   p2 = outro profissional (full_name com '@')   p3 = terceiro
--
-- Relógio: dentro da transação now() é CONSTANTE, então as bordas da janela de 15 min
-- (14 / 15 / 16 min antes) são determinísticas. A numeração do relatório é automática.
-- ============================================================================
begin;

create temp table res (n serial, ok boolean, name text) on commit drop;
grant all on res to public;
grant all on sequence res_n_seq to public;

create function pg_temp.t(p_ok boolean, p_name text) returns void
language sql security definer as $$ insert into pg_temp.res (ok, name) values (coalesce(p_ok, false), p_name) $$;

create function pg_temp.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Executa um comando e devolve 'OK' ou 'SQLSTATE:mensagem' (sem abortar o teste).
create function pg_temp.try(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'OK';
exception when others then
  return sqlstate || ':' || sqlerrm;
end $$;

-- start_job que devolve 'OK' ou 'SQLSTATE:mensagem'.
create function pg_temp.ts(p_job uuid, p_lat double precision, p_lng double precision,
                           p_acc double precision, p_sim boolean) returns text language plpgsql as $$
begin
  perform public.start_job(p_job, p_lat, p_lng, p_acc, p_sim);
  return 'OK';
exception when others then
  return sqlstate || ':' || sqlerrm;
end $$;

-- Pedido do cliente c com o profissional p, ainda aguardando pagamento.
create function pg_temp.job(c uuid, p uuid, price numeric) returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  insert into public.jobs (client_id, title, description, category, urgency, provider_id, status, agreed_price)
  values (c, 'Serviço de teste', 'x', 'Elétrica', 'scheduled', p, 'awaiting_payment', price) returning id into j;
  return j;
end $$;

-- Pedido PAGO pelo cliente (-> scheduled + escrow) com horário combinado `sf`.
create function pg_temp.paid(c uuid, p uuid, price numeric, sf timestamptz) returns uuid
language plpgsql as $$
declare j uuid;
begin
  j := pg_temp.job(c, p, price);
  perform pg_temp.login(c);
  perform public.pay_job_mock(j, 'pix');
  execute 'reset role';
  update public.jobs set scheduled_for = sf where id = j;
  return j;
end $$;

do $$
declare
  ids uuid[]; c uuid; c2 uuid; p1 uuid; p2 uuid; p3 uuid;
  jm uuid; jap uuid; jg uuid; jg2 uuid; jst uuid; jsim uuid; jsim2 uuid; jem uuid; jx uuid; jy uuid; jr uuid; jh uuid; jb uuid;
  lat0 constant double precision := -23.5505;  lng0 constant double precision := -46.6333;   -- destino A
  lat1 constant double precision := -23.5605;                                                 -- pino B (1,11 km ao sul de A)
  v jsonb; d jsonb; r text; s text; n int; n0 int; n1 int; v_pin text; sf timestamptz; rid uuid;
  u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
  num numeric; st text; ps text;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 5 then raise exception 'TESTE ABORTADO: são necessários >= 5 perfis.'; end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3]; p3 := ids[4]; c2 := ids[5];

  -- ---------------------------------------------------------------- preparação
  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id in (c, c2);
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true where id in (p1, p2, p3);
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee)
    select id, array['Elétrica'], 30 from public.profiles where id in (p1, p2, p3);
  update public.profiles set full_name = 'Maria Souza'       where id = c;
  update public.profiles set full_name = 'cliente@email.com' where id = c2;
  update public.profiles set full_name = 'João Eletricista'  where id = p1;
  update public.profiles set full_name = 'prof@email.com'    where id = p2;
  update public.profiles set full_name = 'Pedro Terceiro'    where id = p3;
  insert into public.app_settings (key, value) values ('checkin_sandbox', 'true')
    on conflict (key) do update set value = 'true';

  -- ===== PAGAR -> AGENDADO =====
  jm := pg_temp.paid(c, p1, 150, now() + interval '2 days');
  select status, payment_status into st, ps from public.jobs where id = jm;
  perform pg_temp.t(st = 'scheduled' and ps = 'escrow', 'pagar serviço de urgência "scheduled" -> status scheduled + escrow (' || st || '/' || ps || ')');
  perform pg_temp.t((select amount = 150 and status = 'escrow' from public.payments where job_id = jm), 'pagamento fica em custódia (escrow) com o valor combinado (R$ 150)');
  select pin into v_pin from public.job_secrets where job_id = jm;
  perform pg_temp.t(v_pin ~ '^[0-9]{4}$', 'o PIN de 4 dígitos já nasce no pagamento');
  perform pg_temp.t((select started_at is null and not start_simulated and start_distance_m is null from public.jobs where id = jm),
                    'serviço agendado ainda não tem início real (started_at nulo, sem simulação/distância)');

  -- ===== ENQUANTO AGENDADO: nada de cronômetro, evidência ou conclusão =====
  perform pg_temp.login(p1);
  select count(*) into n from public.jobs where id = jm and started_at is null and status = 'scheduled';
  perform pg_temp.t(n = 1, 'profissional vê o serviço "scheduled" SEM started_at (sem cronômetro)');
  d := public.provider_job_dossier(jm);
  perform pg_temp.t(d ->> 'status' = 'scheduled' and (d ->> 'started_at') is null, 'dossiê do profissional agendado: status scheduled e started_at nulo');
  r := pg_temp.try(format('insert into public.job_evidence (job_id, provider_id, slot, path) values (%L,%L,%L,%L)', jm, p1, 'overview', p1::text || '/a.jpg'));
  perform pg_temp.t(r <> 'OK' and starts_with(r, '42501'), 'evidência RECUSADA enquanto o serviço está agendado (' || left(r, 40) || ')');
  r := pg_temp.try(format('select public.complete_job_with_pin(%L, %L)', jm, v_pin));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'complete_job_with_pin com o PIN CERTO recusado enquanto agendado');
  r := pg_temp.try(format('select public.complete_job_with_pin(%L, %L)', jm, '0000'));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'complete_job_with_pin com PIN errado também recusado enquanto agendado');
  reset role;
  perform pg_temp.t((select status = 'scheduled' and payment_status = 'escrow' and pin_attempts = 0 from public.jobs where id = jm),
                    'o serviço segue agendado, em custódia e sem tentativas de PIN gastas');

  -- ===== start_job: TRAVA TEMPORAL (relógio do servidor, janela de 15 min) =====
  perform pg_temp.login(p1);
  select scheduled_for into sf from public.jobs where id = jm;
  r := pg_temp.ts(jm, lat0, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_TOO_EARLY|' || to_char((sf - interval '15 minutes') at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                    'iniciar 2 dias antes: START_TOO_EARLY com o instante de abertura (' || r || ')');
  reset role;
  update public.jobs set scheduled_for = now() + interval '16 minutes' where id = jm;
  perform pg_temp.login(p1);
  r := pg_temp.ts(jm, lat0, lng0, 5, false);
  perform pg_temp.t(starts_with(r, 'P0001:START_TOO_EARLY|'), 'borda: 16 min antes ainda é cedo demais (' || r || ')');
  reset role;
  update public.jobs set scheduled_for = now() + interval '15 minutes' where id = jm;
  perform pg_temp.login(p1);
  r := pg_temp.ts(jm, null, null, null, false);
  perform pg_temp.t(r = 'P0001:START_NO_POSITION', 'borda: exatamente 15 min antes a janela JÁ abre (o erro passa a ser de posição)');
  reset role;
  update public.jobs set scheduled_for = now() + interval '14 minutes' where id = jm;
  perform pg_temp.login(p1);
  r := pg_temp.ts(jm, null, null, null, false);
  perform pg_temp.t(r = 'P0001:START_NO_POSITION', 'borda: 14 min antes a janela está aberta');

  -- ===== start_job: POSIÇÃO / PRECISÃO / DESTINO =====
  perform pg_temp.t(pg_temp.ts(jm, lat0, null, 5, false) = 'P0001:START_NO_POSITION', 'sem longitude -> START_NO_POSITION');
  perform pg_temp.t(pg_temp.ts(jm, 91, lng0, 5, false) = 'P0001:START_NO_POSITION', 'latitude fora de -90..90 -> START_NO_POSITION');
  perform pg_temp.t(pg_temp.ts(jm, lat0, 181, 5, false) = 'P0001:START_NO_POSITION', 'longitude fora de -180..180 -> START_NO_POSITION');
  r := pg_temp.ts(jm, lat0, lng0, 150, false);
  perform pg_temp.t(r = 'P0001:START_LOW_ACCURACY|150', 'precisão do GPS ruim (150 m) -> START_LOW_ACCURACY|150 (' || r || ')');
  r := pg_temp.ts(jm, lat0, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_NO_DESTINATION', 'sem destino conhecido -> START_NO_DESTINATION (' || r || ')');
  reset role;

  -- destino só por geocodificação da cidade/bairro: impreciso demais (raio 0)
  insert into public.job_geo (job_id, lat, lng, precision_level, source) values (jm, lat0, lng0, 'locality', 'nominatim');
  perform pg_temp.login(p1);
  r := pg_temp.ts(jm, lat0, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_DESTINATION_IMPRECISE', 'destino "locality" -> START_DESTINATION_IMPRECISE (mesmo estando em cima do ponto) (' || r || ')');
  v := public.job_destination(jm);
  perform pg_temp.t(v ->> 'precision' = 'locality' and (v ->> 'radius_m')::int = 0 and v ->> 'source' = 'nominatim', 'job_destination(locality): raio 0, origem nominatim');
  reset role;

  -- coordenadas do pedido têm prioridade sobre a geocodificação (raio 100 m)
  update public.jobs set latitude = lat0, longitude = lng0 where id = jm;
  perform pg_temp.login(p1);
  v := public.job_destination(jm);
  perform pg_temp.t(v ->> 'source' = 'client' and (v ->> 'radius_m')::int = 100 and v ->> 'precision' = 'exact',
                    'coordenadas do pedido vencem o job_geo "locality": origem client, raio 100');
  r := pg_temp.ts(jm, lat0 + 0.0045, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|500|100', 'a ~500 m do destino -> START_TOO_FAR|500|100 (' || r || ')');
  r := pg_temp.ts(jm, lat0 + 0.00135, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|150|100', 'a ~150 m (raio exato = 100 m) -> START_TOO_FAR|150|100 (' || r || ')');
  r := pg_temp.ts(jm, lat0 + 0.0045, lng0, 100, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|500|100', 'precisão de exatamente 100 m é aceita (cai na checagem de distância)');
  reset role;
  perform pg_temp.t((select status = 'scheduled' and started_at is null from public.jobs where id = jm), 'todas as recusas deixam o serviço "scheduled"');

  -- ===== QUEM PODE INICIAR =====
  perform pg_temp.login(p2);
  r := pg_temp.ts(jm, lat0, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'outro profissional não inicia o serviço (INVALID_STATE)');
  reset role;
  perform pg_temp.login(c);
  r := pg_temp.ts(jm, lat0, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'o cliente dono não inicia o serviço (INVALID_STATE)');
  r := pg_temp.ts(jm, null, null, null, true);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'o cliente também não inicia em modo simulado');
  reset role;
  perform pg_temp.login(c2);
  r := pg_temp.ts(jm, lat0, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'outro cliente não inicia o serviço (INVALID_STATE)');
  reset role;
  jap := pg_temp.job(c, p1, 60);
  perform pg_temp.login(p1);
  r := pg_temp.ts(jap, lat0, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'serviço ainda aguardando pagamento não pode ser iniciado');
  r := pg_temp.ts(jap, null, null, null, true);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'nem em modo simulado (precisa estar scheduled)');
  reset role;

  -- ===== PINO DE LOCALIZAÇÃO (set_job_location) =====
  perform pg_temp.login(p1);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jm, lat1, lng0));
  perform pg_temp.t(r <> 'OK' and starts_with(r, 'P0001:'), 'o profissional contratado NÃO altera a localização');
  reset role;
  perform pg_temp.login(p2);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jm, lat1, lng0));
  perform pg_temp.t(r <> 'OK' and starts_with(r, 'P0001:'), 'outro profissional NÃO altera a localização');
  reset role;
  perform pg_temp.login(c2);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jm, lat1, lng0));
  perform pg_temp.t(r <> 'OK' and starts_with(r, 'P0001:'), 'outro cliente NÃO altera a localização');
  reset role;
  perform pg_temp.login(c);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jm, 100, lng0));
  perform pg_temp.t(starts_with(r, '22023:'), 'coordenadas inválidas (lat 100) recusadas');
  v := public.set_job_location(jm, lat1, lng0);
  perform pg_temp.t(v ->> 'source' = 'client_pin' and (v ->> 'radius_m')::int = 100, 'o dono grava o pino: destino passa a origem client_pin, raio 100');
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jap, lat0, lng0));
  perform pg_temp.t(r = 'OK', 'o dono também ajusta o pino com o pedido aguardando pagamento');
  reset role;
  perform pg_temp.t((select source = 'client_pin' and precision_level = 'house' and lat = lat1 from public.job_geo where job_id = jm),
                    'job_geo foi SUBSTITUÍDO pelo pino (client_pin / house) e não duplicado');

  -- ===== job_destination: só as partes =====
  perform pg_temp.login(p1);
  v := public.job_destination(jm);
  perform pg_temp.t(v ->> 'source' = 'client_pin' and (v ->> 'lat')::double precision = lat1,
                    'o pino do cliente tem prioridade sobre as coordenadas do pedido (profissional vê client_pin)');
  select count(*) into n from public.job_geo where job_id = jm;
  perform pg_temp.t(n = 1, 'profissional contratado lê o job_geo do serviço (RLS)');
  r := pg_temp.ts(jm, lat0, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|1112|100', 'em cima das coordenadas ANTIGAS do pedido, mas longe do pino: START_TOO_FAR|1112|100 (' || r || ')');
  reset role;
  perform pg_temp.login(c);
  perform pg_temp.t(public.job_destination(jm) ->> 'source' = 'client_pin', 'cliente dono enxerga o destino');
  select count(*) into n from public.job_geo where job_id = jm;
  perform pg_temp.t(n = 1, 'cliente dono lê o job_geo');
  reset role;
  perform pg_temp.login(p3);
  perform pg_temp.t(public.job_destination(jm) is null, 'terceiro recebe NULL em job_destination');
  select count(*) into n from public.job_geo where job_id = jm;
  perform pg_temp.t(n = 0, 'terceiro não enxerga o job_geo (RLS)');
  reset role;
  perform pg_temp.login(p2);
  perform pg_temp.t(public.job_destination(jm) is null, 'outro profissional recebe NULL em job_destination');
  reset role;
  perform pg_temp.login(c);
  r := pg_temp.try(format('insert into public.job_geo (job_id, lat, lng, precision_level) values (%L, 1, 1, %L)', jap, 'house'));
  perform pg_temp.t(r <> 'OK' and starts_with(r, '42501'), 'o app não grava job_geo direto (só via set_job_location)');
  r := pg_temp.try('select public._job_destination(j) from public.jobs j limit 1');
  perform pg_temp.t(r <> 'OK' and starts_with(r, '42501'), '_job_destination (interna) não é chamável pelo app');
  reset role;

  -- ===== INICIAR DENTRO DO RAIO =====
  perform pg_temp.login(p1);
  v := public.start_job(jm, lat1 + 0.00045, lng0, 8, false);   -- ~50 m do pino
  reset role;
  perform pg_temp.t((v ->> 'ok')::boolean and not (v ->> 'simulated')::boolean and abs((v ->> 'distance_m')::numeric - 50) < 1.5,
                    'start_job a ~50 m do pino retorna ok, não simulado, distância ~50 m (' || (v ->> 'distance_m') || ')');
  perform pg_temp.t((select status = 'in_progress' and started_at = now() and not start_simulated
                            and start_distance_m between 48.5 and 51.5 from public.jobs where id = jm),
                    'serviço -> in_progress com started_at (relógio do servidor) e start_distance_m ~50');
  perform pg_temp.t((select count(*) from public.notifications where user_id = c and kind = 'service_started' and job_id = jm) = 1,
                    'cliente é notificado do início do serviço');
  perform pg_temp.login(p1);
  r := pg_temp.ts(jm, lat1, lng0, 5, false);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'iniciar DUAS vezes é recusado (INVALID_STATE)');
  r := pg_temp.ts(jm, null, null, null, true);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'reiniciar em modo simulado também é recusado');
  reset role;
  perform pg_temp.login(c);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jm, lat0, lng0));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'set_job_location recusado depois de in_progress (não "move a casa")');
  reset role;
  perform pg_temp.t((select lat = lat1 and source = 'client_pin' from public.job_geo where job_id = jm), 'o pino segue intacto após a tentativa recusada');

  -- ===== RAIO DE 250 m PARA "street" + atraso permitido =====
  jst := pg_temp.paid(c, p1, 100, now() - interval '1 hour');
  insert into public.job_geo (job_id, lat, lng, precision_level, source) values (jst, lat0, lng0, 'street', 'nominatim');
  perform pg_temp.login(p1);
  v := public.job_destination(jst);
  perform pg_temp.t((v ->> 'radius_m')::int = 250 and v ->> 'precision' = 'street', 'destino "street": raio de 250 m');
  r := pg_temp.ts(jst, lat0 + 0.0027, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|300|250', 'a ~300 m de um destino "street": START_TOO_FAR|300|250 (' || r || ')');
  v := public.start_job(jst, lat0 + 0.00135, lng0, 10, false);   -- ~150 m: dentro de 250, fora de 100
  reset role;
  perform pg_temp.t((select status = 'in_progress' and abs(start_distance_m - 150) < 2 from public.jobs where id = jst),
                    'a ~150 m inicia no destino "street" (raio 250); serviço atrasado (1 h) também pode iniciar');

  -- ===== GEOCODIFICAÇÃO FEITA PELO CLIENTE (client_geocode) + notificação confirm_location =====
  jg  := pg_temp.paid(c, p1, 100, now() + interval '10 minutes');
  jg2 := pg_temp.paid(c, p1, 100, now() + interval '10 minutes');
  perform pg_temp.t((select count(*) from public.notifications where user_id = c and kind = 'confirm_location' and job_id = jg) = 1,
                    'pagar serviço agendado notifica o CLIENTE para confirmar o local (confirm_location)');
  perform pg_temp.t((select count(*) from public.notifications where user_id = c and kind = 'confirm_location' and job_id = jm) = 1,
                    'confirm_location também foi criada no pagamento do serviço principal (1 por serviço)');
  perform pg_temp.t((select count(*) from public.notifications where user_id = p1 and kind = 'confirm_location' and job_id in (jg, jm)) = 0,
                    'o profissional NÃO recebe confirm_location (é pedido ao cliente)');
  -- quem não é o cliente dono não grava geocodificação
  perform pg_temp.login(p1);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'client_geocode', 'house'));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'profissional contratado não grava client_geocode (recusado)');
  reset role;
  perform pg_temp.login(p2);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'client_geocode', 'house'));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'outro profissional (terceiro) não grava client_geocode (recusado)');
  reset role;
  perform pg_temp.login(c2);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'client_geocode', 'street'));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'outro cliente não grava client_geocode (recusado)');
  reset role;
  perform pg_temp.t(not exists (select 1 from public.job_geo where job_id = jg), 'as tentativas recusadas não criaram job_geo');
  -- validações de origem/precisão
  perform pg_temp.login(c);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'nominatim', 'house'));
  perform pg_temp.t(r = '22023:Origem de localização inválida.', 'origem inválida (nominatim) -> 22023 (' || r || ')');
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'foo', 'house'));
  perform pg_temp.t(starts_with(r, '22023:'), 'origem inválida (foo) -> 22023');
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'client_geocode', 'bogus'));
  perform pg_temp.t(r = '22023:Precisão inválida.', 'precisão inválida em client_geocode -> 22023 (' || r || ')');
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, lat0, lng0, 'client_geocode', 'exact'));
  perform pg_temp.t(starts_with(r, '22023:'), 'precisão "exact" não existe para client_geocode -> 22023');
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg, 100, lng0, 'client_geocode', 'house'));
  perform pg_temp.t(starts_with(r, '22023:'), 'coordenadas inválidas com client_geocode -> 22023');
  reset role;
  perform pg_temp.t(not exists (select 1 from public.job_geo where job_id = jg), 'entradas inválidas não gravaram job_geo');
  -- geocodificação "street": raio 250 m
  perform pg_temp.login(c);
  v := public.set_job_location(jg, lat0, lng0, 'client_geocode', 'street');
  reset role;
  perform pg_temp.t(v ->> 'source' = 'client_geocode' and v ->> 'precision' = 'street' and (v ->> 'radius_m')::int = 250,
                    'client_geocode/street grava o destino com raio 250 (' || (v ->> 'source') || '/' || (v ->> 'precision') || ')');
  perform pg_temp.t((select source = 'client_geocode' and precision_level = 'street' and lat = lat0 and lng = lng0 from public.job_geo where job_id = jg),
                    'job_geo guarda source client_geocode e precisão street');
  perform pg_temp.login(p1);
  r := pg_temp.ts(jg, lat0 + 0.0027, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|300|250', 'geocodificação street: a ~300 m -> START_TOO_FAR|300|250 (' || r || ')');
  reset role;
  -- "locality": impreciso demais
  perform pg_temp.login(c);
  v := public.set_job_location(jg, lat0, lng0, 'client_geocode', 'locality');
  reset role;
  perform pg_temp.t(v ->> 'precision' = 'locality' and (v ->> 'radius_m')::int = 0, 'client_geocode/locality: raio 0');
  perform pg_temp.t((select count(*) from public.job_geo where job_id = jg) = 1 and (select precision_level from public.job_geo where job_id = jg) = 'locality',
                    'nova geocodificação atualiza o mesmo job_geo (sem duplicar)');
  perform pg_temp.login(p1);
  r := pg_temp.ts(jg, lat0, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_DESTINATION_IMPRECISE', 'geocodificação locality -> START_DESTINATION_IMPRECISE (' || r || ')');
  reset role;
  -- "house": raio 100 m
  perform pg_temp.login(c);
  v := public.set_job_location(jg, lat0, lng0, 'client_geocode', 'house');
  reset role;
  perform pg_temp.t(v ->> 'source' = 'client_geocode' and v ->> 'precision' = 'house' and (v ->> 'radius_m')::int = 100,
                    'client_geocode/house: raio 100 e origem client_geocode');
  perform pg_temp.login(p1);
  r := pg_temp.ts(jg, lat0 + 0.00135, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|150|100', 'geocodificação house: a ~150 m -> START_TOO_FAR|150|100 (' || r || ')');
  reset role;
  -- pino do cliente sobrescreve a geocodificação; geocodificação posterior NÃO sobrescreve o pino
  perform pg_temp.login(c);
  v := public.set_job_location(jg, lat1, lng0);
  reset role;
  perform pg_temp.t(v ->> 'source' = 'client_pin' and v ->> 'precision' = 'exact' and (v ->> 'radius_m')::int = 100,
                    'client_pin posterior sobrescreve a geocodificação (precision exact, raio 100)');
  perform pg_temp.t((select source = 'client_pin' and precision_level = 'house' and lat = lat1 from public.job_geo where job_id = jg),
                    'job_geo agora é client_pin/house no ponto do pino');
  perform pg_temp.login(c);
  v := public.set_job_location(jg, lat0, lng0, 'client_geocode', 'street');
  reset role;
  perform pg_temp.t(v ->> 'source' = 'client_pin' and (v ->> 'lat')::double precision = lat1, 'client_geocode posterior devolve o destino do pino (não sobrescreve)');
  perform pg_temp.t((select source = 'client_pin' and precision_level = 'house' and lat = lat1 and lng = lng0 from public.job_geo where job_id = jg),
                    'job_geo continua com o pino (client_geocode NÃO sobrescreveu)');
  perform pg_temp.login(c);
  v := public.set_job_location(jg, lat1, lng0, 'client_pin', 'street');
  reset role;
  perform pg_temp.t((select precision_level from public.job_geo where job_id = jg) = 'house' and v ->> 'precision' = 'exact',
                    'client_pin força precisão house (ignora a precisão informada)');
  -- início real com geocodificação street
  perform pg_temp.login(c);
  perform public.set_job_location(jg2, lat0, lng0, 'client_geocode', 'street');
  reset role;
  perform pg_temp.login(p1);
  r := pg_temp.ts(jg2, lat0 + 0.0027, lng0, 10, false);
  perform pg_temp.t(r = 'P0001:START_TOO_FAR|300|250', 'client_geocode/street: ~300 m recusado (START_TOO_FAR|300|250)');
  v := public.start_job(jg2, lat0 + 0.00135, lng0, 10, false);   -- ~150 m
  reset role;
  perform pg_temp.t((select status = 'in_progress' and not start_simulated and abs(start_distance_m - 150) < 2 from public.jobs where id = jg2),
                    'client_geocode/street: início a ~150 m aceito (raio 250), start_distance_m ~150');
  perform pg_temp.login(c);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s, %L, %L)', jg2, lat1, lng0, 'client_geocode', 'house'));
  r := r || '|' || pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jg2, lat1, lng0));
  reset role;
  perform pg_temp.t(r ~ '^P0001:.*\|P0001:', 'após in_progress, client_geocode e client_pin são recusados');
  perform pg_temp.t((select source = 'client_geocode' and precision_level = 'street' and lat = lat0 from public.job_geo where job_id = jg2),
                    'após in_progress o job_geo segue como estava');

  -- ===== MODO SIMULADO (checkin_sandbox) =====
  jsim := pg_temp.paid(c, p1, 100, now() + interval '3 days');
  jsim2 := pg_temp.paid(c, p1, 100, now() + interval '3 days');
  update public.app_settings set value = 'false' where key = 'checkin_sandbox';
  perform pg_temp.login(p1);
  r := pg_temp.ts(jsim, null, null, null, true);
  perform pg_temp.t(r = '42501:START_SANDBOX_OFF', 'sandbox desligado: p_simulate -> START_SANDBOX_OFF (' || r || ')');
  reset role;
  perform pg_temp.t((select status = 'scheduled' and not start_simulated from public.jobs where id = jsim), 'sandbox desligado: o serviço continua agendado');
  update public.app_settings set value = 'true' where key = 'checkin_sandbox';
  perform pg_temp.login(p2);
  r := pg_temp.ts(jsim, null, null, null, true);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'sandbox ligado: outro profissional não inicia nem simulando');
  reset role;
  perform pg_temp.login(p1);
  r := pg_temp.ts(jsim2, lat0, lng0, 5, false);
  perform pg_temp.t(starts_with(r, 'P0001:START_TOO_EARLY|'), 'sandbox ligado NÃO afrouxa o início real (sem p_simulate vale a janela)');
  v := public.start_job(jsim, null, null, null, true);
  reset role;
  perform pg_temp.t((v ->> 'simulated')::boolean and (v ->> 'distance_m') is null, 'simulado: resposta simulated=true e sem distância');
  perform pg_temp.t((select status = 'in_progress' and start_simulated and start_distance_m is null and started_at is not null
                       from public.jobs where id = jsim),
                    'sandbox ligado: p_simulate inicia sem janela nem geofence e marca start_simulated');

  -- ===== EMERGÊNCIA: começa no aceite =====
  perform pg_temp.login(c);
  insert into public.jobs (client_id, title, description, category, urgency, visibility, address_summary)
  values (c, 'Vazamento intenso', 'Cano estourou', 'Encanador', 'emergency', 'direct', 'Centro') returning id into jem;
  insert into public.job_addresses (job_id, address_line) values (jem, 'Rua A, 1');
  perform public.invite_providers(jem, array[p2]);
  perform public.request_emergency_mock(jem, 'pix');
  reset role;
  perform pg_temp.t((select status = 'open' and started_at is null and payment_status = 'escrow' from public.jobs where id = jem),
                    'emergência paga e ainda sem aceite: open, sem started_at, escrow');
  perform pg_temp.login(p2);
  perform public.accept_emergency(jem);
  reset role;
  perform pg_temp.t((select status = 'in_progress' and started_at is not null and provider_id = p2 and not start_simulated from public.jobs where id = jem),
                    'emergência aceita vai direto a in_progress com started_at');
  perform pg_temp.t(not exists (select 1 from public.notifications where kind = 'confirm_location' and job_id = jem),
                    'emergência NÃO gera confirm_location (nem ao pagar nem ao aceitar)');
  perform pg_temp.login(p2);
  r := pg_temp.ts(jem, null, null, null, true);
  perform pg_temp.t(r = 'P0001:START_INVALID_STATE', 'start_job numa emergência em andamento é recusado');
  reset role;

  -- ===== CHAT: idempotência (client_message_id) =====
  perform pg_temp.login(c);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body, client_message_id) values (%L,%L,%L,%L)', jm, p1, 'Olá, estou no portão', u1));
  perform pg_temp.t(r = 'OK', 'cliente envia mensagem com client_message_id');
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body, client_message_id) values (%L,%L,%L,%L)', jm, p1, 'Olá, estou no portão', u1));
  perform pg_temp.t(starts_with(r, '23505:'), 'reenvio com o MESMO client_message_id viola o UNIQUE (23505)');
  select count(*) into n from public.messages where job_id = jm and client_message_id = u1;
  perform pg_temp.t(n = 1, 'o reenvio NÃO duplicou a mensagem');
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body, client_message_id) values (%L,%L,%L,%L)', jm, p1, 'Segunda mensagem', u2));
  perform pg_temp.t(r = 'OK', 'client_message_id diferente passa');
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body) values (%L,%L,%L)', jm, p1, 'Sem id 1'));
  r := r || '/' || pg_temp.try(format('insert into public.messages (job_id, provider_id, body) values (%L,%L,%L)', jm, p1, 'Sem id 2'));
  perform pg_temp.t(r = 'OK/OK', 'mensagens sem client_message_id (NULL) não colidem entre si');
  reset role;
  perform pg_temp.login(p1);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body, client_message_id) values (%L,%L,%L,%L)', jm, p1, 'Já abro', u1));
  perform pg_temp.t(r = 'OK', 'o UNIQUE é por remetente: o profissional pode usar o mesmo uuid');
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 5, 'profissional contratado lê as 5 mensagens da conversa (' || n || ')');
  reset role;

  -- terceiros
  perform pg_temp.login(p3);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body) values (%L,%L,%L)', jm, p1, 'intruso'));
  perform pg_temp.t(r <> 'OK', 'terceiro não envia mensagem na conversa alheia');
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 0, 'terceiro não lê a conversa');
  reset role;
  perform pg_temp.login(p2);
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 0, 'outro profissional não lê a conversa');
  reset role;
  perform pg_temp.login(c2);
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 0, 'outro cliente não lê a conversa');
  reset role;

  -- ===== chat_counterpart =====
  jx := pg_temp.job(c, p2, 90);
  jy := pg_temp.job(c2, p1, 70);
  perform pg_temp.login(c);
  v := public.chat_counterpart(jm, p1);
  perform pg_temp.t(v ->> 'name' = 'João Eletricista' and v ->> 'role' = 'provider' and v ->> 'subtitle' = 'Elétrica',
                    'cliente vê o profissional com nome e especialidade (' || (v ->> 'name') || ' / ' || (v ->> 'subtitle') || ')');
  v := public.chat_counterpart(jx, p2);
  perform pg_temp.t(v ->> 'name' = 'Profissional', 'profissional com full_name e-mail aparece como "Profissional" (' || (v ->> 'name') || ')');
  perform pg_temp.t(public.chat_counterpart(jm, p2) is null, 'cliente pergunta por um profissional que não foi contratado -> null');
  reset role;
  perform pg_temp.login(p1);
  v := public.chat_counterpart(jm, p1);
  perform pg_temp.t(v ->> 'name' = 'Maria Souza' and v ->> 'role' = 'client', 'profissional contratado vê o cliente com o nome completo (' || (v ->> 'name') || ')');
  v := public.chat_counterpart(jy, p1);
  perform pg_temp.t(v ->> 'name' = 'Cliente', 'cliente com full_name e-mail aparece como "Cliente" (' || (v ->> 'name') || ')');
  reset role;
  perform pg_temp.login(p3);
  perform pg_temp.t(public.chat_counterpart(jm, p1) is null, 'terceiro recebe null em chat_counterpart');
  reset role;
  perform pg_temp.login(p2);
  perform pg_temp.t(public.chat_counterpart(jm, p1) is null and public.chat_counterpart(jm, p2) is null, 'outro profissional recebe null (não contratado nesse serviço)');
  reset role;
  perform pg_temp.login(c2);
  perform pg_temp.t(public.chat_counterpart(jm, p1) is null, 'outro cliente recebe null em chat_counterpart');
  reset role;

  -- ===== evidências + conclusão (agora permitidas) =====
  perform pg_temp.login(p1);
  r := pg_temp.try(format('insert into public.job_evidence (job_id, provider_id, slot, path) values (%L,%L,%L,%L)', jm, p1, 'overview', p1::text || '/a.jpg'));
  perform pg_temp.t(r = 'OK', 'depois de iniciar, a evidência é aceita');
  select pin into v_pin from public.job_secrets where job_id = jm;
  reset role;
  select pin into v_pin from public.job_secrets where job_id = jm;

  -- dossiê do profissional ANTES de concluir/avaliar
  perform pg_temp.login(p1);
  s := public.complete_job_with_pin(jm, v_pin);
  reset role;
  perform pg_temp.t(s = 'ok', 'profissional conclui o serviço iniciado com o PIN');

  -- ===== CHAT ARQUIVADO =====
  perform pg_temp.login(c);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body, client_message_id) values (%L,%L,%L,%L)', jm, p1, 'Obrigado!', gen_random_uuid()));
  perform pg_temp.t(starts_with(r, 'P0001:CHAT_ARCHIVED'), 'cliente não escreve após "completed" (CHAT_ARCHIVED)');
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 5, 'cliente continua LENDO a conversa arquivada (' || n || ')');
  reset role;
  perform pg_temp.login(p1);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body) values (%L,%L,%L)', jm, p1, 'Por nada'));
  perform pg_temp.t(starts_with(r, 'P0001:CHAT_ARCHIVED'), 'profissional não escreve após "completed" (CHAT_ARCHIVED)');
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 5, 'profissional CONTRATADO continua lendo após a conclusão (' || n || ')');
  reset role;
  perform pg_temp.login(p3);
  select count(*) into n from public.messages where job_id = jm;
  perform pg_temp.t(n = 0, 'terceiro segue sem ler a conversa arquivada');
  reset role;
  -- cancelado também arquiva; contratado lê mesmo sem orçamento ativo
  insert into public.messages (job_id, provider_id, sender_id, body) values (jx, p2, c, 'Oi, tudo certo?');
  update public.jobs set status = 'canceled' where id = jx;
  perform pg_temp.login(c);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body) values (%L,%L,%L)', jx, p2, 'ainda aí?'));
  perform pg_temp.t(starts_with(r, 'P0001:CHAT_ARCHIVED'), 'conversa de serviço cancelado também é arquivada (cliente)');
  reset role;
  perform pg_temp.login(p2);
  r := pg_temp.try(format('insert into public.messages (job_id, provider_id, body) values (%L,%L,%L)', jx, p2, 'estou sim'));
  select count(*) into n from public.messages where job_id = jx;
  perform pg_temp.t(starts_with(r, 'P0001:CHAT_ARCHIVED') and n = 1, 'serviço cancelado: profissional contratado lê o histórico (1) mas não escreve');
  reset role;
  perform pg_temp.login(c);
  r := pg_temp.try(format('select public.set_job_location(%L, %s, %s)', jx, lat0, lng0));
  perform pg_temp.t(starts_with(r, 'P0001:'), 'set_job_location recusado em serviço cancelado');
  reset role;
  perform pg_temp.login(p3);
  select count(*) into n from public.messages where job_id = jx;
  perform pg_temp.t(n = 0, 'terceiro não lê conversa de serviço cancelado');
  reset role;

  -- ===== DOSSIÊ DO PROFISSIONAL =====
  perform pg_temp.login(p2);
  perform pg_temp.t(public.provider_job_dossier(jm) is null, 'provider_job_dossier: outro profissional recebe null');
  reset role;
  perform pg_temp.login(c);
  perform pg_temp.t(public.provider_job_dossier(jm) is null, 'provider_job_dossier: o cliente recebe null (financeiro do profissional)');
  reset role;
  perform pg_temp.login(c2);
  perform pg_temp.t(public.provider_job_dossier(jm) is null, 'provider_job_dossier: outro cliente recebe null');
  reset role;
  perform pg_temp.login(p1);
  d := public.provider_job_dossier(jm);
  perform pg_temp.t((d ->> 'gross')::numeric = 150 and (d ->> 'fee')::numeric = 18 and (d ->> 'net')::numeric = 132 and (d ->> 'fee_pct')::numeric = 12,
                    'dossiê do profissional: bruto 150 / taxa 18 (12%) / líquido 132');
  perform pg_temp.t(d ->> 'status' = 'completed' and (d ->> 'started_at') is not null and (d ->> 'finished_at') is not null
                    and d -> 'client' ->> 'name' = 'Maria Souza' and jsonb_array_length(d -> 'evidence') = 1,
                    'dossiê: concluído, com início/fim, cliente e 1 evidência');
  perform pg_temp.t(jsonb_typeof(d -> 'review') = 'null', 'dossiê: sem avaliação ainda -> review nulo');
  reset role;

  -- ===== AVALIAÇÃO CEGA NO DOSSIÊ =====
  perform pg_temp.login(c);
  perform public.submit_review(jm, 4, 'Comentario secreto XYZ', array['Pontual'], 0);
  reset role;
  perform pg_temp.login(p1);
  d := public.provider_job_dossier(jm);
  perform pg_temp.t(d -> 'review' ->> 'state' = 'hidden', 'avaliação do cliente ainda não revelada: review.state = hidden');
  perform pg_temp.t(not (d -> 'review' ? 'rating') and position('Comentario secreto' in d::text) = 0 and position('"rating"' in d::text) = 0,
                    'review "hidden" NÃO vaza nota nem comentário (nem em outro lugar do dossiê)');
  select count(*) into n from public.my_received_reviews() r2 where (r2 ->> 'job_id')::uuid = jm;
  perform pg_temp.t(n = 0, 'my_received_reviews não traz avaliação ainda oculta');
  perform public.submit_review(jm, 5, null, '{}', 0, '{"Simpatia":5}'::jsonb);   -- profissional avalia o cliente -> revela as duas
  d := public.provider_job_dossier(jm);
  perform pg_temp.t(d -> 'review' ->> 'state' = 'revealed' and (d -> 'review' ->> 'rating')::int = 4
                    and d -> 'review' ->> 'comment' = 'Comentario secreto XYZ', 'após a revelação: review.state = revealed com nota 4 e comentário');
  select count(*) into n from public.my_received_reviews() r2
   where (r2 ->> 'job_id')::uuid = jm and (r2 ->> 'rating')::int = 4;
  perform pg_temp.t(n = 1, 'my_received_reviews traz a avaliação revelada com job_id');
  select count(*) into n from public.my_received_reviews() r2 where r2 ->> 'reviewer_name' = 'Maria S.' and (r2 ->> 'job_id')::uuid = jm;
  perform pg_temp.t(n = 1, 'my_received_reviews mostra o avaliador em formato curto (Maria S.)');
  reset role;
  perform pg_temp.login(p2);
  select count(*) into n from public.my_received_reviews() r2 where (r2 ->> 'job_id')::uuid = jm;
  perform pg_temp.t(n = 0, 'my_received_reviews: outro profissional não vê as avaliações do p1');
  reset role;
  perform pg_temp.login(c);
  select count(*) into n from public.my_received_reviews() r2 where (r2 ->> 'job_id')::uuid = jm;
  perform pg_temp.t(n = 0, 'my_received_reviews: o cliente não vê avaliação alheia nem a sua recebida (só do profissional)');
  reset role;

  -- avaliações com cliente de nome-e-mail: uma revelada (jr) e uma oculta (jh)
  jr := pg_temp.job(c2, p1, 80);
  update public.jobs set status = 'completed', payment_status = 'released' where id = jr;
  jh := pg_temp.job(c2, p1, 50);
  update public.jobs set status = 'completed', payment_status = 'released' where id = jh;
  perform pg_temp.login(c2);
  perform public.submit_review(jr, 3, 'ok', '{}', 0);
  perform public.submit_review(jh, 5, 'oculta', '{}', 0);
  reset role;
  perform pg_temp.login(p1);
  perform public.submit_review(jr, 5, null, '{}', 0);
  select count(*) into n from public.my_received_reviews() r2 where (r2 ->> 'job_id')::uuid = jh;
  perform pg_temp.t(n = 0, 'my_received_reviews só devolve reveladas (a oculta de outro serviço fica de fora)');
  select count(*) into n from public.my_received_reviews() r2 where (r2 ->> 'job_id')::uuid in (jm, jr);
  perform pg_temp.t(n = 2, 'my_received_reviews devolve as 2 reveladas (jm e jr)');
  select count(*) into n from public.my_received_reviews() r2 where (r2 ->> 'job_id')::uuid = jr and r2 ->> 'reviewer_name' = 'Cliente';
  perform pg_temp.t(n = 1, 'avaliador com full_name e-mail aparece como "Cliente" em my_received_reviews');
  d := public.provider_job_dossier(jh);
  perform pg_temp.t(d -> 'review' ->> 'state' = 'hidden' and position('oculta' in d::text) = 0, 'outro serviço com avaliação oculta: dossiê só informa hidden (sem nota/comentário)');
  perform pg_temp.t((select full_name from public.job_client_cards where job_id = jr) = 'Cliente', 'job_client_cards: nome e-mail do cliente vira "Cliente" para o profissional contratado');
  perform pg_temp.t((select full_name from public.job_client_cards where job_id = jm) = 'Maria Souza', 'job_client_cards: nome normal segue completo para o profissional contratado');
  reset role;
  select id into rid from public.reviews where job_id = jr and reviewer_id = c2;
  perform pg_temp.login(p3);
  perform pg_temp.t((select reviewer_name from public.public_reviews where id = rid) = 'Cliente', 'public_reviews: reviewer_name e-mail vira "Cliente"');
  perform pg_temp.t((select reviewer_name from public.public_reviews
                      where id = (select id from public.reviews where job_id = jm and reviewer_id = c)) = 'Maria S.', 'public_reviews: nome normal fica abreviado (Maria S.)');
  perform pg_temp.t((select count(*) from public.public_reviews where id = (select id from public.reviews where job_id = jh and reviewer_id = c2)) = 0,
                    'public_reviews: avaliação oculta não aparece');
  r := pg_temp.try('select job_id from public.public_reviews limit 1');
  perform pg_temp.t(starts_with(r, '42703'), 'public_reviews: consulta por job_id falha (coluna inexistente)');
  reset role;
  select count(*) into n from information_schema.columns
   where table_schema = 'public' and table_name = 'public_reviews'
     and column_name in ('job_id', 'budget', 'net', 'amount', 'fee', 'net_amount', 'fee_amount', 'agreed_price');
  perform pg_temp.t(n = 0, 'public_reviews NÃO tem job_id/budget/net/amount/fee (information_schema)');
  perform pg_temp.t((select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'public_reviews'
                       and column_name in ('id', 'provider_id', 'rating', 'comment', 'reviewer_name')) = 5, 'public_reviews mantém as colunas públicas (id, provider_id, rating, comment, reviewer_name)');

  -- ===== DOSSIÊ DO CLIENTE =====
  perform pg_temp.login(p1);
  perform pg_temp.t(public.client_job_dossier(jm) is null, 'client_job_dossier: o profissional recebe null');
  reset role;
  perform pg_temp.login(c2);
  perform pg_temp.t(public.client_job_dossier(jm) is null, 'client_job_dossier: outro cliente recebe null');
  reset role;
  perform pg_temp.login(p3);
  perform pg_temp.t(public.client_job_dossier(jm) is null, 'client_job_dossier: terceiro recebe null');
  reset role;
  perform pg_temp.login(c);
  d := public.client_job_dossier(jm);
  perform pg_temp.t((d ->> 'amount')::numeric = 150 and d ->> 'status' = 'completed' and d -> 'provider' ->> 'name' = 'João Eletricista'
                    and d -> 'provider' ->> 'title' = 'Elétrica', 'dossiê do cliente: valor pago 150, status e profissional (nome/título)');
  perform pg_temp.t(not (d ? 'fee') and not (d ? 'net') and not (d ? 'fee_pct') and not (d ? 'net_amount') and not (d ? 'gross')
                    and position('"fee' in d::text) = 0 and position('"net' in d::text) = 0,
                    'dossiê do cliente NÃO contém fee/net (taxa e líquido do profissional)');
  perform pg_temp.t((d -> 'my_review' ->> 'rating')::int = 4 and (d ->> 'started_at') is not null, 'dossiê do cliente traz a própria avaliação (4) e o início do serviço');
  reset role;

  -- ===== ESTADOS QUE CONTAM "AGENDADO" =====
  -- Exclusão de conta
  perform pg_temp.login(p3);
  v := public.account_deletion_status();
  n0 := (v ->> 'active_jobs')::int;
  reset role;
  jb := pg_temp.job(c2, p3, 40);
  update public.jobs set status = 'scheduled', scheduled_for = timestamptz '2031-03-03 10:00:00+00' where id = jb;
  perform pg_temp.login(p3);
  v := public.account_deletion_status();
  perform pg_temp.t((v ->> 'active_jobs')::int = n0 + 1 and v -> 'blockers' ? 'active_jobs' and not (v ->> 'can_delete')::boolean,
                    '_deletion_blockers: serviço "scheduled" bloqueia a exclusão do profissional (active_jobs ' || n0 || ' -> ' || (v ->> 'active_jobs') || ')');
  reset role;
  perform pg_temp.t((public._deletion_blockers(c2) -> 'blockers') ? 'active_jobs', '_deletion_blockers: serviço "scheduled" também bloqueia a exclusão do cliente');
  -- Agenda ocupada
  perform pg_temp.login(c);
  select count(*) into n from public.provider_busy_slots where provider_id = p3 and scheduled_for = timestamptz '2031-03-03 10:00:00+00';
  perform pg_temp.t(n = 1, 'provider_busy_slots inclui serviço "scheduled"');
  reset role;
  update public.jobs set status = 'in_progress' where id = jb;
  select count(*) into n from public.provider_busy_slots where provider_id = p3 and scheduled_for = timestamptz '2031-03-03 10:00:00+00';
  perform pg_temp.t(n = 1, 'provider_busy_slots segue incluindo "in_progress"');
  update public.jobs set status = 'completed' where id = jb;
  select count(*) into n from public.provider_busy_slots where provider_id = p3 and scheduled_for = timestamptz '2031-03-03 10:00:00+00';
  perform pg_temp.t(n = 0, 'provider_busy_slots libera o horário após "completed"');
  update public.jobs set status = 'canceled' where id = jb;
  perform pg_temp.login(p3);
  v := public.account_deletion_status();
  perform pg_temp.t((v ->> 'active_jobs')::int = n0, 'serviço encerrado deixa de bloquear a exclusão (active_jobs volta a ' || n0 || ')');
  reset role;

  -- ===== FUNÇÕES UTILITÁRIAS =====
  perform pg_temp.t(public.haversine_m(-23.55, -46.63, -23.55, -46.63) = 0, 'haversine_m: mesmo ponto = 0 m');
  perform pg_temp.t(abs(public.haversine_m(0, 0, 1, 0) - 111194.93) < 5, 'haversine_m: 1° de latitude ~ 111,19 km (' || round(public.haversine_m(0, 0, 1, 0)::numeric, 1) || ' m)');
  perform pg_temp.t(abs(public.haversine_m(0, 0, 0, 1) - 111194.93) < 5, 'haversine_m: 1° de longitude no equador ~ 111,19 km');
  perform pg_temp.t(abs(public.haversine_m(60, 0, 60, 1) - 55597.5) < 100, 'haversine_m: 1° de longitude a 60° de latitude ~ metade (55,6 km)');
  perform pg_temp.t(abs(public.haversine_m(-23.5505, -46.6333, -23.5605, -46.6333) - 1111.95) < 1, 'haversine_m: 0,01° de latitude ~ 1.112 m');
  perform pg_temp.t(abs(public.haversine_m(10, 20, -30, 40) - public.haversine_m(-30, 40, 10, 20)) < 0.001, 'haversine_m é simétrica');
  num := public.haversine_m(0, 0, 0, 180)::numeric;
  perform pg_temp.t(abs(num - 20015086.8) < 20, 'haversine_m: pontos antípodas ~ 20.015 km, sem NaN (' || round(num) || ' m)');
  perform pg_temp.t(public.safe_name('maria@email.com') = 'Cliente' and public.safe_name('maria@email.com', 'Profissional') = 'Profissional',
                    'safe_name: e-mail vira o fallback');
  perform pg_temp.t(public.safe_name('  ', 'X') = 'X' and public.safe_name(null, 'Cliente') = 'Cliente', 'safe_name: vazio/nulo vira o fallback');
  perform pg_temp.t(public.safe_name('  Maria Souza ') = 'Maria Souza', 'safe_name: nome normal é preservado (sem espaços nas pontas)');
  perform pg_temp.t(public._short_name('maria@email.com') = 'Cliente' and public._short_name('Maria Souza') = 'Maria S.'
                    and public._short_name('Maria') = 'Maria' and public._short_name(null) = 'Usuário removido', '_short_name: e-mail -> Cliente, nome composto -> "Maria S."');
  perform pg_temp.login(c);
  perform pg_temp.t(abs(extract(epoch from public.server_time() - now())) < 5, 'server_time() responde ao app autenticado e bate com o relógio do banco');
  reset role;

  -- ===== ANON =====
  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role anon';
  r := pg_temp.try('select 1 from public.job_geo limit 1');
  perform pg_temp.t(starts_with(r, '42501'), 'anon sem acesso a job_geo');
  r := pg_temp.try(format('select public.start_job(%L, 1, 1, 1, false)', jm));
  perform pg_temp.t(starts_with(r, '42501'), 'anon não executa start_job');
  r := pg_temp.try(format('select public.job_destination(%L)', jm)) || '|' || pg_temp.try(format('select public.set_job_location(%L, 1, 1)', jm))
       || '|' || pg_temp.try(format('select public.chat_counterpart(%L, %L)', jm, p1));
  perform pg_temp.t(r ~ '^42501.*\|42501.*\|42501', 'anon não executa job_destination / set_job_location / chat_counterpart');
  r := pg_temp.try(format('select public.provider_job_dossier(%L)', jm)) || '|' || pg_temp.try(format('select public.client_job_dossier(%L)', jm))
       || '|' || pg_temp.try('select public.my_received_reviews()') || '|' || pg_temp.try('select public.server_time()');
  perform pg_temp.t(r ~ '^42501.*\|42501.*\|42501.*\|42501', 'anon não executa dossiês, my_received_reviews nem server_time');
  reset role;

  -- ---------------------------------------------------------------- relatório
  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || lpad(r2.n::text, 3, '0') || ' ' || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (AGENDAMENTO / CHAT / DOSSIÊ) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
