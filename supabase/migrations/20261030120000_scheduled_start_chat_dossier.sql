-- ============================================================================
-- DESPERRENGUE — Serviço AGENDADO x EM EXECUÇÃO, trava de horário + geofence,
-- chat idempotente/arquivado, dossiês e sanitização de nomes.
--
-- POR QUÊ (testes reais em 2 celulares):
--  * Serviço marcado para 31/10 já abria com cronômetro rodando e "Finalizar" liberado em 29/10,
--    longe da casa do cliente. Agora o pagamento deixa o serviço em `scheduled`; só a RPC
--    `start_job` (relógio do SERVIDOR + distância de Haversine <= raio) o move para `in_progress`.
--    Como evidências/PIN/conclusão já exigem `in_progress`, o servidor passa a recusar finalizar
--    um serviço que nunca começou (falha fechada).
--  * Mensagem duplicada: `messages.client_message_id` + UNIQUE torna o envio idempotente.
--  * Conversa de serviço encerrado fica arquivada (INSERT recusado) e continua legível.
--  * `profiles.full_name` podia ser um e-mail e vazava na UI: `safe_name()` sanitiza no servidor.
-- ============================================================================

-- ---------------------------------------------------------------- helpers
create or replace function public.haversine_m(lat1 double precision, lng1 double precision,
                                              lat2 double precision, lng2 double precision)
returns double precision language sql immutable parallel safe as $$
  -- Fórmula de Haversine (esfera de raio 6.371 km): distância em METROS entre dois pontos.
  select 2 * 6371000.0 * asin(least(1.0, sqrt(
           power(sin(radians(lat2 - lat1) / 2), 2) +
           cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2))))
$$;

create or replace function public.safe_name(p_name text, p_fallback text default 'Cliente')
returns text language sql immutable as $$
  select case when p_name is null or btrim(p_name) = '' or position('@' in p_name) > 0
              then p_fallback else btrim(p_name) end
$$;

create or replace function public.server_time() returns timestamptz
language sql stable as $$ select now() $$;
revoke all on function public.server_time() from public, anon;
grant execute on function public.server_time() to authenticated;

-- _short_name agora também esconde e-mail ("Maria S." / "Cliente").
create or replace function public._short_name(p_name text) returns text
language sql immutable as $$
  select case
    when coalesce(btrim(p_name), '') = '' then 'Usuário removido'
    when position('@' in p_name) > 0 then 'Cliente'
    when position(' ' in btrim(p_name)) = 0 then btrim(p_name)
    else split_part(btrim(p_name), ' ', 1) || ' ' || upper(left(regexp_replace(btrim(p_name), '^.*\s', ''), 1)) || '.'
  end;
$$;

-- ---------------------------------------------------------------- jobs: início real
alter table public.jobs
  add column if not exists started_at       timestamptz,
  add column if not exists start_simulated  boolean not null default false,
  add column if not exists start_distance_m numeric;

alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check
  check (status in ('open', 'awaiting_payment', 'scheduled', 'in_progress', 'awaiting_approval', 'completed', 'canceled', 'disputed'));

-- Já pagos e ainda sem início real (nunca tiveram "Iniciar"): voltam a `scheduled` se a data é futura.
update public.jobs set status = 'scheduled'
 where status = 'in_progress' and urgency = 'scheduled' and started_at is null
   and scheduled_for is not null and scheduled_for > now();
-- Os demais em andamento: o início real é o pagamento (histórico).
update public.jobs set started_at = coalesce(paid_at, created_at)
 where status in ('in_progress', 'awaiting_approval', 'completed', 'disputed') and started_at is null;

insert into public.app_settings (key, value) values ('checkin_sandbox', 'true')
on conflict (key) do nothing;

-- ---------------------------------------------------------------- destino do serviço (privado)
create table if not exists public.job_geo (
  job_id          uuid primary key references public.jobs(id) on delete cascade,
  lat             double precision not null check (lat between -90 and 90),
  lng             double precision not null check (lng between -180 and 180),
  precision_level text not null check (precision_level in ('house', 'street', 'locality')),
  source          text not null default 'nominatim',
  display_name    text,
  resolved_at     timestamptz not null default now()
);
alter table public.job_geo enable row level security;
revoke all on public.job_geo from anon, authenticated;
grant select on public.job_geo to authenticated;
drop policy if exists job_geo_select on public.job_geo;
create policy job_geo_select on public.job_geo for select to authenticated using (
  public.is_admin() or exists (select 1 from public.jobs j where j.id = job_id
                                and (j.client_id = auth.uid() or j.provider_id = auth.uid())));

-- Raio de tolerância por qualidade do ponto: GPS do cliente/casa = 100 m; só a rua (OSM sem número) = 250 m;
-- só a cidade/bairro = 0 (impreciso demais para validar presença; só a homologação libera).
create or replace function public._job_destination(j public.jobs) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare g public.job_geo%rowtype;
begin
  if j.latitude is not null and j.longitude is not null then
    return jsonb_build_object('lat', j.latitude, 'lng', j.longitude, 'precision', 'exact', 'radius_m', 100, 'source', 'client');
  end if;
  select * into g from public.job_geo where job_id = j.id;
  if found then
    return jsonb_build_object('lat', g.lat, 'lng', g.lng, 'precision', g.precision_level,
             'radius_m', case g.precision_level when 'house' then 100 when 'street' then 250 else 0 end,
             'source', g.source);
  end if;
  return null;
end $$;
revoke all on function public._job_destination(public.jobs) from public, anon, authenticated;

create or replace function public.job_destination(p_job uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare j public.jobs%rowtype;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  select * into j from public.jobs where id = p_job and (client_id = auth.uid() or provider_id = auth.uid());
  if not found then return null; end if;
  return public._job_destination(j);
end $$;
revoke all on function public.job_destination(uuid) from public, anon;
grant execute on function public.job_destination(uuid) to authenticated;

-- ---------------------------------------------------------------- pagamento -> AGENDADO
do $$
declare d text; r text;
begin
  d := pg_get_functiondef('public.pay_job_mock(uuid,text,timestamptz)'::regprocedure);
  if position('set status = ''in_progress'', payment_status = ''escrow'', paid_at = now(),' in d) = 0 then
    raise exception 'pay_job_mock mudou: ajuste o patch desta migration.';
  end if;
  r := replace(d, 'set status = ''in_progress'', payment_status = ''escrow'', paid_at = now(),',
    'set status = case when urgency = ''emergency'' then ''in_progress'' else ''scheduled'' end, payment_status = ''escrow'', paid_at = now(), started_at = case when urgency = ''emergency'' then now() end,');
  r := replace(r, 'está em custódia. Pode iniciar o serviço.', 'está em custódia. O serviço está agendado: você poderá iniciá-lo no local, no horário combinado.');
  execute r;
end $$;

-- Emergência: o atendimento começa no aceite (não há agenda a respeitar).
do $$
declare d text;
begin
  d := pg_get_functiondef('public.accept_emergency(uuid)'::regprocedure);
  if position('set status = ''in_progress'', provider_id = auth.uid(), accepted_quote_id = v_quote' in d) = 0 then
    raise exception 'accept_emergency mudou: ajuste o patch desta migration.';
  end if;
  execute replace(d, 'set status = ''in_progress'', provider_id = auth.uid(), accepted_quote_id = v_quote',
                     'set status = ''in_progress'', started_at = now(), provider_id = auth.uid(), accepted_quote_id = v_quote');
end $$;

-- ---------------------------------------------------------------- start_job (dupla trava)
create or replace function public.start_job(p_job uuid,
                                            p_lat double precision default null,
                                            p_lng double precision default null,
                                            p_accuracy_m double precision default null,
                                            p_simulate boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  j public.jobs%rowtype; v_sand boolean; dest jsonb; v_dist double precision; v_radius double precision;
  v_now timestamptz := now(); v_window constant interval := interval '15 minutes';
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  select * into j from public.jobs where id = p_job and provider_id = auth.uid() for update;
  if not found or j.status <> 'scheduled' then
    raise exception 'START_INVALID_STATE' using errcode = 'P0001';
  end if;
  select coalesce((select value = 'true' from public.app_settings where key = 'checkin_sandbox'), false) into v_sand;

  if p_simulate then
    -- Homologação: só funciona com app_settings.checkin_sandbox = 'true' (desligue em produção).
    if not v_sand then raise exception 'START_SANDBOX_OFF' using errcode = '42501'; end if;
  else
    -- 1) Trava TEMPORAL com o relógio do SERVIDOR (o do celular pode ser adulterado).
    if j.scheduled_for is not null and v_now < j.scheduled_for - v_window then
      raise exception 'START_TOO_EARLY|%', to_char((j.scheduled_for - v_window) at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        using errcode = 'P0001';
    end if;
    -- 2) Trava GEOESPACIAL (Haversine) no servidor: o app só envia a posição; a conta é feita aqui.
    if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
      raise exception 'START_NO_POSITION' using errcode = 'P0001';
    end if;
    if p_accuracy_m is not null and p_accuracy_m > 100 then
      raise exception 'START_LOW_ACCURACY|%', round(p_accuracy_m) using errcode = 'P0001';
    end if;
    dest := public._job_destination(j);
    if dest is null then raise exception 'START_NO_DESTINATION' using errcode = 'P0001'; end if;
    v_radius := (dest ->> 'radius_m')::double precision;
    if v_radius <= 0 then raise exception 'START_DESTINATION_IMPRECISE' using errcode = 'P0001'; end if;
    v_dist := public.haversine_m(p_lat, p_lng, (dest ->> 'lat')::double precision, (dest ->> 'lng')::double precision);
    if v_dist > v_radius then
      raise exception 'START_TOO_FAR|%|%', round(v_dist), round(v_radius) using errcode = 'P0001';
    end if;
  end if;

  update public.jobs
     set status = 'in_progress', started_at = v_now, start_simulated = p_simulate,
         start_distance_m = case when p_simulate then null else round(v_dist::numeric, 1) end
   where id = j.id;
  perform public.notify_user(j.client_id, 'service_started', 'Serviço iniciado',
    'O profissional iniciou "' || j.title || '".', j.id);
  return jsonb_build_object('ok', true, 'started_at', v_now, 'simulated', p_simulate,
                            'distance_m', case when p_simulate then null else round(v_dist::numeric, 1) end);
end $$;
revoke all on function public.start_job(uuid, double precision, double precision, double precision, boolean) from public, anon;
grant execute on function public.start_job(uuid, double precision, double precision, double precision, boolean) to authenticated;

-- ---------------------------------------------------------------- estados que também contam "agendado"
do $$
declare d text;
begin
  d := pg_get_functiondef('public._deletion_blockers(uuid)'::regprocedure);
  if position('status in (''in_progress'', ''awaiting_approval'', ''disputed'')' in d) = 0 then raise exception '_deletion_blockers mudou'; end if;
  execute replace(d, 'status in (''in_progress'', ''awaiting_approval'', ''disputed'')', 'status in (''scheduled'', ''in_progress'', ''awaiting_approval'', ''disputed'')');

  d := pg_get_functiondef('public.create_support_ticket(uuid,text,text,text[])'::regprocedure);
  if position('j.status in (''in_progress'', ''awaiting_approval'')' in d) = 0 then raise exception 'create_support_ticket mudou'; end if;
  execute replace(d, 'j.status in (''in_progress'', ''awaiting_approval'')', 'j.status in (''scheduled'', ''in_progress'', ''awaiting_approval'')');
end $$;

create or replace view public.provider_busy_slots as
  select provider_id, scheduled_for
    from public.jobs j
   where scheduled_for is not null
     and status = any (array['awaiting_payment', 'scheduled', 'in_progress', 'awaiting_approval'])
     and public.is_public_provider(provider_id);

-- ---------------------------------------------------------------- chat
alter table public.messages add column if not exists client_message_id uuid;
alter table public.messages drop constraint if exists messages_client_msg_uniq;
alter table public.messages add constraint messages_client_msg_uniq unique (job_id, sender_id, client_message_id);
grant insert (client_message_id) on public.messages to authenticated;

-- Conversa de serviço encerrado fica ARQUIVADA: leitura sim, escrita não (também no servidor).
create or replace function public._messages_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  select status into v_status from public.jobs where id = new.job_id;
  if v_status in ('completed', 'canceled') then
    raise exception 'CHAT_ARCHIVED: esta conversa foi arquivada.' using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke all on function public._messages_guard() from public, anon, authenticated;
drop trigger if exists messages_guard on public.messages;
create trigger messages_guard before insert on public.messages for each row execute function public._messages_guard();

-- Quem foi contratado continua podendo LER a conversa mesmo após conclusão/cancelamento
-- (o orçamento vira `rejected` no cancelamento e antes cortava o acesso ao histórico).
create or replace function public.can_chat(p_job uuid, p_provider uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select (exists (select 1 from public.quotes q
                   where q.job_id = p_job and q.provider_id = p_provider and q.status in ('pending', 'accepted'))
          or exists (select 1 from public.jobs j where j.id = p_job and j.provider_id = p_provider))
     and (public.owns_job(p_job) or auth.uid() = p_provider or public.is_admin());
$$;

create or replace function public.chat_counterpart(p_job uuid, p_provider uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare j public.jobs%rowtype; v jsonb;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  if not public.can_chat(p_job, p_provider) then return null; end if;
  select * into j from public.jobs where id = p_job;
  if auth.uid() = p_provider then
    -- Profissional vendo o cliente: nome completo só depois da contratação (antes, só o primeiro nome).
    select jsonb_build_object('id', c.id, 'role', 'client',
             'name', public.safe_name(case when j.provider_id = auth.uid() then c.full_name else split_part(c.full_name, ' ', 1) end, 'Cliente'),
             'avatar_url', c.avatar_url, 'subtitle', c.address_city)
      into v from public.profiles c where c.id = j.client_id;
  else
    select jsonb_build_object('id', p.id, 'role', 'provider', 'name', public.safe_name(p.full_name, 'Profissional'),
             'avatar_url', p.avatar_url, 'subtitle', coalesce(pp.specialties[1], pp.headline))
      into v from public.profiles p left join public.provider_profiles pp on pp.user_id = p.id where p.id = p_provider;
  end if;
  return v;
end $$;
revoke all on function public.chat_counterpart(uuid, uuid) from public, anon;
grant execute on function public.chat_counterpart(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------- nomes seguros nas views
create or replace view public.job_client_cards as
 select j.id as job_id, j.client_id,
        case when j.client_id = auth.uid() or j.provider_id = auth.uid()
             then public.safe_name(p.full_name, 'Cliente')
             else public.safe_name(split_part(p.full_name, ' ', 1), 'Cliente') end as full_name,
        p.avatar_url, p.address_city
   from public.jobs j join public.profiles p on p.id = j.client_id
  where j.client_id = auth.uid() or j.provider_id = auth.uid() or public.is_admin()
     or public.is_invited(j.id) or public.has_quoted_job(j.id)
     or (j.status = 'open' and j.visibility = 'open' and public.is_active_provider());

create or replace view public.public_reviews as
 select r.id, r.reviewee_id as provider_id, r.rating, r.comment, r.tags, r.created_at, r.photo_paths, r.reply, r.reply_at,
        case when public.safe_name(p.full_name, '') = '' then 'Cliente'
             else split_part(p.full_name, ' ', 1) ||
                  case when position(' ' in p.full_name) > 0 then ' ' || left(split_part(p.full_name, ' ', 2), 1) || '.' else '' end
        end as reviewer_name,
        p.avatar_url as reviewer_avatar
   from public.reviews r
   join public.profiles p on p.id = r.reviewer_id
   join public.jobs j on j.id = r.job_id
  where r.reviewee_id = j.provider_id and r.revealed_at is not null and public.is_public_provider(r.reviewee_id);

-- ---------------------------------------------------------------- dossiês (privados)
-- Profissional contratado: tudo do serviço, inclusive financeiro. Nada disto existe em view pública.
create or replace function public.provider_job_dossier(p_job uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare j public.jobs%rowtype; pay public.payments%rowtype; a public.job_addresses%rowtype;
        c public.profiles%rowtype; r public.reviews%rowtype; v_review jsonb;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  select * into j from public.jobs where id = p_job and provider_id = auth.uid();
  if not found then return null; end if;
  select * into pay from public.payments where job_id = j.id;
  select * into a from public.job_addresses where job_id = j.id;
  select * into c from public.profiles where id = j.client_id;
  select * into r from public.reviews where job_id = j.id and reviewee_id = j.provider_id and reviewer_id = j.client_id;
  if found then
    -- Avaliação cega: antes da revelação só se informa que EXISTE (nunca a nota).
    v_review := case when r.revealed_at is null then jsonb_build_object('state', 'hidden')
                else jsonb_build_object('state', 'revealed', 'rating', r.rating, 'tags', to_jsonb(r.tags),
                       'comment', r.comment, 'photo_paths', to_jsonb(r.photo_paths), 'reply', r.reply, 'created_at', r.created_at) end;
  end if;
  return jsonb_build_object(
    'job_id', j.id, 'code', '#DSP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
    'status', j.status, 'payment_status', j.payment_status,
    'title', j.title, 'description', j.description, 'category', j.category,
    'address_line', a.address_line, 'complement', a.complement, 'reference', a.reference, 'address_summary', j.address_summary,
    'scheduled_for', j.scheduled_for, 'started_at', j.started_at, 'started_simulated', j.start_simulated,
    'finished_at', coalesce(j.approved_at, j.finished_at),
    'gross', coalesce(pay.amount, j.agreed_price, 0), 'fee', coalesce(pay.fee_amount, 0),
    'fee_pct', coalesce(pay.fee_pct, 0), 'net', coalesce(pay.net_amount, 0),
    'client', jsonb_build_object('id', c.id, 'name', public.safe_name(c.full_name, 'Cliente'), 'avatar_url', c.avatar_url),
    'report', j.provider_report, 'photo_paths', to_jsonb(coalesce(j.photo_paths, '{}')),
    'evidence', coalesce((select jsonb_agg(jsonb_build_object('slot', e.slot, 'path', e.path)
                          order by array_position(array['overview', 'detail', 'angle', 'clean', 'video'], e.slot))
                           from public.job_evidence e where e.job_id = j.id), '[]'::jsonb),
    'review', v_review);
end $$;
revoke all on function public.provider_job_dossier(uuid) from public, anon;
grant execute on function public.provider_job_dossier(uuid) to authenticated;

-- Cliente dono: histórico do serviço (valor pago, profissional, evidências). Sem taxa/líquido do profissional.
create or replace function public.client_job_dossier(p_job uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare j public.jobs%rowtype; pay public.payments%rowtype; r public.reviews%rowtype; v_my jsonb; v_prov jsonb;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  select * into j from public.jobs where id = p_job and client_id = auth.uid();
  if not found then return null; end if;
  select * into pay from public.payments where job_id = j.id;
  select * into r from public.reviews where job_id = j.id and reviewer_id = j.client_id and reviewee_id = j.provider_id;
  if found then
    v_my := jsonb_build_object('rating', r.rating, 'tags', to_jsonb(r.tags), 'comment', r.comment, 'created_at', r.created_at);
  end if;
  if j.provider_id is not null then
    select jsonb_build_object('id', p.id, 'name', public.safe_name(p.full_name, 'Profissional'), 'avatar_url', p.avatar_url,
             'title', coalesce(pp.specialties[1], pp.headline), 'rating_avg', pp.rating_avg, 'rating_count', pp.rating_count)
      into v_prov from public.profiles p left join public.provider_profiles pp on pp.user_id = p.id where p.id = j.provider_id;
  end if;
  return jsonb_build_object(
    'job_id', j.id, 'code', '#DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
    'title', j.title, 'description', j.description, 'category', j.category, 'status', j.status,
    'scheduled_for', j.scheduled_for, 'started_at', j.started_at, 'finished_at', coalesce(j.approved_at, j.finished_at),
    'address_summary', j.address_summary, 'photo_paths', to_jsonb(coalesce(j.photo_paths, '{}')),
    'amount', coalesce(pay.amount, j.agreed_price, 0), 'payment_status', j.payment_status,
    'provider', v_prov, 'report', j.provider_report,
    'evidence', coalesce((select jsonb_agg(jsonb_build_object('slot', e.slot, 'path', e.path)
                          order by array_position(array['overview', 'detail', 'angle', 'clean', 'video'], e.slot))
                           from public.job_evidence e where e.job_id = j.id), '[]'::jsonb),
    'my_review', v_my);
end $$;
revoke all on function public.client_job_dossier(uuid) from public, anon;
grant execute on function public.client_job_dossier(uuid) to authenticated;

-- Avaliações recebidas (só as reveladas) COM `job_id`, só para o próprio profissional.
create or replace function public.my_received_reviews() returns setof jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', r.id, 'job_id', r.job_id, 'rating', r.rating, 'comment', r.comment,
           'tags', to_jsonb(r.tags), 'photo_paths', to_jsonb(r.photo_paths), 'reply', r.reply, 'reply_at', r.reply_at,
           'created_at', r.created_at, 'reviewer_name', public._short_name(p.full_name), 'reviewer_avatar', p.avatar_url)
    from public.reviews r
    join public.jobs j on j.id = r.job_id
    left join public.profiles p on p.id = r.reviewer_id
   where r.reviewee_id = auth.uid() and r.revealed_at is not null and j.provider_id = auth.uid()
   order by r.created_at desc;
$$;
revoke all on function public.my_received_reviews() from public, anon;
grant execute on function public.my_received_reviews() to authenticated;
