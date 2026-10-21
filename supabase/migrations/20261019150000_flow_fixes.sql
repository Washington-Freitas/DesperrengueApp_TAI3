-- ============================================================================
-- DESPERRENGUE — Migration 7: correções do fluxo
--  * complete_job_with_pin: o RAISE EXCEPTION desfazia o contador de tentativas
--    (nunca bloqueava). Agora retorna texto e persiste a tentativa.
--  * cancel_job: estorna a reserva da emergência e encerra convites.
--  * Orçamento criado internamente no aceite da emergência não notifica
--    "novo orçamento" (o cliente recebe "Temos um Match!").
-- ============================================================================

begin;

drop function if exists public.complete_job_with_pin(uuid, text);
create or replace function public.complete_job_with_pin(p_job_id uuid, p_pin text)
returns text language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_pin text;
begin
  select * into j from public.jobs where id = p_job_id and provider_id = auth.uid() for update;
  if not found or j.status not in ('in_progress', 'awaiting_approval') then
    raise exception 'Serviço não pode ser concluído agora.' using errcode = 'P0001';
  end if;
  if j.pin_attempts >= 5 then
    return 'locked';
  end if;
  select pin into v_pin from public.job_secrets where job_id = p_job_id;

  if v_pin is distinct from btrim(p_pin) then
    update public.jobs set pin_attempts = pin_attempts + 1 where id = p_job_id;
    if j.pin_attempts + 1 >= 5 then return 'locked'; end if;
    return 'invalid:' || (4 - j.pin_attempts);
  end if;

  update public.jobs
     set status = 'completed', payment_status = 'released',
         finished_at = coalesce(finished_at, now()), approved_at = now()
   where id = p_job_id;
  update public.payments set status = 'released', released_at = now() where job_id = p_job_id;
  update public.provider_profiles set jobs_done = jobs_done + 1 where user_id = auth.uid();
  perform public.notify_user(j.client_id, 'job_completed', 'Serviço concluído',
    '"' || j.title || '" foi concluído. Que tal avaliar o profissional?', p_job_id);
  return 'ok';
end $$;

revoke all on function public.complete_job_with_pin(uuid, text) from public, anon;
grant execute on function public.complete_job_with_pin(uuid, text) to authenticated;

create or replace function public.cancel_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prov uuid; v_pay text;
begin
  update public.jobs set status = 'canceled',
         payment_status = case when payment_status = 'escrow' then 'refunded' else payment_status end
   where id = p_job_id and client_id = auth.uid() and status in ('open', 'awaiting_payment')
  returning provider_id, payment_status into v_prov, v_pay;
  if not found then
    raise exception 'Demanda não pode ser cancelada.' using errcode = 'P0001';
  end if;
  update public.quotes set status = 'rejected' where job_id = p_job_id and status in ('pending', 'accepted');
  update public.job_invites set status = 'withdrawn' where job_id = p_job_id and status = 'pending';
  update public.payments set status = 'refunded', released_at = now() where job_id = p_job_id and status = 'escrow';
  if v_prov is not null then
    perform public.notify_user(v_prov, 'job_canceled', 'Demanda cancelada',
      'O cliente cancelou a demanda antes do pagamento.', p_job_id);
  end if;
end $$;

create or replace function public.quotes_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_client uuid; v_title text; v_name text;
begin
  update public.jobs set quote_count = quote_count + 1
   where id = new.job_id returning client_id, title into v_client, v_title;
  if coalesce(current_setting('app.bypass_quote_rules', true), '') = 'on' then
    return new;
  end if;
  select split_part(full_name, ' ', 1) into v_name from public.profiles where id = new.provider_id;
  perform public.notify_user(v_client, 'new_quote', 'Novo orçamento recebido',
    coalesce(v_name, 'Um profissional') || ' enviou um orçamento para "' || v_title || '".', new.job_id);
  return new;
end $$;

commit;
