-- =============================================================================
-- Conquistas do profissional (estilo troféus)
--
-- 9 categorias x 10 níveis (1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000).
-- O catálogo (nomes/ícones) vive no app (core/models/achievements.dart); o banco
-- guarda só o que foi DESBLOQUEADO (código = <categoria>_<limite>) e calcula os
-- contadores a partir de dados reais (serviços, avaliações reveladas, pílulas...).
--
-- Desbloqueio automático: gatilho em jobs (serviço concluído) e na revelação das
-- avaliações. Nada é editável pelo app.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabela de desbloqueios
-- ---------------------------------------------------------------------------
create table if not exists public.provider_achievements (
  provider_id uuid not null references public.profiles(id) on delete cascade,
  code        text not null check (code ~ '^[a-z_]+_[0-9]+$'),
  unlocked_at timestamptz not null default timezone('utc', now()),
  primary key (provider_id, code)
);
create index if not exists provider_achievements_recent_idx
  on public.provider_achievements (provider_id, unlocked_at desc);

alter table public.provider_achievements enable row level security;
revoke all on public.provider_achievements from anon;
revoke insert, update, delete on public.provider_achievements from authenticated;
grant  select on public.provider_achievements to authenticated;

-- O dono, a equipe e (como vitrine) qualquer usuário logado veem as conquistas de profissionais ativos.
drop policy if exists provider_achievements_select on public.provider_achievements;
create policy provider_achievements_select on public.provider_achievements for select to authenticated
  using (provider_id = auth.uid() or public.is_admin() or public.is_public_provider(provider_id));

-- ---------------------------------------------------------------------------
-- 2. Contadores (interno) e contadores do próprio usuário (RPC)
-- ---------------------------------------------------------------------------
create or replace function public._achievement_counts(p_provider uuid)
returns table (category text, n int)
language sql stable security definer set search_path = public as $$
  with rv as (
    select r.rating, r.tags
      from public.reviews r join public.jobs j on j.id = r.job_id
     where r.reviewee_id = p_provider and r.reviewee_id = j.provider_id
       and r.reviewer_id = j.client_id and r.revealed_at is not null)
  select 'services', count(*)::int from public.jobs where provider_id = p_provider and status = 'completed'
  union all select 'five_star', count(*)::int from rv where rating = 5
  union all select 'punctual',   count(*)::int from rv where 'Super pontual'        = any (tags)
  union all select 'tidy',       count(*)::int from rv where 'Limpou tudo depois'   = any (tags)
  union all select 'fair_price', count(*)::int from rv where 'Preço honesto'        = any (tags)
  union all select 'skilled',    count(*)::int from rv where 'Mestre no que faz'    = any (tags)
  union all select 'courteous',  count(*)::int from rv where 'Educado e confiável'  = any (tags)
  union all select 'emergency',  count(*)::int from public.jobs
                                  where provider_id = p_provider and status = 'completed' and urgency = 'emergency'
  union all select 'repeat_clients', count(*)::int from (
              select client_id from public.jobs
               where provider_id = p_provider and status = 'completed'
               group by client_id having count(*) >= 2) s;
$$;
revoke all on function public._achievement_counts(uuid) from public, anon, authenticated;

create or replace function public.my_achievement_counts()
returns table (category text, n int)
language sql stable security definer set search_path = public as $$
  select * from public._achievement_counts(auth.uid());
$$;
revoke all on function public.my_achievement_counts() from public, anon;
grant execute on function public.my_achievement_counts() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Avaliação e desbloqueio
-- ---------------------------------------------------------------------------
create or replace function public.refresh_provider_achievements(p_provider uuid, p_notify boolean default true)
returns int language plpgsql security definer set search_path = public as $$
declare
  c record; lim int; v_new int := 0; v_code text; v_title text; v_unit text;
  v_limits int[] := array[1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000];
begin
  if not exists (select 1 from public.profiles where id = p_provider and is_provider) then return 0; end if;
  for c in select * from public._achievement_counts(p_provider) loop
    foreach lim in array v_limits loop
      exit when c.n < lim;
      v_code := c.category || '_' || lim;
      insert into public.provider_achievements (provider_id, code) values (p_provider, v_code)
        on conflict do nothing;
      if found then
        v_new := v_new + 1;
        if p_notify then
          v_unit := case c.category
            when 'services' then 'serviços concluídos' when 'five_star' then 'avaliações 5 estrelas'
            when 'punctual' then 'elogios de pontualidade' when 'tidy' then 'elogios de organização'
            when 'fair_price' then 'elogios de preço justo' when 'skilled' then 'elogios de qualidade do trabalho'
            when 'courteous' then 'elogios de cortesia' when 'emergency' then 'emergências atendidas'
            else 'clientes recorrentes' end;
          v_title := lim || ' ' || v_unit;
          perform public.notify_user(p_provider, 'achievement', 'Conquista desbloqueada',
            v_title || ' — veja em Minhas conquistas.', null);
        end if;
      end if;
    end loop;
  end loop;
  return v_new;
end $$;
revoke all on function public.refresh_provider_achievements(uuid, boolean) from public, anon, authenticated;

-- Serviço concluído -> recalcula o profissional
create or replace function public.jobs_achievements_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' and new.provider_id is not null then
    perform public.refresh_provider_achievements(new.provider_id);
  end if;
  return new;
end $$;
revoke all on function public.jobs_achievements_trigger() from public, anon, authenticated;

drop trigger if exists jobs_achievements on public.jobs;
create trigger jobs_achievements after update of status on public.jobs
  for each row execute function public.jobs_achievements_trigger();

-- Revelação das avaliações (avaliações 5★ e pílulas só contam depois de reveladas)
create or replace function public.reveal_job_reviews(p_job uuid)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; r record;
begin
  update public.reviews set revealed_at = now() where job_id = p_job and revealed_at is null;
  if not found then return; end if;
  select * into j from public.jobs where id = p_job;
  if j.provider_id is not null then
    perform public.refresh_provider_reputation(j.provider_id);
    perform public.refresh_provider_achievements(j.provider_id);
  end if;
  for r in select reviewee_id from public.reviews where job_id = p_job loop
    perform public.notify_user(r.reviewee_id, 'review_revealed', 'Avaliação disponível',
      'Você recebeu uma avaliação do serviço "' || coalesce(j.title, '') || '".', p_job);
  end loop;
end $$;
revoke all on function public.reveal_job_reviews(uuid) from public, anon, authenticated;

-- Migra o histórico (sem notificar)
do $$ declare r record; begin
  for r in select id from public.profiles where is_provider loop
    perform public.refresh_provider_achievements(r.id, false);
  end loop;
end $$;
