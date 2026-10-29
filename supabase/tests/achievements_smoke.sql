-- ============================================================================
-- DESPERRENGUE — Teste de fumaça das CONQUISTAS do profissional
--
-- Transação SEMPRE abortada (nada é gravado). Relatório na mensagem do erro:
--   supabase db query --linked -f supabase/tests/achievements_smoke.sql
-- Requer >= 3 linhas em public.profiles.   c = cliente  p1/p2 = profissionais
-- ============================================================================
begin;

create temp table res (n serial, ok boolean, name text) on commit drop;
grant all on res to public;
grant all on sequence res_n_seq to public;

create function pg_temp.t(p_ok boolean, p_name text) returns void
language sql security definer as $$ insert into pg_temp.res (ok, name) values (p_ok, p_name) $$;

create function pg_temp.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function pg_temp.done_job(c uuid, p uuid, title text, urg text default 'scheduled') returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  insert into public.jobs (client_id, title, description, category, urgency) values (c, title, 'desc', 'Elétrica', urg) returning id into j;
  update public.jobs set provider_id = p, status = 'completed', payment_status = 'released' where id = j;
  return j;
end $$;

do $$
declare
  ids uuid[]; c uuid; p1 uuid; p2 uuid; j uuid; n int; i int; s text; r record;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 3 then raise exception 'TESTE ABORTADO: são necessários >= 3 perfis.'; end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3];

  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id = c;
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true where id in (p1, p2);
  delete from public.provider_achievements;
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee)
    select id, array['Elétrica'], 30 from public.profiles where id in (p1, p2);

  -- ===== PRIMEIRO SERVIÇO =====
  select count(*) into n from public.provider_achievements where provider_id = p1;
  perform pg_temp.t(n = 0, '01 profissional novo não tem conquistas');
  j := pg_temp.done_job(c, p1, 'Serviço 1');
  select count(*) into n from public.provider_achievements where provider_id = p1 and code = 'services_1';
  perform pg_temp.t(n = 1, '02 concluir o 1º serviço desbloqueia "services_1" automaticamente');
  select count(*) into n from public.provider_achievements where provider_id = p1 and code = 'services_10';
  perform pg_temp.t(n = 0, '03 níveis acima do contador NÃO são desbloqueados');
  select count(*) into n from public.notifications where user_id = p1 and kind = 'achievement';
  perform pg_temp.t(n = 1, '04 notificação "Conquista desbloqueada" enviada');

  -- ===== ESCALA: 10 serviços =====
  for i in 2..10 loop perform pg_temp.done_job(c, p1, 'Serviço ' || i); end loop;
  select count(*) into n from public.provider_achievements where provider_id = p1 and code = 'services_10';
  perform pg_temp.t(n = 1, '05 10 serviços concluídos desbloqueia "services_10"');
  select count(*) into n from public.provider_achievements where provider_id = p1 and code like 'services_%';
  perform pg_temp.t(n = 2, '06 apenas níveis 1 e 10 de "services" (' || n || ')');
  perform public.refresh_provider_achievements(p1);
  select count(*) into n from public.provider_achievements where provider_id = p1 and code like 'services_%';
  perform pg_temp.t(n = 2, '07 recalcular é idempotente (sem duplicar)');
  select count(*) into n from public.notifications where user_id = p1 and kind = 'achievement';
  perform pg_temp.t(n = 3, '08 uma notificação por nível desbloqueado: services_1, services_10 e repeat_clients_1 (' || n || ')');

  -- ===== CLIENTES RECORRENTES (mesmo cliente, 2+ serviços) =====
  select count(*) into n from public.provider_achievements where provider_id = p1 and code = 'repeat_clients_1';
  perform pg_temp.t(n = 1, '09 cliente que voltou -> "repeat_clients_1"');
  select count(*) into n from public.provider_achievements where provider_id = p2 and code = 'repeat_clients_1';
  perform pg_temp.t(n = 0, '10 outro profissional não herda conquistas');

  -- ===== EMERGÊNCIA =====
  perform pg_temp.done_job(c, p2, 'Chave quebrada', 'emergency');
  select count(*) into n from public.provider_achievements where provider_id = p2 and code = 'emergency_1';
  perform pg_temp.t(n = 1, '11 emergência concluída -> "emergency_1"');

  -- ===== AVALIAÇÕES REVELADAS (5★ e pílulas) =====
  j := pg_temp.done_job(c, p2, 'Serviço com avaliação');
  perform pg_temp.login(c);
  perform public.submit_review(j, 5, 'ótimo', array['Super pontual', 'Limpou tudo depois']);
  reset role;
  select count(*) into n from public.provider_achievements where provider_id = p2 and code = 'five_star_1';
  perform pg_temp.t(n = 0, '12 avaliação ainda OCULTA não desbloqueia "five_star_1"');
  perform pg_temp.login(p2);
  perform public.submit_review(j, 4, 'cliente ok');
  reset role;
  select count(*) into n from public.provider_achievements where provider_id = p2 and code = 'five_star_1';
  perform pg_temp.t(n = 1, '13 ao revelar, a 1ª avaliação 5★ desbloqueia "five_star_1"');
  select count(*) into n from public.provider_achievements where provider_id = p2 and code in ('punctual_1', 'tidy_1');
  perform pg_temp.t(n = 2, '14 pílulas elogiadas desbloqueiam "punctual_1" e "tidy_1"');
  select count(*) into n from public.provider_achievements where provider_id = p2 and code = 'fair_price_1';
  perform pg_temp.t(n = 0, '15 pílula não marcada não desbloqueia nada');

  -- ===== PRIVACIDADE =====
  perform pg_temp.login(p1);
  select count(*) into n from public.provider_achievements where provider_id = p2;
  perform pg_temp.t(n >= 1, '16 conquistas de profissional ativo são visíveis (vitrine)');
  begin
    insert into public.provider_achievements (provider_id, code) values (p1, 'services_10000');
    perform pg_temp.t(false, '17 inserir conquista direto PERMITIDO');
  exception when others then perform pg_temp.t(true, '17 conquista não é inserível pelo app'); end;
  begin
    delete from public.provider_achievements where provider_id = p1;
    perform pg_temp.t(false, '18 apagar conquista PERMITIDO');
  exception when others then perform pg_temp.t(true, '18 conquista não é apagável pelo app'); end;
  begin
    perform public.refresh_provider_achievements(p1);
    perform pg_temp.t(false, '19 refresh chamado pelo app PERMITIDO');
  exception when others then perform pg_temp.t(true, '19 refresh só pelo sistema'); end;
  select m.n into n from public.my_achievement_counts() m where m.category = 'services';
  perform pg_temp.t(n = 10, '20 my_achievement_counts devolve os contadores do próprio usuário (services=' || coalesce(n, -1) || ')');
  reset role;
  perform pg_temp.login(c);
  select count(*) into n from public.provider_achievements where provider_id = p1;
  perform pg_temp.t(n >= 1, '21 cliente enxerga as conquistas do profissional (vitrine)');
  reset role;
  execute 'set local role anon';
  begin
    perform 1 from public.provider_achievements limit 1;
    perform pg_temp.t(false, '22 anon leu conquistas PERMITIDO');
  exception when others then perform pg_temp.t(true, '22 anon sem acesso às conquistas'); end;
  reset role;

  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (CONQUISTAS) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
