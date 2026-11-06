-- =============================================================================
-- DESPERRENGUE — Match de categoria por tag canônica, pedido restrito à categoria,
-- notificação dos profissionais da área e dossiê completo do cliente.
--
-- 1. norm_tag/norm_tags: normalização canônica (sem acento, minúsculas, sinônimos). É o
--    ESPELHO de app/lib/core/utils/tag_normalizer.dart — mudou lá, mude aqui.
-- 2. Índice GIN em norm_tags(specialties) + coluna `specialty_slugs` na view pública:
--    o app filtra por categoria na própria query (O(log N)), inclusive com N tags por perfil.
-- 3. Isolamento por categoria: um pedido PÚBLICO só é visível/orçável por profissionais que
--    atendem a categoria dele (RLS de jobs, cartão do cliente, fotos no storage e trigger de orçamento).
-- 4. Notificação "novo pedido da sua área" aos profissionais que atendem a categoria.
-- 5. Cancelamento registra quando/por quê; client_job_dossier devolve tudo que o detalhe
--    do pedido precisa (endereço completo, coordenadas, cancelamento e mediação).
-- =============================================================================
begin;

-- ---------------------------------------------------------------------------
-- 1. Normalização canônica
-- ---------------------------------------------------------------------------
create or replace function public.norm_tag(p_tag text)
returns text language plpgsql immutable parallel safe as $$
declare n text;
begin
  if p_tag is null then return ''; end if;
  n := lower(btrim(p_tag));
  n := translate(n, 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn');
  n := btrim(regexp_replace(n, '\s+', ' ', 'g'));
  return case n
    when 'eletrica' then 'eletrica'
    when 'eletricista' then 'eletrica'
    when 'eletricidade' then 'eletrica'
    when 'instalacao eletrica' then 'eletrica'
    when 'instalacoes eletricas' then 'eletrica'
    when 'encanador' then 'encanador'
    when 'encanamento' then 'encanador'
    when 'hidraulica' then 'encanador'
    when 'hidraulico' then 'encanador'
    when 'bombeiro hidraulico' then 'encanador'
    when 'limpeza' then 'limpeza'
    when 'diarista' then 'limpeza'
    when 'faxina' then 'limpeza'
    when 'faxineira' then 'limpeza'
    when 'faxineiro' then 'limpeza'
    when 'montagem' then 'montagem'
    when 'montador' then 'montagem'
    when 'montagem de moveis' then 'montagem'
    when 'montador de moveis' then 'montagem'
    when 'pintura' then 'pintura'
    when 'pintor' then 'pintura'
    when 'chaveiro' then 'chaveiro'
    when 'chaveiros' then 'chaveiro'
    when 'pedreiro' then 'pedreiro'
    when 'alvenaria' then 'pedreiro'
    when 'gesso' then 'gesso'
    when 'gesseiro' then 'gesso'
    when 'drywall' then 'gesso'
    when 'marcenaria' then 'marcenaria'
    when 'marceneiro' then 'marcenaria'
    when 'carpintaria' then 'marcenaria'
    when 'carpinteiro' then 'marcenaria'
    else n
  end;
end $$;

create or replace function public.norm_tags(p_tags text[])
returns text[] language sql immutable parallel safe as $$
  select coalesce(array_agg(distinct s.t), '{}'::text[])
    from (select public.norm_tag(x) as t from unnest(coalesce(p_tags, '{}'::text[])) as x) s
   where s.t <> '';
$$;

-- ---------------------------------------------------------------------------
-- 2. Índice + coluna `specialty_slugs` na view pública
-- ---------------------------------------------------------------------------
create index if not exists provider_profiles_specialty_slugs_gin
  on public.provider_profiles using gin (public.norm_tags(specialties));

-- Mesma definição da migration 20261023100000, com a coluna nova NO FIM (create or replace).
create or replace view public.provider_public_profiles as
  select p.id, p.full_name, p.avatar_url, p.bio, p.address_city,
         pp.headline, pp.specialties, pp.hourly_rate, pp.visit_fee, pp.service_radius_km,
         pp.rating_avg, pp.rating_count, pp.jobs_done, pp.accepting_jobs,
         p.latitude, p.longitude,
         pp.badges,
         round(
           (coalesce(pp.rating_count, 0)::numeric / (coalesce(pp.rating_count, 0) + public.ranking_min_reviews()))
             * coalesce(pp.rating_recent_avg, 0)
           + (public.ranking_min_reviews() / (coalesce(pp.rating_count, 0) + public.ranking_min_reviews()))
             * (select public.platform_avg_rating()), 3) as rank_score,
         public.norm_tags(pp.specialties) as specialty_slugs
    from public.profiles p
    left join public.provider_profiles pp on pp.user_id = p.id
   where p.is_provider and p.verification_status = 'ACTIVE';
revoke all on public.provider_public_profiles from anon;
grant  select on public.provider_public_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Isolamento por categoria
-- ---------------------------------------------------------------------------
-- O profissional logado atende esta categoria? (qualquer uma das N tags dele)
create or replace function public.provider_matches_category(p_category text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.provider_profiles pp
     where pp.user_id = auth.uid()
       and public.norm_tags(pp.specialties) @> array[public.norm_tag(p_category)]
       and public.norm_tag(p_category) <> '');
$$;
revoke all on function public.provider_matches_category(text) from public, anon;
grant execute on function public.provider_matches_category(text) to authenticated;

-- jobs visíveis: o feed aberto só chega a quem atende a categoria do pedido
drop policy if exists jobs_select on public.jobs;
create policy jobs_select on public.jobs for select to authenticated using (
  client_id = auth.uid()
  or provider_id = auth.uid()
  or public.is_admin()
  or public.is_invited(id)
  or (status = 'open' and visibility = 'open' and public.is_active_provider()
      and public.provider_matches_category(category))
  or public.has_quoted_job(id)
);

-- cartão do cliente acompanha a mesma regra (definição de 20261030120000 + categoria)
create or replace view public.job_client_cards as
 select j.id as job_id, j.client_id,
        case when j.client_id = auth.uid() or j.provider_id = auth.uid()
             then public.safe_name(p.full_name, 'Cliente')
             else public.safe_name(split_part(p.full_name, ' ', 1), 'Cliente') end as full_name,
        p.avatar_url, p.address_city
   from public.jobs j join public.profiles p on p.id = j.client_id
  where j.client_id = auth.uid() or j.provider_id = auth.uid() or public.is_admin()
     or public.is_invited(j.id) or public.has_quoted_job(j.id)
     or (j.status = 'open' and j.visibility = 'open' and public.is_active_provider()
         and public.provider_matches_category(j.category));

-- fotos do pedido no storage: mesma regra (definição de 20261019130000 + categoria)
drop policy if exists "job_media_select" on storage.objects;
create policy "job_media_select" on storage.objects for select to authenticated using (
  bucket_id = 'job-media' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (select 1 from public.jobs j
                where name = any (j.photo_paths)
                  and (j.provider_id = auth.uid()
                       or public.is_invited(j.id)
                       or (j.status = 'open' and j.visibility = 'open' and public.is_active_provider()
                           and public.provider_matches_category(j.category))
                       or public.has_quoted_job(j.id)))
    or exists (select 1 from public.job_evidence e
                where e.path = name and public.owns_job(e.job_id))
  )
);

-- orçamento: pedido público só recebe orçamento de quem atende a categoria (ou foi convidado)
create or replace function public.quotes_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_job   public.jobs%rowtype;
  v_count int;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.job_id::text, 0));

  select * into v_job from public.jobs where id = new.job_id;
  if not found then
    raise exception 'Demanda não encontrada.' using errcode = 'P0002';
  end if;
  if v_job.status <> 'open' then
    raise exception 'A demanda não está aberta para orçamentos.' using errcode = 'P0001';
  end if;
  if v_job.client_id = new.provider_id then
    raise exception 'Você não pode orçar a sua própria demanda.' using errcode = '42501';
  end if;
  if coalesce(current_setting('app.bypass_quote_rules', true), '') = 'on' then
    update public.job_invites set status = 'quoted'
     where job_id = new.job_id and provider_id = new.provider_id and status in ('pending', 'accepted');
    return new;
  end if;
  if v_job.urgency = 'emergency' then
    raise exception 'Emergências são aceitas, não orçadas.' using errcode = 'P0001';
  end if;
  if v_job.visibility = 'direct' then
    if not exists (select 1 from public.job_invites
                    where job_id = new.job_id and provider_id = new.provider_id
                      and status = 'pending' and expires_at > now()) then
      raise exception 'Convite inexistente ou expirado.' using errcode = 'P0001';
    end if;
  elsif not exists (select 1 from public.job_invites where job_id = new.job_id and provider_id = new.provider_id)
        and not exists (select 1 from public.provider_profiles pp
                         where pp.user_id = new.provider_id
                           and public.norm_tags(pp.specialties) @> array[public.norm_tag(v_job.category)]
                           and public.norm_tag(v_job.category) <> '') then
    raise exception 'Este pedido é exclusivo de profissionais da categoria %.', v_job.category using errcode = 'P0001';
  end if;

  select count(*) into v_count from public.quotes where job_id = new.job_id and status <> 'withdrawn';
  if v_count >= 3 then
    raise exception 'QUOTE_LIMIT_REACHED: esta demanda já recebeu 3 orçamentos.' using errcode = 'P0001';
  end if;

  update public.job_invites set status = 'quoted'
   where job_id = new.job_id and provider_id = new.provider_id;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Notifica os profissionais da área quando um pedido público é publicado
-- ---------------------------------------------------------------------------
create or replace function public.jobs_notify_area_providers()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if new.visibility <> 'open' or new.urgency = 'emergency' or new.status <> 'open'
     or public.norm_tag(new.category) = '' then
    return new;
  end if;
  for r in
    select pp.user_id
      from public.provider_profiles pp
      join public.profiles p on p.id = pp.user_id
     where p.is_provider and p.verification_status = 'ACTIVE'
       and coalesce(pp.accepting_jobs, true)
       and pp.user_id <> new.client_id
       and public.norm_tags(pp.specialties) @> array[public.norm_tag(new.category)]
     limit 200
  loop
    perform public.notify_user(r.user_id, 'new_area_job', 'Novo pedido de ' || new.category,
      'Um cliente da sua região precisa de ' || new.category || ': "' || left(coalesce(new.title, ''), 60) || '". Envie seu orçamento.', new.id);
  end loop;
  return new;
end $$;
revoke all on function public.jobs_notify_area_providers() from public, anon, authenticated;

drop trigger if exists jobs_notify_area_providers on public.jobs;
create trigger jobs_notify_area_providers after insert on public.jobs
  for each row execute function public.jobs_notify_area_providers();

-- ---------------------------------------------------------------------------
-- 5. Cancelamento registrado + dossiê completo do cliente
-- ---------------------------------------------------------------------------
alter table public.jobs
  add column if not exists canceled_at   timestamptz,
  add column if not exists cancel_reason text,
  add column if not exists canceled_by   uuid;

create or replace function public.jobs_stamp_cancellation()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_reason text;
begin
  if new.status = 'canceled' and old.status is distinct from 'canceled' then
    new.canceled_at := coalesce(new.canceled_at, now());
    new.canceled_by := coalesce(new.canceled_by, auth.uid());
    if new.cancel_reason is null then
      v_reason := nullif(btrim(coalesce(current_setting('app.cancel_reason', true), '')), '');
      new.cancel_reason := coalesce(v_reason, case
        when old.status = 'disputed' then 'Mediação concluída: o valor foi devolvido ao cliente.'
        when auth.uid() is null and old.urgency = 'emergency' then 'Nenhum profissional aceitou a emergência a tempo.'
        when auth.uid() = old.client_id and old.status in ('open', 'awaiting_payment') then 'Cancelado por você antes da contratação do profissional.'
        when auth.uid() = old.client_id then 'Cancelado por você.'
        when auth.uid() = old.provider_id then 'Cancelado pelo profissional.'
        else 'Pedido cancelado automaticamente pela plataforma.' end);
    end if;
  end if;
  return new;
end $$;
revoke all on function public.jobs_stamp_cancellation() from public, anon, authenticated;

drop trigger if exists jobs_stamp_cancellation on public.jobs;
create trigger jobs_stamp_cancellation before update of status on public.jobs
  for each row execute function public.jobs_stamp_cancellation();

-- Cliente dono: histórico completo do pedido em QUALQUER estado. Sem taxa/líquido do profissional.
create or replace function public.client_job_dossier(p_job uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare j public.jobs%rowtype; pay public.payments%rowtype; r public.reviews%rowtype;
        a public.job_addresses%rowtype; g public.job_geo%rowtype;
        v_my jsonb; v_prov jsonb; v_disp jsonb;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  select * into j from public.jobs where id = p_job and client_id = auth.uid();
  if not found then return null; end if;
  select * into pay from public.payments where job_id = j.id;
  select * into a from public.job_addresses where job_id = j.id;
  select * into g from public.job_geo where job_id = j.id;
  select * into r from public.reviews where job_id = j.id and reviewer_id = j.client_id and reviewee_id = j.provider_id;
  if found then
    v_my := jsonb_build_object('rating', r.rating, 'tags', to_jsonb(r.tags), 'comment', r.comment, 'created_at', r.created_at);
  end if;
  if j.provider_id is not null then
    select jsonb_build_object('id', p.id, 'name', public.safe_name(p.full_name, 'Profissional'), 'avatar_url', p.avatar_url,
             'title', coalesce(pp.specialties[1], pp.headline), 'rating_avg', pp.rating_avg, 'rating_count', pp.rating_count)
      into v_prov from public.profiles p left join public.provider_profiles pp on pp.user_id = p.id where p.id = j.provider_id;
  end if;
  -- Contestação mais antiga do serviço (qualquer das partes): quem abriu, motivo e andamento.
  select jsonb_build_object(
           'opened_by', case when t.user_id = j.client_id then 'client' else 'provider' end,
           'reason', t.reason, 'description', t.description, 'status', t.status,
           'opened_at', t.created_at, 'resolution', t.resolution)
    into v_disp
    from public.support_tickets t where t.job_id = j.id order by t.created_at limit 1;
  return jsonb_build_object(
    'job_id', j.id, 'code', '#DESP-' || upper(substr(replace(j.id::text, '-', ''), 1, 5)),
    'title', j.title, 'description', j.description, 'category', j.category, 'status', j.status,
    'urgency', j.urgency, 'created_at', j.created_at,
    'scheduled_for', j.scheduled_for, 'started_at', j.started_at, 'finished_at', coalesce(j.approved_at, j.finished_at),
    'address_summary', j.address_summary, 'address_line', a.address_line,
    'latitude', coalesce(g.lat, j.latitude), 'longitude', coalesce(g.lng, j.longitude),
    'photo_paths', to_jsonb(coalesce(j.photo_paths, '{}')),
    'amount', coalesce(pay.amount, j.agreed_price, 0), 'payment_status', j.payment_status,
    'canceled_at', j.canceled_at, 'cancel_reason', j.cancel_reason,
    'dispute', v_disp,
    'provider', v_prov, 'report', j.provider_report,
    'evidence', coalesce((select jsonb_agg(jsonb_build_object('slot', e.slot, 'path', e.path)
                          order by array_position(array['overview', 'detail', 'angle', 'clean', 'video'], e.slot))
                           from public.job_evidence e where e.job_id = j.id), '[]'::jsonb),
    'my_review', v_my);
end $$;
revoke all on function public.client_job_dossier(uuid) from public, anon;
grant execute on function public.client_job_dossier(uuid) to authenticated;

commit;
