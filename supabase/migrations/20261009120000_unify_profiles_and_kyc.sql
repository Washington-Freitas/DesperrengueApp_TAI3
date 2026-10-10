-- ============================================================================
-- DESPERRENGUE — Migration 1/3: perfil unificado + KYC
--
-- Problema corrigido: coexistiam `public.perfis` (usada pelo app) e
-- `public.profiles` (usada por trigger/cron/Edge Function). Esta migration
-- consolida tudo em `public.profiles` (nomes em inglês), move os dados de KYC
-- para `public.kyc_submissions` e impede que o usuário altere o próprio status
-- de verificação (brecha de auto-aprovação).
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. Remove automações antigas (serão recriadas abaixo sobre o novo modelo)
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select jobid from cron.job where command ilike '%process_mock_kyc_approvals%' loop
    perform cron.unschedule(r.jobid);
  end loop;
end $$;

drop trigger  if exists gatilho_nativo_email    on public.profiles;
drop trigger  if exists on_auth_user_created    on auth.users;
drop function if exists public.disparar_email_aprovacao();
drop function if exists public.process_mock_kyc_approvals();
drop function if exists public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 1. Enum de status de verificação (substitui user_verification_status)
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.verification_status as enum
    ('NOT_SUBMITTED', 'PENDING', 'APPROVED_PENDING_EMAIL', 'ACTIVE', 'REJECTED');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. public.profiles — renomeia/adapta colunas existentes
-- ---------------------------------------------------------------------------
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='profiles' and column_name='nome_completo') then
    alter table public.profiles rename column nome_completo to full_name;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='profiles' and column_name='criado_em') then
    alter table public.profiles rename column criado_em to created_at;
  end if;
end $$;

alter table public.profiles drop column if exists tipo_perfil;
alter table public.profiles drop column if exists document_submitted_at;

alter table public.profiles alter column verification_status drop default;
alter table public.profiles
  alter column verification_status type public.verification_status
  using (coalesce(verification_status::text, 'NOT_SUBMITTED'))::public.verification_status;
alter table public.profiles alter column verification_status set default 'NOT_SUBMITTED';
alter table public.profiles alter column verification_status set not null;

update public.profiles set full_name = 'Usuário' where full_name is null or btrim(full_name) = '';
alter table public.profiles alter column full_name set not null;

alter table public.profiles
  add column if not exists role         text,
  add column if not exists phone        text,
  add column if not exists bio          text,
  add column if not exists latitude     double precision,
  add column if not exists longitude    double precision,
  add column if not exists address_city text,
  add column if not exists updated_at   timestamptz not null default timezone('utc', now());

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role is null or role in ('client', 'provider', 'admin'));

-- ---------------------------------------------------------------------------
-- 3. Migra a escolha de papel feita no app (perfis.role) e descarta `perfis`
-- ---------------------------------------------------------------------------
do $$ begin
  if to_regclass('public.perfis') is not null then
    update public.profiles p
       set role = case pf.role when 'cliente' then 'client'
                               when 'profissional' then 'provider' end
      from public.perfis pf
     where pf.id = p.id and p.role is null;
    drop table public.perfis;
  end if;
end $$;

drop type if exists public.user_verification_status;

-- ---------------------------------------------------------------------------
-- 4. Configurações da aplicação (feature flags no banco)
-- ---------------------------------------------------------------------------
create table if not exists public.app_settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default timezone('utc', now())
);
alter table public.app_settings enable row level security;  -- sem policies: só service_role/postgres
revoke all on public.app_settings from anon, authenticated;

-- 'true' = aprovação automática MOCK do KYC (MVP acadêmico). Em produção: 'false'.
insert into public.app_settings (key, value) values ('kyc_auto_approve', 'true')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 5. Helpers de autorização (SECURITY DEFINER evita recursão de RLS)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.is_active_provider()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'provider' and verification_status = 'ACTIVE');
$$;

create or replace function public.is_client()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'client');
$$;

revoke all on function public.is_admin(), public.is_active_provider(), public.is_client() from public, anon;
grant execute on function public.is_admin(), public.is_active_provider(), public.is_client() to authenticated;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Segurança de public.profiles
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "Atualização restrita ao proprietário"      on public.profiles;
drop policy if exists "Leitura restrita ao proprietário"          on public.profiles;
drop policy if exists "Usuários podem ver seu próprio perfil"     on public.profiles;
drop policy if exists "profiles_select_own_or_admin"              on public.profiles;
drop policy if exists "profiles_update_own"                       on public.profiles;

create policy "profiles_select_own_or_admin" on public.profiles
  for select to authenticated using (auth.uid() = id or public.is_admin());

create policy "profiles_update_own" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Sem policy de INSERT/DELETE: o perfil nasce pelo trigger handle_new_user().

-- Defesa em profundidade: o cliente da API só pode escrever nestas colunas.
-- verification_status NÃO está na lista -> auto-aprovação impossível.
revoke all on public.profiles from anon;
revoke insert, update, delete on public.profiles from authenticated;
grant  select on public.profiles to authenticated;
grant  update (full_name, phone, avatar_url, bio, latitude, longitude, address_city, role)
  on public.profiles to authenticated;

-- O papel só pode ser definido UMA vez pelo usuário (NULL -> client|provider).
-- 'admin' só é atribuído por quem opera o banco (service_role/postgres).
create or replace function public.profiles_protect_columns()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.role is distinct from old.role
       and not (old.role is null and new.role in ('client', 'provider')) then
      raise exception 'O papel do usuário não pode ser alterado.' using errcode = '42501';
    end if;
    if new.verification_status is distinct from old.verification_status then
      raise exception 'O status de verificação é controlado pelo sistema.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists profiles_protect_columns on public.profiles;
create trigger profiles_protect_columns
  before update on public.profiles
  for each row execute function public.profiles_protect_columns();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Visão pública mínima (sem telefone/coordenadas) para o cliente ver prestadores.
drop view if exists public.provider_public_profiles;
create view public.provider_public_profiles as
  select id, full_name, avatar_url, bio, address_city
    from public.profiles
   where role = 'provider' and verification_status = 'ACTIVE';
revoke all on public.provider_public_profiles from anon;
grant select on public.provider_public_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Criação automática do perfil no cadastro (email/senha e OAuth)
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Usuário')
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Garante perfil para usuários já existentes sem linha em profiles.
insert into public.profiles (id, full_name)
select u.id,
       coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
                nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'Usuário')
  from auth.users u
 where not exists (select 1 from public.profiles p where p.id = u.id);

-- ---------------------------------------------------------------------------
-- 8. KYC — dados sensíveis separados do perfil
-- ---------------------------------------------------------------------------
create table if not exists public.kyc_submissions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  front_path      text not null,
  back_path       text not null,
  selfie_path     text not null,
  registry_type   text not null check (registry_type in ('CREA', 'CFT', 'CNPJ', 'Outro')),
  registry_number text not null check (btrim(registry_number) <> ''),
  status          text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  rejection_reason text,
  submitted_at    timestamptz not null default timezone('utc', now()),
  reviewed_at     timestamptz,
  reviewed_by     uuid references public.profiles(id)
);
create index if not exists kyc_submissions_user_idx   on public.kyc_submissions (user_id, submitted_at desc);
create index if not exists kyc_submissions_status_idx on public.kyc_submissions (status, submitted_at);

alter table public.kyc_submissions enable row level security;
revoke all on public.kyc_submissions from anon;
revoke insert, update, delete on public.kyc_submissions from authenticated;
grant  select on public.kyc_submissions to authenticated;

drop policy if exists "kyc_select_own_or_admin" on public.kyc_submissions;
create policy "kyc_select_own_or_admin" on public.kyc_submissions
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- 8.1 Envio do KYC (único caminho de escrita para o app)
create or replace function public.submit_kyc(
  p_front_path      text,
  p_back_path       text,
  p_selfie_path     text,
  p_registry_type   text,
  p_registry_number text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_role   text;
  v_status public.verification_status;
  v_id     uuid;
begin
  if v_uid is null then
    raise exception 'Não autenticado.' using errcode = '28000';
  end if;

  select role, verification_status into v_role, v_status
    from public.profiles where id = v_uid for update;

  if v_role is distinct from 'provider' then
    raise exception 'Apenas profissionais enviam KYC.' using errcode = '42501';
  end if;
  if v_status not in ('NOT_SUBMITTED', 'REJECTED') then
    raise exception 'KYC já enviado (status: %).', v_status using errcode = 'P0001';
  end if;
  if split_part(p_front_path,  '/', 1) <> v_uid::text
     or split_part(p_back_path,   '/', 1) <> v_uid::text
     or split_part(p_selfie_path, '/', 1) <> v_uid::text then
    raise exception 'Caminho de arquivo inválido.' using errcode = '42501';
  end if;

  insert into public.kyc_submissions
    (user_id, front_path, back_path, selfie_path, registry_type, registry_number)
  values
    (v_uid, p_front_path, p_back_path, p_selfie_path, p_registry_type, btrim(p_registry_number))
  returning id into v_id;

  update public.profiles set verification_status = 'PENDING' where id = v_uid;
  return v_id;
end $$;

-- 8.2 Revisão manual (admin autenticado ou service_role)
create or replace function public.admin_review_kyc(p_user_id uuid, p_approve boolean, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_admin() or auth.role() = 'service_role') then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;

  update public.kyc_submissions
     set status = case when p_approve then 'APPROVED' else 'REJECTED' end,
         rejection_reason = case when p_approve then null else p_reason end,
         reviewed_at = now(),
         reviewed_by = auth.uid()
   where user_id = p_user_id and status = 'PENDING';

  update public.profiles
     set verification_status = case when p_approve then 'APPROVED_PENDING_EMAIL'
                                    else 'REJECTED' end::public.verification_status
   where id = p_user_id and verification_status = 'PENDING';
end $$;

-- 8.3 Ativação da conta profissional (deep link do e-mail / botão da Tela 7)
create or replace function public.activate_provider()
returns public.verification_status
language plpgsql security definer set search_path = public as $$
declare v_status public.verification_status;
begin
  if auth.uid() is null then
    raise exception 'Não autenticado.' using errcode = '28000';
  end if;
  select verification_status into v_status from public.profiles where id = auth.uid() for update;

  if v_status = 'APPROVED_PENDING_EMAIL' then
    update public.profiles set verification_status = 'ACTIVE' where id = auth.uid();
    return 'ACTIVE';
  elsif v_status = 'ACTIVE' then
    return 'ACTIVE';
  end if;
  raise exception 'Conta ainda não aprovada (status: %).', v_status using errcode = 'P0001';
end $$;

-- 8.4 Aprovação automática MOCK (controlada por app_settings.kyc_auto_approve)
create or replace function public.process_mock_kyc_approvals()
returns void language plpgsql security definer set search_path = public as $$
begin
  if coalesce((select value from public.app_settings where key = 'kyc_auto_approve'), 'false') <> 'true' then
    return;
  end if;

  with approved as (
    update public.kyc_submissions
       set status = 'APPROVED', reviewed_at = now()
     where status = 'PENDING' and submitted_at <= now() - interval '40 seconds'
    returning user_id
  )
  update public.profiles p
     set verification_status = 'APPROVED_PENDING_EMAIL'
    from approved a
   where p.id = a.user_id and p.verification_status = 'PENDING';
end $$;

revoke all on function
  public.submit_kyc(text, text, text, text, text),
  public.admin_review_kyc(uuid, boolean, text),
  public.activate_provider(),
  public.process_mock_kyc_approvals()
from public, anon;
grant execute on function public.submit_kyc(text, text, text, text, text) to authenticated;
grant execute on function public.admin_review_kyc(uuid, boolean, text)     to authenticated;
grant execute on function public.activate_provider()                       to authenticated;

select cron.schedule('kyc-mock-approval', '* * * * *', 'select public.process_mock_kyc_approvals();');

-- ---------------------------------------------------------------------------
-- 9. Notificação de aprovação -> Edge Function (autenticada por segredo no Vault)
-- ---------------------------------------------------------------------------
create or replace function public.notify_kyc_approved()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_secret text;
begin
  if new.verification_status = 'APPROVED_PENDING_EMAIL'
     and old.verification_status is distinct from new.verification_status then

    select decrypted_secret into v_secret
      from vault.decrypted_secrets where name = 'kyc_webhook_secret' limit 1;

    perform net.http_post(
      url     := 'https://eisfkemgooqbgqljvwvs.supabase.co/functions/v1/enviar-email-aprovacao',
      headers := jsonb_build_object(
                   'Content-Type',     'application/json',
                   'x-webhook-secret', coalesce(v_secret, '')),
      body    := jsonb_build_object('record',
                   jsonb_build_object('id', new.id,
                                      'full_name', new.full_name,
                                      'verification_status', new.verification_status))
    );
  end if;
  return new;
end $$;

revoke all on function public.notify_kyc_approved() from public, anon, authenticated;

drop trigger if exists profiles_notify_kyc_approved on public.profiles;
create trigger profiles_notify_kyc_approved
  after update of verification_status on public.profiles
  for each row execute function public.notify_kyc_approved();

commit;
