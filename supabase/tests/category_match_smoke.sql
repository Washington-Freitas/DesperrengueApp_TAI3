-- ============================================================================
-- DESPERRENGUE — Teste de fumaça do MATCH DE CATEGORIA (tags canônicas) e do isolamento
-- do pedido por categoria (migration 20261106120000).
--
-- Transação SEMPRE abortada (nada é gravado). Relatório na mensagem do erro:
--   supabase db query --linked -f supabase/tests/category_match_smoke.sql
-- Requer >= 4 linhas em public.profiles.
--   c = cliente   p1 = Encanador+Eletricista+Montador   p2 = só Pintura   p3 = Encanador (0 serviços)
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

do $$
declare
  ids uuid[]; c uuid; p1 uuid; p2 uuid; p3 uuid; j uuid; j2 uuid; j3 uuid; n int; s text; v_slugs text[]; v_d jsonb;
begin
  -- ===== NORMALIZAÇÃO (puro, sem dados) =====
  perform pg_temp.t(public.norm_tag('Encanador') = 'encanador', '01 "Encanador" -> encanador');
  perform pg_temp.t(public.norm_tag('  ELÉTRICA ') = 'eletrica', '02 acento/caixa/espaço: "  ELÉTRICA " -> eletrica');
  perform pg_temp.t(public.norm_tag('Hidráulica') = 'encanador', '03 sinônimo: Hidráulica -> encanador');
  perform pg_temp.t(public.norm_tag('Eletricista') = public.norm_tag('Elétrica'), '04 Eletricista == Elétrica');
  perform pg_temp.t(public.norm_tag('Montador') = 'montagem', '05 Montador -> montagem');
  perform pg_temp.t(public.norm_tag(null) = '', '06 null -> vazio');
  v_slugs := public.norm_tags(array['Encanador', 'hidraulica', 'Montador', '', null]);
  perform pg_temp.t(v_slugs = array['encanador', 'montagem'], '07 norm_tags deduplica e descarta vazios (' || v_slugs::text || ')');

  -- ===== CENÁRIO =====
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 4 then raise exception 'TESTE ABORTADO: são necessários >= 4 perfis.'; end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3]; p3 := ids[4];

  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id = c;
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true where id in (p1, p2, p3);
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee) values
    (p1, array['encanador', 'Eletricista', 'montador'], 30),
    (p2, array['Pintura'], 30),
    (p3, array['Hidráulica'], 30);

  -- ===== VIEW PÚBLICA: filtro por slug (inclui 0 serviços) =====
  perform pg_temp.login(c);
  select count(*) into n from public.provider_public_profiles where specialty_slugs @> array['encanador'];
  perform pg_temp.t(n = 2, '08 categoria Encanador lista p1 (multi-tags) e p3 (Hidráulica, 0 serviços): ' || n);
  select count(*) into n from public.provider_public_profiles where specialty_slugs @> array['pintura'] and id <> p2;
  perform pg_temp.t(n = 0, '09 isolamento: Pintura não traz quem não tem a tag');
  reset role;

  -- ===== PEDIDO PÚBLICO: só quem atende a categoria =====
  insert into public.jobs (client_id, title, description, category, visibility)
    values (c, 'Vazamento na pia', 'desc', 'Encanador', 'open') returning id into j;
  select count(*) into n from public.notifications where kind = 'new_area_job' and job_id = j and user_id in (p1, p3);
  perform pg_temp.t(n = 2, '10 pedido público notifica os 2 profissionais da área (' || n || ')');
  select count(*) into n from public.notifications where kind = 'new_area_job' and job_id = j and user_id = p2;
  perform pg_temp.t(n = 0, '11 profissional de outra categoria NÃO é notificado');

  perform pg_temp.login(p1);
  select count(*) into n from public.jobs where id = j;
  perform pg_temp.t(n = 1, '12 p1 (tem a tag) enxerga o pedido público');
  reset role;
  perform pg_temp.login(p2);
  select count(*) into n from public.jobs where id = j;
  perform pg_temp.t(n = 0, '13 p2 (sem a tag) NÃO enxerga o pedido público');
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, p2, 100);
    perform pg_temp.t(false, '14 p2 orçou pedido de outra categoria PERMITIDO');
  exception when others then perform pg_temp.t(true, '14 orçamento fora da categoria é bloqueado'); end;
  reset role;
  perform pg_temp.login(p1);
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, p1, 100);
    perform pg_temp.t(true, '15 p1 (com a tag) consegue orçar');
  exception when others then perform pg_temp.t(false, '15 p1 não conseguiu orçar: ' || sqlerrm); end;
  reset role;

  -- ===== CANCELAMENTO REGISTRADO =====
  perform pg_temp.login(c);
  perform public.cancel_job(j);
  reset role;
  select count(*) into n from public.jobs where id = j and status = 'canceled' and canceled_at is not null and cancel_reason is not null;
  perform pg_temp.t(n = 1, '16 cancelar registra data e motivo');

  -- ===== DOSSIÊ COMPLETO =====
  perform pg_temp.login(c);
  perform pg_temp.t((public.client_job_dossier(j) ->> 'cancel_reason') is not null, '17 dossiê traz o motivo do cancelamento');
  perform pg_temp.t((public.client_job_dossier(j) ? 'dispute'), '18 dossiê traz a chave "dispute"');
  reset role;
  perform pg_temp.login(p2);
  perform pg_temp.t(public.client_job_dossier(j) is null, '19 não-dono recebe dossiê nulo');
  reset role;

  -- ===== TRIGGER DE ORÇAMENTO (direto, sem depender da RLS) =====
  insert into public.jobs (client_id, title, description, category, visibility)
    values (c, 'Pintar quarto', 'desc', 'Pintura', 'open') returning id into j2;
  begin
    insert into public.quotes (job_id, provider_id, price) values (j2, p1, 100);
    perform pg_temp.t(false, '20 trigger deixou p1 (sem a tag Pintura) orçar');
  exception when others then
    perform pg_temp.t(sqlerrm like '%exclusivo de profissionais da categoria%', '20 trigger bloqueia orçamento fora da categoria: ' || sqlerrm);
  end;
  begin
    insert into public.quotes (job_id, provider_id, price) values (j2, p2, 100);
    perform pg_temp.t(true, '21 trigger permite orçamento de quem tem a tag (p2 Pintura)');
  exception when others then perform pg_temp.t(false, '21 p2 deveria poder orçar: ' || sqlerrm); end;

  -- ===== MEDIAÇÃO: quem abriu, motivo e custódia no dossiê =====
  insert into public.jobs (client_id, title, description, category, visibility)
    values (c, 'Trocar torneira', 'desc', 'Encanador', 'open') returning id into j3;
  update public.jobs set provider_id = p1, status = 'in_progress', payment_status = 'escrow' where id = j3;
  perform pg_temp.login(p1);
  perform public.create_support_ticket(j3, 'Cliente não liberou o serviço', 'Serviço feito, PIN não informado.');
  reset role;
  perform pg_temp.login(c);
  v_d := public.client_job_dossier(j3);
  perform pg_temp.t(v_d ->> 'status' = 'disputed', '22 chamado do profissional congela o serviço (disputed)');
  perform pg_temp.t(v_d #>> '{dispute,opened_by}' = 'provider', '23 dossiê informa que o PROFISSIONAL abriu a contestação');
  perform pg_temp.t(v_d #>> '{dispute,reason}' = 'Cliente não liberou o serviço', '24 dossiê traz o motivo reportado');
  perform pg_temp.t(v_d ->> 'payment_status' = 'escrow', '25 dossiê mostra o bloqueio preventivo (escrow)');
  reset role;

  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (MATCH DE CATEGORIA) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
