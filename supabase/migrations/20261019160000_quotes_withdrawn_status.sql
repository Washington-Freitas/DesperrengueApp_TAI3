-- Permite o estado 'withdrawn' (profissional retira a proposta).
begin;
alter table public.quotes drop constraint if exists quotes_status_check;
alter table public.quotes add constraint quotes_status_check check (status in ('pending','accepted','rejected','withdrawn'));
commit;