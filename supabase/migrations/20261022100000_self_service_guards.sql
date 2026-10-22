-- =============================================================================
-- Trava de "auto-contratação": quem é cliente E profissional na mesma conta
-- nunca pode atender (nem orçar, nem aceitar emergência de) o próprio pedido.
--
--  * quotes_before_insert  -> já bloqueia orçar a própria demanda (mantido).
--  * invite_providers      -> já ignora o próprio usuário (mantido).
--  * accept_emergency      -> passa a recusar explicitamente (defesa em profundidade).
-- =============================================================================

create or replace function public.accept_emergency(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_quote uuid;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if not found or j.urgency <> 'emergency' or j.status <> 'open' or j.payment_status <> 'escrow' then
    raise exception 'Emergência indisponível.' using errcode = 'P0001';
  end if;
  if j.client_id = auth.uid() then
    raise exception 'Você não pode atender o seu próprio pedido.' using errcode = '42501';
  end if;
  update public.job_invites set status = 'accepted'
   where job_id = p_job_id and provider_id = auth.uid() and status = 'pending' and expires_at > now();
  if not found then
    raise exception 'Convite expirado ou inexistente.' using errcode = 'P0001';
  end if;
  update public.job_invites set status = 'withdrawn'
   where job_id = p_job_id and provider_id <> auth.uid() and status = 'pending';

  perform set_config('app.bypass_quote_rules', 'on', true);
  insert into public.quotes (job_id, provider_id, price, message, status)
  values (p_job_id, auth.uid(), j.agreed_price, 'Atendimento de emergência aceito.', 'accepted')
  returning id into v_quote;

  perform set_config('app.bypass_quote_rules', 'off', true);
  update public.job_invites set status = 'accepted' where job_id = p_job_id and provider_id = auth.uid();
  update public.jobs
     set status = 'in_progress', provider_id = auth.uid(), accepted_quote_id = v_quote
   where id = p_job_id;
  update public.payments set provider_id = auth.uid() where job_id = p_job_id;
  perform public.gen_job_pin(p_job_id);
  perform public.notify_user(j.client_id, 'emergency_accepted', 'Temos um Match!',
    'Um profissional aceitou sua emergência e está a caminho.', p_job_id);
end $$;

revoke all on function public.accept_emergency(uuid) from public, anon;
grant execute on function public.accept_emergency(uuid) to authenticated;
