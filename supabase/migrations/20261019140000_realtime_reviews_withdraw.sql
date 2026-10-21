-- ============================================================================
-- DESPERRENGUE — Migration 6: realtime, retirada de proposta, avaliações públicas
-- ============================================================================

begin;

-- Realtime para as telas que reagem a eventos (orçamento chegou, notificação, etc.)
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'quotes') then
      alter publication supabase_realtime add table public.quotes;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications') then
      alter publication supabase_realtime add table public.notifications;
    end if;
  end if;
end $$;

-- Orçamentos retirados não contam para o limite de 3
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
  end if;

  select count(*) into v_count from public.quotes where job_id = new.job_id and status <> 'withdrawn';
  if v_count >= 3 then
    raise exception 'QUOTE_LIMIT_REACHED: esta demanda já recebeu 3 orçamentos.' using errcode = 'P0001';
  end if;

  update public.job_invites set status = 'quoted'
   where job_id = new.job_id and provider_id = new.provider_id;
  return new;
end $$;

-- Profissional retira a proposta enquanto o cliente não decidiu
create or replace function public.withdraw_quote(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.quotes set status = 'withdrawn'
   where job_id = p_job_id and provider_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'Proposta não pode ser retirada.' using errcode = 'P0001';
  end if;
  update public.jobs set quote_count = greatest(quote_count - 1, 0) where id = p_job_id;
  update public.job_invites set status = 'withdrawn'
   where job_id = p_job_id and provider_id = auth.uid();
end $$;

-- Cliente recusa um orçamento específico
create or replace function public.reject_quote(p_quote_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prov uuid; v_job uuid; v_title text;
begin
  update public.quotes q set status = 'rejected'
    from public.jobs j
   where q.id = p_quote_id and j.id = q.job_id and j.client_id = auth.uid()
     and j.status = 'open' and q.status = 'pending'
  returning q.provider_id, q.job_id, j.title into v_prov, v_job, v_title;
  if not found then
    raise exception 'Orçamento indisponível.' using errcode = 'P0001';
  end if;
  perform public.notify_user(v_prov, 'quote_rejected', 'Orçamento recusado',
    'O cliente recusou seu orçamento para "' || v_title || '".', v_job);
end $$;

revoke all on function public.withdraw_quote(uuid), public.reject_quote(uuid) from public, anon;
grant execute on function public.withdraw_quote(uuid), public.reject_quote(uuid) to authenticated;

-- Avaliações públicas dos profissionais (só de clientes, sem expor dados pessoais)
drop view if exists public.public_reviews;
create view public.public_reviews as
  select r.id, r.reviewee_id as provider_id, r.rating, r.comment, r.tags, r.created_at,
         split_part(p.full_name, ' ', 1) ||
           case when position(' ' in p.full_name) > 0
                then ' ' || left(split_part(p.full_name, ' ', 2), 1) || '.' else '' end as reviewer_name,
         p.avatar_url as reviewer_avatar
    from public.reviews r
    join public.profiles p on p.id = r.reviewer_id
    join public.jobs j on j.id = r.job_id
   where r.reviewee_id = j.provider_id
     and public.is_public_provider(r.reviewee_id);
revoke all on public.public_reviews from anon;
grant  select on public.public_reviews to authenticated;

-- Dias ocupados do profissional (agenda pública mínima): só datas, sem dados do cliente
drop view if exists public.provider_busy_slots;
create view public.provider_busy_slots as
  select j.provider_id, j.scheduled_for
    from public.jobs j
   where j.scheduled_for is not null
     and j.status in ('awaiting_payment', 'in_progress', 'awaiting_approval')
     and public.is_public_provider(j.provider_id);
revoke all on public.provider_busy_slots from anon;
grant  select on public.provider_busy_slots to authenticated;

commit;
