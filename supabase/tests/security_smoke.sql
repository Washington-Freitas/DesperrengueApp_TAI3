-- ============================================================================
-- DESPERRENGUE — Teste de fumaça de segurança e do fluxo de serviço
--
-- Roda tudo dentro de UMA transação SEMPRE abortada no final (RAISE EXCEPTION):
-- nada é gravado. O relatório vem na mensagem do erro:
--
--   supabase db query --linked -f supabase/tests/security_smoke.sql
--
-- Requer >= 6 linhas em public.profiles (usa contas existentes como "atores" e
-- ajusta flags só dentro da transação).
--
--   c  = cliente            p1 = profissional ativo (também será cliente)
--   p2, p3, p4 = profissionais ativos      x = conta sem nenhum modo
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
  ids uuid[];
  c uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; x uuid;
  j uuid; j2 uuid; je uuid; je2 uuid; je3 uuid;
  q1 uuid; q2 uuid; q3 uuid; qa uuid;
  n int; st text; s text; v_pin text; r record;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 6 then
    raise exception 'TESTE ABORTADO: são necessários >= 6 perfis (existem %).', coalesce(array_length(ids, 1), 0);
  end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3]; p3 := ids[4]; p4 := ids[5]; x := ids[6];

  -- ---------------------------------------------------------------- preparação
  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id in (c, p1);
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true
   where id in (p1, p2, p3, p4);
  update public.profiles set is_provider = true where id = x;
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee) select id, array['Elétrica'], 30
    from public.profiles where id in (p1, p2, p3, p4);

  -- ===== SEGURANÇA DE PERFIL =====
  perform pg_temp.login(x);
  begin
    update public.profiles set verification_status = 'ACTIVE' where id = x;
    perform pg_temp.t(false, '01 auto-aprovação de KYC PERMITIDA');
  exception when others then perform pg_temp.t(true, '01 auto-aprovação de KYC bloqueada'); end;
  begin
    update public.profiles set role = 'admin' where id = x;
    perform pg_temp.t(false, '02 escalada para admin PERMITIDA');
  exception when others then perform pg_temp.t(true, '02 escalada para admin bloqueada'); end;
  begin
    update public.profiles set is_client = true where id = x;
    perform pg_temp.t(false, '03 mudar is_client direto PERMITIDO');
  exception when others then perform pg_temp.t(true, '03 mudar is_client direto bloqueado'); end;
  begin
    update public.provider_profiles set rating_avg = 5 where user_id = x;
    perform pg_temp.t(false, '04 mudar nota própria PERMITIDO');
  exception when others then perform pg_temp.t(true, '04 mudar nota própria bloqueado'); end;

  -- ===== MULTI-MODO =====
  perform public.enroll_mode('client');
  perform public.enroll_mode('provider');
  select (is_client and is_provider) into st from public.profiles where id = x;
  perform pg_temp.t(st::boolean, '05 mesma conta vira cliente E profissional (enroll_mode)');
  begin
    perform public.enroll_mode('admin');
    perform pg_temp.t(false, '06 enroll_mode(admin) PERMITIDO');
  exception when others then perform pg_temp.t(true, '06 enroll_mode(admin) rejeitado'); end;
  perform public.set_last_mode('client');
  select last_mode into st from public.profiles where id = x;
  perform pg_temp.t(st = 'client', '07 set_last_mode persiste o modo');
  reset role;

  -- ===== PEDIDO DIRETO + CONVITES =====
  perform pg_temp.login(c);
  begin
    insert into public.jobs (client_id, title, description, category, visibility, provider_id)
    values (c, 'x', 'y', 'Elétrica', 'direct', p1);
    perform pg_temp.t(false, '08 cliente definiu provider_id na criação PERMITIDO');
  exception when others then perform pg_temp.t(true, '08 cliente não define provider_id na criação'); end;
  begin
    insert into public.jobs (client_id, title, description, category, urgency, visibility, address_summary)
    values (c, 'Trocar disjuntor', 'Disjuntor do chuveiro desarma', 'Elétrica', 'scheduled', 'direct', 'Consolação, São Paulo - SP')
    returning id into j;
    insert into public.job_addresses (job_id, address_line) values (j, 'Rua Augusta, 1400');
    perform pg_temp.t(true, '09 cliente cria pedido direto + endereço');
  exception when others then perform pg_temp.t(false, '09 criar pedido falhou: ' || sqlerrm); end;
  select public.invite_providers(j, array[p1, p2, p4, x]) into n;
  perform pg_temp.t(n = 3, '10 convida só profissionais ATIVOS (retornou ' || n || ', esperado 3)');
  begin
    select public.invite_providers(j, array[p3]) into n;
    perform pg_temp.t(n = 0, '11 limite de 3 convites por pedido (retornou ' || n || ')');
  exception when others then perform pg_temp.t(false, '11 invite 4º: ' || sqlerrm); end;
  reset role;

  perform pg_temp.login(p3);
  select count(*) into n from public.jobs where id = j;
  perform pg_temp.t(n = 0, '12 profissional NÃO convidado não vê pedido direto');
  select count(*) into n from public.job_addresses where job_id = j;
  perform pg_temp.t(n = 0, '13 endereço completo oculto para quem não foi contratado');
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, p3, 100);
    perform pg_temp.t(false, '14 orçamento sem convite PERMITIDO');
  exception when others then perform pg_temp.t(true, '14 orçamento sem convite bloqueado'); end;
  reset role;

  perform pg_temp.login(p1);
  select count(*) into n from public.jobs where id = j;
  perform pg_temp.t(n = 1, '15 profissional convidado vê o pedido');
  insert into public.quotes (job_id, provider_id, price, message) values (j, p1, 150, 'Inclui disjuntor novo') returning id into q1;
  perform pg_temp.t(true, '16 convidado envia orçamento');
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, p1, 99);
    perform pg_temp.t(false, '17 2º orçamento do mesmo profissional PERMITIDO');
  exception when others then perform pg_temp.t(true, '17 1 orçamento por profissional'); end;
  reset role;

  perform pg_temp.login(p2);
  insert into public.quotes (job_id, provider_id, price) values (j, p2, 180) returning id into q2;
  select count(*) into n from public.quotes where job_id = j;
  perform pg_temp.t(n = 1, '18 profissional não enxerga orçamento concorrente (vê ' || n || ')');
  begin
    perform public.accept_quote(q2);
    perform pg_temp.t(false, '19 profissional aceitou o próprio orçamento PERMITIDO');
  exception when others then perform pg_temp.t(true, '19 só o dono aceita orçamento'); end;
  reset role;

  perform pg_temp.login(p4);
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, p4, 50);
    perform pg_temp.t(true, '20 p4 (convidado) orça normalmente');
  exception when others then perform pg_temp.t(false, '20 p4 orçamento: ' || sqlerrm); end;
  reset role;

  -- ===== ACEITE + PAGAMENTO MOCK + PIN =====
  perform pg_temp.login(c);
  select count(*) into n from public.quotes where job_id = j;
  perform pg_temp.t(n = 3, '21 cliente vê os 3 orçamentos (vê ' || n || ')');
  begin
    perform public.pay_job_mock(j, 'pix');
    perform pg_temp.t(false, '22 pagar antes do aceite PERMITIDO');
  exception when others then perform pg_temp.t(true, '22 não paga antes do aceite'); end;
  perform public.accept_quote(q1);
  select status, provider_id::text into r from public.jobs where id = j;
  perform pg_temp.t(r.status = 'awaiting_payment' and r.provider_id = p1::text, '23 aceite -> awaiting_payment com profissional definido');
  select count(*) into n from public.quotes where job_id = j and status = 'rejected';
  perform pg_temp.t(n = 2, '24 aceite rejeita os demais orçamentos');
  begin
    perform public.pay_job_mock(j, 'bitcoin');
    perform pg_temp.t(false, '25 método inválido PERMITIDO');
  exception when others then perform pg_temp.t(true, '25 método de pagamento inválido rejeitado'); end;
  perform public.pay_job_mock(j, 'pix');
  select status, payment_status into r from public.jobs where id = j;
  perform pg_temp.t(r.status = 'in_progress' and r.payment_status = 'escrow', '26 pagamento -> in_progress + escrow');
  select pin into v_pin from public.job_secrets where job_id = j;
  perform pg_temp.t(v_pin ~ '^[0-9]{4}$', '27 cliente enxerga o PIN de 4 dígitos');
  begin
    update public.jobs set status = 'completed', payment_status = 'released' where id = j;
    perform pg_temp.t(false, '28 cliente alterou status/pagamento direto PERMITIDO');
  exception when others then perform pg_temp.t(true, '28 status/pagamento só por RPC'); end;
  reset role;

  perform pg_temp.login(p1);
  select count(*) into n from public.job_secrets where job_id = j;
  perform pg_temp.t(n = 0, '29 profissional NÃO consegue ler o PIN');
  select count(*) into n from public.job_addresses where job_id = j;
  perform pg_temp.t(n = 1, '30 profissional contratado enxerga o endereço completo');
  reset role;

  perform pg_temp.login(p2);
  begin
    insert into public.job_evidence (job_id, provider_id, slot, path) values (j, p2, 'overview', p2 || '/x.jpg');
    perform pg_temp.t(false, '32 evidência por profissional não contratado PERMITIDA');
  exception when others then perform pg_temp.t(true, '32 evidência só do profissional contratado'); end;
  reset role;

  perform pg_temp.login(p1);
  insert into public.job_evidence (job_id, provider_id, slot, path) values (j, p1, 'overview', p1 || '/a.jpg');
  perform pg_temp.t(true, '33 profissional contratado anexa evidência');
  s := public.complete_job_with_pin(j, '0000x');
  perform pg_temp.t(s like 'invalid:%', '34 PIN errado -> invalid (' || s || ')');
  select pin_attempts into n from public.jobs where id = j;
  perform pg_temp.t(n = 1, '35 tentativa errada é PERSISTIDA (pin_attempts=' || n || ')');
  s := public.complete_job_with_pin(j, v_pin);
  perform pg_temp.t(s = 'ok', '36 PIN correto conclui (' || s || ')');
  reset role;
  select status, payment_status into r from public.jobs where id = j;
  perform pg_temp.t(r.status = 'completed' and r.payment_status = 'released', '37 serviço concluído e escrow liberado');
  select jobs_done into n from public.provider_profiles where user_id = p1;
  perform pg_temp.t(n = 1, '38 jobs_done do profissional incrementado');
  select net_amount::int into n from public.payments where job_id = j;
  perform pg_temp.t(n = 132, '39 comissão de 12% descontada (líquido R$ ' || n || ' de R$ 150)');

  -- ===== AVALIAÇÕES =====
  perform pg_temp.login(c);
  perform public.submit_review(j, 5, 'Ótimo!', array['Pontual'], 10);
  perform pg_temp.t(true, '40 cliente avalia o profissional');
  begin
    perform public.submit_review(j, 4);
    perform pg_temp.t(false, '41 avaliação duplicada PERMITIDA');
  exception when others then perform pg_temp.t(true, '41 avaliação duplicada rejeitada'); end;
  reset role;
  perform pg_temp.login(p2);
  begin
    perform public.submit_review(j, 1);
    perform pg_temp.t(false, '42 terceiro avaliou serviço alheio PERMITIDO');
  exception when others then perform pg_temp.t(true, '42 só as partes avaliam'); end;
  reset role;
  perform pg_temp.login(p1);
  perform public.submit_review(j, 5, null, '{}', 0, '{"Simpatia":5}'::jsonb);
  perform pg_temp.t(true, '43 profissional avalia o cliente (critérios)');
  reset role;
  select rating_count, rating_avg::int into r from public.provider_profiles where user_id = p1;
  perform pg_temp.t(r.rating_count = 1 and r.rating_avg = 5, '44 nota agregada do profissional atualizada');

  -- ===== CHAT =====
  perform pg_temp.login(c);
  insert into public.messages (job_id, provider_id, body) values (j, p1, 'Oi!');
  perform pg_temp.t(true, '45 cliente envia mensagem');
  reset role;
  perform pg_temp.login(p3);
  begin
    insert into public.messages (job_id, provider_id, body) values (j, p3, 'intruso');
    perform pg_temp.t(false, '46 intruso enviou mensagem PERMITIDO');
  exception when others then perform pg_temp.t(true, '46 só quem orçou conversa'); end;
  reset role;
  perform pg_temp.login(p2);
  select count(*) into n from public.messages where job_id = j and provider_id = p1;
  perform pg_temp.t(n = 0, '47 conversas de outro profissional são privadas');
  reset role;

  -- ===== PEDIDO PÚBLICO: LIMITE DE 3 ORÇAMENTOS =====
  perform pg_temp.login(c);
  insert into public.jobs (client_id, title, description, category, visibility, address_summary)
  values (c, 'Pintar sala', 'Sala 20m2', 'Pintura', 'open', 'Centro') returning id into j2;
  reset role;
  perform pg_temp.login(p1); insert into public.quotes (job_id, provider_id, price) values (j2, p1, 100); reset role;
  perform pg_temp.login(p2); insert into public.quotes (job_id, provider_id, price) values (j2, p2, 110); reset role;
  perform pg_temp.login(p3); insert into public.quotes (job_id, provider_id, price) values (j2, p3, 120); reset role;
  perform pg_temp.login(p4);
  begin
    insert into public.quotes (job_id, provider_id, price) values (j2, p4, 90);
    perform pg_temp.t(false, '48 4º orçamento PERMITIDO');
  exception when others then perform pg_temp.t(position('QUOTE_LIMIT_REACHED' in sqlerrm) > 0, '48 4º orçamento bloqueado (RF-04)'); end;
  reset role;
  perform pg_temp.login(x);
  select count(*) into n from public.jobs where id = j2;
  perform pg_temp.t(n = 0, '49 profissional NÃO ativo não vê pedidos abertos');
  reset role;
  perform pg_temp.login(p3);
  perform public.withdraw_quote(j2);
  perform pg_temp.t(true, '50 profissional retira a proposta');
  reset role;
  perform pg_temp.login(p4);
  begin
    insert into public.quotes (job_id, provider_id, price) values (j2, p4, 90);
    perform pg_temp.t(true, '51 proposta retirada libera vaga no limite de 3');
  exception when others then perform pg_temp.t(false, '51 vaga não liberada: ' || sqlerrm); end;
  reset role;

  -- ===== EMERGÊNCIA =====
  perform pg_temp.login(c);
  insert into public.jobs (client_id, title, description, category, urgency, visibility, address_summary)
  values (c, 'Vazamento intenso', 'Cano estourou', 'Encanador', 'emergency', 'direct', 'Centro') returning id into je;
  insert into public.job_addresses (job_id, address_line) values (je, 'Rua A, 1');
  perform public.invite_providers(je, array[p2]);
  perform public.request_emergency_mock(je, 'pix');
  select payment_status into st from public.jobs where id = je;
  perform pg_temp.t(st = 'escrow', '52 emergência: reserva paga ANTES do aceite (escrow)');
  reset role;
  perform pg_temp.login(p3);
  begin
    perform public.accept_emergency(je);
    perform pg_temp.t(false, '53 profissional não convidado aceitou emergência PERMITIDO');
  exception when others then perform pg_temp.t(true, '53 só o convidado aceita a emergência'); end;
  reset role;
  perform pg_temp.login(p2);
  perform public.accept_emergency(je);
  select status, provider_id::text into r from public.jobs where id = je;
  perform pg_temp.t(r.status = 'in_progress' and r.provider_id = p2::text, '54 aceite da emergência -> in_progress com o profissional');
  select count(*) into n from public.job_secrets where job_id = je;
  reset role;
  select count(*) into n from public.job_secrets where job_id = je;
  perform pg_temp.t(n = 1, '55 PIN gerado no aceite da emergência');

  -- emergência que expira: estorno automático
  perform pg_temp.login(c);
  insert into public.jobs (client_id, title, description, category, urgency, visibility, address_summary)
  values (c, 'Curto-circuito', 'Cheiro de queimado', 'Elétrica', 'emergency', 'direct', 'Centro') returning id into je2;
  insert into public.job_addresses (job_id, address_line) values (je2, 'Rua B, 2');
  perform public.invite_providers(je2, array[p3]);
  perform public.request_emergency_mock(je2, 'credit_card');
  reset role;
  update public.job_invites set expires_at = now() - interval '1 minute' where job_id = je2;
  perform public.expire_invites();
  select status, payment_status into r from public.jobs where id = je2;
  perform pg_temp.t(r.status = 'canceled' and r.payment_status = 'refunded', '56 emergência sem resposta expira e ESTORNA a reserva');

  -- cliente cancela emergência pendente: estorno
  perform pg_temp.login(c);
  insert into public.jobs (client_id, title, description, category, urgency, visibility, address_summary)
  values (c, 'Fechadura', 'Chave quebrou', 'Chaveiro', 'emergency', 'direct', 'Centro') returning id into je3;
  insert into public.job_addresses (job_id, address_line) values (je3, 'Rua C, 3');
  perform public.invite_providers(je3, array[p1]);
  perform public.request_emergency_mock(je3, 'pix');
  perform public.cancel_job(je3);
  reset role;
  select payment_status into st from public.jobs where id = je3;
  perform pg_temp.t(st = 'refunded', '57 cancelar emergência pendente ESTORNA a reserva');

  -- ===== SUPORTE / DISPUTA =====
  perform pg_temp.login(p2);
  select public.create_support_ticket(je, 'O cliente não tem o código', 'Cliente sem o PIN') into q3;
  reset role;
  select status into st from public.jobs where id = je;
  perform pg_temp.t(st = 'disputed', '58 chamado de suporte congela o serviço (disputed)');
  perform pg_temp.login(p3);
  select count(*) into n from public.support_tickets where id = q3;
  perform pg_temp.t(n = 0, '59 chamado é privado do autor');
  begin
    perform public.admin_resolve_dispute(q3, true, 'x');
    perform pg_temp.t(false, '60 não-admin resolveu disputa PERMITIDO');
  exception when others then perform pg_temp.t(true, '60 só admin resolve disputa'); end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  perform public.admin_resolve_dispute(q3, false, 'Reembolso');
  select status, payment_status into r from public.jobs where id = je;
  perform pg_temp.t(r.status = 'canceled' and r.payment_status = 'refunded', '61 admin devolve o valor ao cliente');

  -- ===== ANON =====
  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role anon';
  begin
    perform 1 from public.jobs limit 1;
    perform pg_temp.t(false, '62 anon leu jobs PERMITIDO');
  exception when others then perform pg_temp.t(true, '62 anon sem acesso a jobs'); end;
  begin
    perform 1 from public.provider_public_profiles limit 1;
    perform pg_temp.t(false, '63 anon leu a view de profissionais PERMITIDO');
  exception when others then perform pg_temp.t(true, '63 anon sem acesso aos profissionais'); end;
  reset role;

  -- ---------------------------------------------------------------- relatório
  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
