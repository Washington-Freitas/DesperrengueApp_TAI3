-- =============================================================================
-- Sistema de avaliações v2
--
--  1. Avaliação bidirecional CEGA: a nota só é revelada quando as DUAS partes
--     avaliaram ou 48 h depois da primeira avaliação (cron a cada 10 min).
--  2. Reputação: média simples (exibida), média com peso de recência (as 10
--     últimas valem 1,5x) e nota de RANQUEAMENTO por Média Bayesiana
--        WR = v/(v+m) * R + m/(v+m) * C
--     v = nº de avaliações, m = mínimo para estabilizar (5), R = média do
--     profissional (com recência), C = média geral da plataforma.
--  3. Selos automáticos (>= 15 marcações da mesma pílula; Super Profissional =
--     20 últimas avaliações nota 5).
--  4. Foto do serviço na avaliação ("Serviço verificado") e direito de resposta
--     pública (uma vez por avaliação).
--  5. Reputação do cliente (visível só a profissionais envolvidos com ele).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Colunas
-- ---------------------------------------------------------------------------
alter table public.reviews
  add column if not exists photo_paths text[] not null default '{}',
  add column if not exists revealed_at timestamptz,
  add column if not exists reply       text,
  add column if not exists reply_at    timestamptz;

alter table public.reviews drop constraint if exists reviews_reply_len;
alter table public.reviews add  constraint reviews_reply_len check (reply is null or char_length(reply) <= 500);
alter table public.reviews drop constraint if exists reviews_photos_max;
alter table public.reviews add  constraint reviews_photos_max check (cardinality(photo_paths) <= 3);

-- Avaliações já existentes (legado) ficam reveladas.
update public.reviews set revealed_at = created_at where revealed_at is null;

alter table public.provider_profiles
  add column if not exists rating_recent_avg numeric(4,3) not null default 0,
  add column if not exists badges text[] not null default '{}';

-- Reputação só muda por função do sistema.
create or replace function public.provider_profiles_protect()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') and tg_op = 'UPDATE' then
    if new.rating_avg is distinct from old.rating_avg
       or new.rating_count is distinct from old.rating_count
       or new.jobs_done is distinct from old.jobs_done
       or new.rating_recent_avg is distinct from old.rating_recent_avg
       or new.badges is distinct from old.badges then
      raise exception 'Reputação controlada pelo sistema.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

-- Leitura: o avaliador vê a própria; o avaliado e o público só depois de revelada.
drop policy if exists reviews_select on public.reviews;
create policy reviews_select on public.reviews for select to authenticated using (
  reviewer_id = auth.uid()
  or public.is_admin()
  or (revealed_at is not null and (reviewee_id = auth.uid() or public.is_public_provider(reviewee_id)))
);

-- ---------------------------------------------------------------------------
-- 2. Parâmetros e média da plataforma
-- ---------------------------------------------------------------------------
create or replace function public.ranking_min_reviews()
returns numeric language sql immutable as $$ select 5::numeric $$;

-- C: média de TODAS as avaliações reveladas de clientes sobre profissionais (4,5 sem dados).
create or replace function public.platform_avg_rating()
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(round(avg(r.rating)::numeric, 3), 4.5)
    from public.reviews r
    join public.jobs j on j.id = r.job_id
   where r.revealed_at is not null
     and r.reviewer_id = j.client_id and r.reviewee_id = j.provider_id;
$$;
revoke all on function public.platform_avg_rating() from public, anon;
grant execute on function public.platform_avg_rating() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Recalcula reputação e selos de um profissional
-- ---------------------------------------------------------------------------
create or replace function public.refresh_provider_reputation(p_provider uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cnt int; v_avg numeric; v_recent numeric;
  v_badges text[]; v_old text[]; v_new text; v_super boolean;
  v_label text;
begin
  select pp.badges into v_old from public.provider_profiles pp where pp.user_id = p_provider;
  if not found then return; end if;

  with rv as (
    select r.rating, row_number() over (order by r.created_at desc) rn
      from public.reviews r
      join public.jobs j on j.id = r.job_id
     where r.reviewee_id = p_provider and r.reviewee_id = j.provider_id
       and r.reviewer_id = j.client_id and r.revealed_at is not null)
  select count(*), coalesce(avg(rating), 0),
         coalesce(sum(rating * case when rn <= 10 then 1.5 else 1 end)
                  / nullif(sum(case when rn <= 10 then 1.5 else 1 end), 0), 0)
    into v_cnt, v_avg, v_recent from rv;

  -- Selos por pílula (>= 15 marcações)
  select coalesce(array_agg(m.badge order by m.badge), '{}') into v_badges
    from (
      select t.tag, count(*) c
        from public.reviews r
        join public.jobs j on j.id = r.job_id,
        unnest(r.tags) t(tag)
       where r.reviewee_id = p_provider and r.reviewee_id = j.provider_id
         and r.reviewer_id = j.client_id and r.revealed_at is not null
       group by t.tag) x
    join (values ('Limpou tudo depois', 'organizacao'), ('Super pontual', 'pontual'),
                 ('Mestre no que faz', 'mestre'), ('Preço honesto', 'honesto'),
                 ('Educado e confiável', 'confiavel')) m(tag, badge) on m.tag = x.tag
   where x.c >= 15;

  -- Super Profissional: as 20 últimas avaliações são nota 5
  select (count(*) = 20 and bool_and(s.rating = 5)) into v_super
    from (select r.rating
            from public.reviews r join public.jobs j on j.id = r.job_id
           where r.reviewee_id = p_provider and r.reviewee_id = j.provider_id
             and r.reviewer_id = j.client_id and r.revealed_at is not null
           order by r.created_at desc limit 20) s;
  if coalesce(v_super, false) then v_badges := array_append(v_badges, 'super'); end if;

  update public.provider_profiles
     set rating_count = v_cnt,
         rating_avg = round(v_avg, 2),
         rating_recent_avg = round(v_recent, 3),
         badges = v_badges
   where user_id = p_provider;

  -- Avisa sobre selos novos
  foreach v_new in array v_badges loop
    continue when v_new = any (coalesce(v_old, '{}'));
    v_label := case v_new
      when 'organizacao' then 'Mestre da Organização'
      when 'pontual'     then 'Sempre Pontual'
      when 'mestre'      then 'Mestre no que faz'
      when 'honesto'     then 'Preço Honesto'
      when 'confiavel'   then 'Educado e Confiável'
      when 'super'       then 'Super Profissional'
      else v_new end;
    perform public.notify_user(p_provider, 'badge_earned', 'Novo selo conquistado!',
      'Parabéns! Você ganhou o selo "' || v_label || '".', null);
  end loop;
end $$;
revoke all on function public.refresh_provider_reputation(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Revelação das avaliações de um serviço
-- ---------------------------------------------------------------------------
create or replace function public.reveal_job_reviews(p_job uuid)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; r record;
begin
  update public.reviews set revealed_at = now() where job_id = p_job and revealed_at is null;
  if not found then return; end if;
  select * into j from public.jobs where id = p_job;
  if j.provider_id is not null then
    perform public.refresh_provider_reputation(j.provider_id);
  end if;
  for r in select reviewee_id from public.reviews where job_id = p_job loop
    perform public.notify_user(r.reviewee_id, 'review_revealed', 'Avaliação disponível',
      'Você recebeu uma avaliação do serviço "' || coalesce(j.title, '') || '".', p_job);
  end loop;
end $$;
revoke all on function public.reveal_job_reviews(uuid) from public, anon, authenticated;

-- Revela, após 48 h da primeira avaliação, os serviços em que a outra parte não avaliou.
create or replace function public.reveal_due_reviews()
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select job_id from public.reviews
            where revealed_at is null
            group by job_id
           having min(created_at) <= now() - interval '48 hours' loop
    perform public.reveal_job_reviews(r.job_id);
  end loop;
end $$;
revoke all on function public.reveal_due_reviews() from public, anon, authenticated;

select cron.unschedule('reveal-reviews') where exists (select 1 from cron.job where jobname = 'reveal-reviews');
select cron.schedule('reveal-reviews', '*/10 * * * *', 'select public.reveal_due_reviews();');

-- ---------------------------------------------------------------------------
-- 5. Enviar avaliação (com pílulas, fotos e revelação cega)
-- ---------------------------------------------------------------------------
drop function if exists public.submit_review(uuid, int, text, text[], numeric, jsonb);
create or replace function public.submit_review(
  p_job_id uuid, p_rating int, p_comment text default null,
  p_tags text[] default '{}', p_tip numeric default 0, p_criteria jsonb default null,
  p_photo_paths text[] default '{}')
returns void language plpgsql security definer set search_path = public as $$
declare
  j public.jobs%rowtype; v_reviewee uuid; v_is_client boolean; v_n int; v_path text;
begin
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'A nota deve ser de 1 a 5.' using errcode = '22023';
  end if;
  select * into j from public.jobs where id = p_job_id;
  if not found or j.status <> 'completed' then
    raise exception 'Só é possível avaliar serviços concluídos.' using errcode = 'P0001';
  end if;
  if auth.uid() = j.client_id then v_reviewee := j.provider_id; v_is_client := true;
  elsif auth.uid() = j.provider_id then v_reviewee := j.client_id; v_is_client := false;
  else raise exception 'Acesso negado.' using errcode = '42501'; end if;

  if coalesce(array_length(p_tags, 1), 0) > 6 or exists (select 1 from unnest(coalesce(p_tags, '{}')) t where char_length(t) > 40) then
    raise exception 'Máximo de 6 marcações de até 40 caracteres.' using errcode = '22023';
  end if;
  if coalesce(array_length(p_photo_paths, 1), 0) > 0 then
    if not v_is_client then
      raise exception 'Só o cliente anexa fotos à avaliação.' using errcode = '42501';
    end if;
    if array_length(p_photo_paths, 1) > 3 then
      raise exception 'Máximo de 3 fotos.' using errcode = '22023';
    end if;
    foreach v_path in array p_photo_paths loop
      if v_path is null or v_path not like auth.uid()::text || '/%' or v_path like '%..%' then
        raise exception 'Foto inválida.' using errcode = '22023';
      end if;
    end loop;
  end if;

  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, tip_amount, criteria, photo_paths)
  values (p_job_id, auth.uid(), v_reviewee, p_rating, nullif(btrim(p_comment), ''), coalesce(p_tags, '{}'),
          case when v_is_client then greatest(coalesce(p_tip, 0), 0) else 0 end, p_criteria,
          coalesce(p_photo_paths, '{}'));

  select count(*) into v_n from public.reviews where job_id = p_job_id;
  if v_n >= 2 then
    perform public.reveal_job_reviews(p_job_id);
  else
    perform public.notify_user(v_reviewee, 'review_pending', 'Avalie para ver a sua nota',
      'A outra parte já avaliou "' || j.title || '". Envie a sua avaliação: as duas são reveladas juntas (ou em 48 h).', p_job_id);
  end if;
exception when unique_violation then
  raise exception 'Você já avaliou este serviço.' using errcode = 'P0001';
end $$;

revoke all on function public.submit_review(uuid, int, text, text[], numeric, jsonb, text[]) from public, anon;
grant execute on function public.submit_review(uuid, int, text, text[], numeric, jsonb, text[]) to authenticated;

-- Estado da avaliação do serviço para quem chama: none | waiting | revealed
create or replace function public.review_status(p_job uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
           when not exists (select 1 from public.reviews where job_id = p_job and reviewer_id = auth.uid()) then 'none'
           when exists (select 1 from public.reviews where job_id = p_job and reviewer_id = auth.uid() and revealed_at is not null) then 'revealed'
           else 'waiting' end;
$$;
revoke all on function public.review_status(uuid) from public, anon;
grant execute on function public.review_status(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Direito de resposta (uma vez, só a quem foi avaliado, só se revelada)
-- ---------------------------------------------------------------------------
create or replace function public.reply_to_review(p_review uuid, p_text text)
returns void language plpgsql security definer set search_path = public as $$
declare r public.reviews%rowtype; v_txt text := btrim(coalesce(p_text, ''));
begin
  select * into r from public.reviews where id = p_review for update;
  if not found or r.reviewee_id <> auth.uid() then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;
  if r.revealed_at is null then
    raise exception 'A avaliação ainda não foi revelada.' using errcode = 'P0001';
  end if;
  if r.reply is not null then
    raise exception 'Você já respondeu esta avaliação.' using errcode = 'P0001';
  end if;
  if char_length(v_txt) < 3 or char_length(v_txt) > 500 then
    raise exception 'A resposta deve ter entre 3 e 500 caracteres.' using errcode = '22023';
  end if;
  update public.reviews set reply = v_txt, reply_at = now() where id = p_review;
  perform public.notify_user(r.reviewer_id, 'review_reply', 'Resposta à sua avaliação',
    'O profissional respondeu à sua avaliação.', r.job_id);
end $$;
revoke all on function public.reply_to_review(uuid, text) from public, anon;
grant execute on function public.reply_to_review(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Views públicas
-- ---------------------------------------------------------------------------
drop view if exists public.provider_public_profiles;
create view public.provider_public_profiles as
  select p.id, p.full_name, p.avatar_url, p.bio, p.address_city,
         pp.headline, pp.specialties, pp.hourly_rate, pp.visit_fee, pp.service_radius_km,
         pp.rating_avg, pp.rating_count, pp.jobs_done, pp.accepting_jobs,
         p.latitude, p.longitude,
         pp.badges,
         -- Média Bayesiana: WR = v/(v+m)*R + m/(v+m)*C
         round(
           (coalesce(pp.rating_count, 0)::numeric / (coalesce(pp.rating_count, 0) + public.ranking_min_reviews()))
             * coalesce(pp.rating_recent_avg, 0)
           + (public.ranking_min_reviews() / (coalesce(pp.rating_count, 0) + public.ranking_min_reviews()))
             * (select public.platform_avg_rating()), 3) as rank_score
    from public.profiles p
    left join public.provider_profiles pp on pp.user_id = p.id
   where p.is_provider and p.verification_status = 'ACTIVE';
revoke all on public.provider_public_profiles from anon;
grant  select on public.provider_public_profiles to authenticated;

drop view if exists public.public_reviews;
create view public.public_reviews as
  select r.id, r.reviewee_id as provider_id, r.rating, r.comment, r.tags, r.created_at,
         r.photo_paths, r.reply, r.reply_at,
         split_part(p.full_name, ' ', 1) ||
           case when position(' ' in p.full_name) > 0
                then ' ' || left(split_part(p.full_name, ' ', 2), 1) || '.' else '' end as reviewer_name,
         p.avatar_url as reviewer_avatar
    from public.reviews r
    join public.profiles p on p.id = r.reviewer_id
    join public.jobs j on j.id = r.job_id
   where r.reviewee_id = j.provider_id
     and r.revealed_at is not null
     and public.is_public_provider(r.reviewee_id);
revoke all on public.public_reviews from anon;
grant  select on public.public_reviews to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Reputação do cliente (só para profissionais que têm relação com ele)
-- ---------------------------------------------------------------------------
create or replace function public.client_reputation(p_client uuid)
returns table (avg_rating numeric, rating_count int)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Não autenticado.' using errcode = '28000'; end if;
  if not (auth.uid() = p_client or public.is_admin()
          or exists (select 1 from public.jobs jb
                      where jb.client_id = p_client
                        and (jb.provider_id = auth.uid() or public.is_invited(jb.id) or public.has_quoted_job(jb.id)))) then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;
  return query
    select coalesce(round(avg(r.rating)::numeric, 2), 0), count(*)::int
      from public.reviews r join public.jobs j on j.id = r.job_id
     where r.reviewee_id = p_client and r.reviewer_id = j.provider_id and r.revealed_at is not null;
end $$;
revoke all on function public.client_reputation(uuid) from public, anon;
grant execute on function public.client_reputation(uuid) to authenticated;

-- Recalcula agora a reputação de todos os profissionais (migra dados existentes).
do $$ declare r record; begin
  for r in select user_id from public.provider_profiles loop
    perform public.refresh_provider_reputation(r.user_id);
  end loop;
end $$;
