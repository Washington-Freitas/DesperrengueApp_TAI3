-- ============================================================================
-- DESPERRENGUE — Teste de fumaça: CARTEIRA/PIX, EXCLUSÃO DE CONTA (LGPD) e
-- VITRINE LIFO de cases. Migration 20261029100000.
--
-- Transação SEMPRE abortada (nada é gravado). Relatório na mensagem do erro:
--   supabase db query --linked -f supabase/tests/offboarding_showcase_smoke.sql
-- Requer >= 3 linhas em public.profiles.   c = cliente  p1/p2 = profissionais
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

-- Pedido concluido + pagamento liberado (net = 88% de amt) para (c -> p).
create function pg_temp.done_job(c uuid, p uuid, title text, amt numeric default 100) returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  insert into public.jobs (client_id, title, description, category, urgency, address_summary, address_cep)
  values (c, title, 'descrição privada', 'Elétrica', 'scheduled', 'Rua Secreta, 10', '01001000') returning id into j;
  update public.jobs set provider_id = p, status = 'completed', payment_status = 'released', agreed_price = amt where id = j;
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status, released_at)
  values (j, c, p, amt, 12, round(amt * 0.12, 2), round(amt * 0.88, 2), 'pix', 'released', now());
  return j;
end $$;

-- Avaliacao do cliente ja REVELADA, em um instante controlado (ordem LIFO).
create function pg_temp.reviewed(c uuid, p uuid, title text, stars int, at_min int) returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  j := pg_temp.done_job(c, p, title);
  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, revealed_at)
  values (j, c, p, stars, 'comentário ' || title, array['Super pontual'], now() - make_interval(mins => at_min));
  insert into public.job_evidence (job_id, provider_id, slot, path) values
    (j, p, 'clean', c::text || '/clean_' || j::text || '.jpg'),
    (j, p, 'overview', c::text || '/overview_' || j::text || '.jpg');
  return j;
end $$;

do $$
declare
  ids uuid[]; c uuid; p1 uuid; p2 uuid; j uuid; n int; s text; k int; v jsonb; w numeric;
  j_old5 uuid; j_old5b uuid; j_old5c uuid; j_old5d uuid; j_three uuid; j_new uuid; j_prog uuid; j_open uuid; j_ret uuid;
  rec record;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 3 then raise exception 'TESTE ABORTADO: são necessários >= 3 perfis.'; end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3];

  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id = c;
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true where id in (p1, p2);
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee)
    select id, array['Elétrica'], 30 from public.profiles where id in (p1, p2);

  -- ===== CARTEIRA / PIX =====
  perform pg_temp.login(p1);
  select (public.my_wallet() ->> 'available')::numeric into w;
  perform pg_temp.t(w = 0, '01 profissional novo: saldo disponível R$ 0');
  reset role;
  perform pg_temp.done_job(c, p1, 'Serviço pago', 100);   -- net 88
  perform pg_temp.login(p1);
  select (public.my_wallet() ->> 'available')::numeric into w;
  perform pg_temp.t(w = 88, '02 pagamento liberado vira saldo (88,00)');

  begin
    perform public.request_withdrawal(10, 'cpf', '12345678901', false);
    perform pg_temp.t(false, '03 saque sem declarar titularidade PERMITIDO');
  exception when others then perform pg_temp.t(true, '03 saque exige declaração de titularidade'); end;
  begin
    perform public.request_withdrawal(500, 'cpf', '12345678901', true);
    perform pg_temp.t(false, '04 saque acima do saldo PERMITIDO');
  exception when others then perform pg_temp.t(true, '04 saque acima do saldo é recusado'); end;
  begin
    perform public.request_withdrawal(-5, 'cpf', '12345678901', true);
    perform pg_temp.t(false, '05 saque negativo PERMITIDO');
  exception when others then perform pg_temp.t(true, '05 valor negativo é recusado'); end;

  perform public.request_withdrawal(40, 'cpf', '12345678901', true);
  select (public.my_wallet() ->> 'available')::numeric into w;
  perform pg_temp.t(w = 48, '06 saque de 40 reduz o saldo para 48,00 (' || w || ')');
  select count(*) into n from public.withdrawals where pix_key_hint like '%12345678901%';
  perform pg_temp.t(n = 0, '07 a chave Pix completa NÃO é guardada (só a máscara)');
  select count(*) into n from public.withdrawals where provider_id = p1 and pix_key_hint = '***8901';
  perform pg_temp.t(n = 1, '08 máscara guarda só os 4 últimos dígitos');
  reset role;

  perform pg_temp.login(p2);
  select count(*) into n from public.withdrawals;
  perform pg_temp.t(n = 0, '09 outro profissional não enxerga saques alheios');
  reset role;
  perform pg_temp.login(c);
  begin
    perform public.request_withdrawal(1, 'cpf', '12345678901', true);
    perform pg_temp.t(false, '10 cliente puro sacou PERMITIDO');
  exception when others then perform pg_temp.t(true, '10 cliente puro não saca'); end;
  reset role;

  -- ===== TRAVA DA EXCLUSÃO =====
  perform pg_temp.login(p1);
  v := public.account_deletion_status();
  perform pg_temp.t(not (v ->> 'can_delete')::boolean and v -> 'blockers' ? 'balance', '11 saldo > 0 bloqueia a exclusão (balance)');
  perform public.request_withdrawal(48, 'cpf', '12345678901', true);
  v := public.account_deletion_status();
  perform pg_temp.t((v ->> 'can_delete')::boolean, '12 saldo zerado e sem pendências libera a exclusão');
  reset role;

  insert into public.jobs (client_id, title, description, category, urgency) values (c, 'Em andamento', 'x', 'Elétrica', 'scheduled') returning id into j_prog;
  update public.jobs set provider_id = p1, status = 'in_progress' where id = j_prog;
  perform pg_temp.login(p1);
  v := public.account_deletion_status();
  perform pg_temp.t(v -> 'blockers' ? 'active_jobs', '13 serviço em andamento bloqueia (active_jobs)');
  reset role;
  update public.jobs set status = 'canceled' where id = j_prog;
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status)
    values (j_prog, c, p1, 50, 12, 6, 44, 'pix', 'escrow');
  perform pg_temp.login(p1);
  v := public.account_deletion_status();
  perform pg_temp.t(v -> 'blockers' ? 'escrow', '14 valor em custódia bloqueia (escrow)');
  reset role;
  delete from public.payments where job_id = j_prog;
  delete from public.jobs where id = j_prog;

  -- ===== VITRINE LIFO =====
  j_old5  := pg_temp.reviewed(c, p2, 'Antigo 5a', 5, 900);
  j_old5b := pg_temp.reviewed(c, p2, 'Antigo 5b', 5, 800);
  j_old5c := pg_temp.reviewed(c, p2, 'Antigo 5c', 5, 700);
  j_old5d := pg_temp.reviewed(c, p2, 'Antigo 5d', 5, 600);
  j_three := pg_temp.reviewed(c, p2, 'Nota 3', 3, 300);
  j_new   := pg_temp.reviewed(c, p2, 'Mais recente', 5, 10);

  perform pg_temp.login(p1);   -- outro usuário vendo a vitrine pública de p2
  select count(*) into n from public.provider_showcase(p2);
  perform pg_temp.t(n = 4, '15 a vitrine mostra no máximo 4 serviços (' || n || ')');
  select title into s from public.provider_showcase(p2) where pos = 0;
  perform pg_temp.t(s = 'Mais recente', '16 LIFO: o mais novo entra na posição [0] (' || s || ')');
  select count(*) into n from public.provider_showcase(p2) where title = 'Nota 3';
  perform pg_temp.t(n = 0, '17 avaliação < 4★ não entra sozinha na vitrine');
  select count(*) into n from public.provider_showcase(p2) where title = 'Antigo 5a';
  perform pg_temp.t(n = 0, '18 o 5º serviço mais antigo cai para o histórico');
  select count(*) into n from public.provider_showcase(p2) where cover_path is not null;
  perform pg_temp.t(n = 4, '19 capa = foto "Ambiente Limpo"');
  select count(*) into n from public.provider_showcase(p1);
  perform pg_temp.t(n = 0, '20 profissional sem cases tem vitrine vazia');
  begin
    perform public.pin_case(j_old5);
    perform pg_temp.t(false, '21 fixar serviço de OUTRO profissional PERMITIDO');
  exception when others then perform pg_temp.t(true, '21 só fixa o próprio serviço'); end;
  reset role;

  perform pg_temp.login(p2);
  begin
    perform public.pin_case(j_three);
    perform pg_temp.t(false, '22 fixar serviço com nota 3 PERMITIDO');
  exception when others then perform pg_temp.t(true, '22 só fixa serviço com 5 estrelas'); end;
  perform public.pin_case(j_old5);
  select pinned, pos into rec from public.provider_showcase(p2) where title = 'Antigo 5a';
  perform pg_temp.t(rec.pinned and rec.pos = 0, '23 fixado assume a posição [0] da vitrine');
  select count(*) into n from public.provider_showcase(p2);
  perform pg_temp.t(n = 4, '24 fixar não aumenta o limite de 4');
  perform public.pin_case(j_old5);  -- idempotente
  perform public.pin_case(j_old5b);
  perform public.pin_case(j_old5c);
  begin
    perform public.pin_case(j_old5d);
    perform pg_temp.t(false, '25 4º fixado PERMITIDO');
  exception when others then perform pg_temp.t(true, '25 limite de 3 fixados (sobra 1 vaga LIFO)'); end;
  select count(*) into n from public.provider_showcase(p2) where not pinned;
  perform pg_temp.t(n = 1 and (select title from public.provider_showcase(p2) where not pinned) = 'Mais recente', '26 a vaga LIFO restante mostra o mais recente');
  perform public.unpin_case(j_old5);
  select count(*) into n from public.provider_showcase(p2) where pinned;
  perform pg_temp.t(n = 2, '27 soltar libera a vaga');
  select count(*) into n from public.provider_case_history() where can_pin;
  perform pg_temp.t(n = 5, '28 histórico: 5 serviços com 5★ podem ser fixados (' || n || ')');
  select count(*) into n from public.provider_case_history() where title = 'Nota 3' and not can_pin;
  perform pg_temp.t(n = 1, '29 histórico: nota 3 aparece, mas não pode ser fixada');
  reset role;

  -- relatório técnico
  update public.jobs set status = 'in_progress' where id = j_new;
  perform pg_temp.login(p2);
  perform public.set_job_report(j_new, '  Troquei o disjuntor de 20A por um DR de 25A.  ');
  reset role;
  select provider_report into s from public.jobs where id = j_new;
  perform pg_temp.t(s = 'Troquei o disjuntor de 20A por um DR de 25A.', '30 relatório técnico é salvo sem espaços sobrando');
  perform pg_temp.login(p1);
  begin
    perform public.set_job_report(j_new, 'invasor');
    perform pg_temp.t(false, '31 outro profissional editou relatório PERMITIDO');
  exception when others then perform pg_temp.t(true, '31 só o profissional do pedido edita o relatório'); end;
  reset role;
  update public.jobs set status = 'completed' where id = j_new;
  perform pg_temp.login(p2);
  begin
    perform public.set_job_report(j_new, 'depois de concluído');
    perform pg_temp.t(false, '32 editar relatório após conclusão PERMITIDO');
  exception when others then perform pg_temp.t(true, '32 relatório trava após a conclusão'); end;
  reset role;

  -- dossiê do case
  insert into public.job_evidence (job_id, provider_id, slot, path) values (j_new, p2, 'video', c::text || '/video_' || j_new::text || '.mp4');
  perform pg_temp.login(c);
  v := public.provider_case_detail(j_new);
  perform pg_temp.t(v ->> 'report' like 'Troquei%' and jsonb_array_length(v -> 'photos') >= 2 and v ->> 'video' like '%.mp4'
                    and (v ->> 'rating')::int = 5, '33 Case de Sucesso traz relatório, fotos, vídeo e avaliação');
  perform pg_temp.t(v ->> 'client_name' is not null and (v ->> 'client_name') is distinct from (select full_name from public.profiles where id = c) or (select position(' ' in btrim(full_name)) = 0 from public.profiles where id = c), '34 mostra o cliente só por nome curto (Ana S.)');
  perform pg_temp.t(public.provider_case_detail(j_three) is null, '35 case de nota 3 não é público');
  perform pg_temp.t(public._is_case_media(c::text || '/video_' || j_new::text || '.mp4'), '36 mídia de case público é legível por logados');
  perform pg_temp.t(not public._is_case_media(c::text || '/clean_' || j_three::text || '.jpg'), '37 mídia de case NÃO público segue privada');
  reset role;
  execute 'set local role anon';
  begin
    perform public.provider_case_detail(j_new);
    perform pg_temp.t(false, '38 anon leu case PERMITIDO');
  exception when others then perform pg_temp.t(true, '38 anon sem acesso aos cases'); end;
  reset role;

  -- ===== DOSSIÊ / PURGA =====
  perform pg_temp.login(c);
  begin
    perform public.account_dossier(c);
    perform pg_temp.t(false, '39 app chamou account_dossier PERMITIDO');
  exception when others then perform pg_temp.t(true, '39 account_dossier só para service_role'); end;
  begin
    perform public.purge_account(c);
    perform pg_temp.t(false, '40 app chamou purge_account PERMITIDO');
  exception when others then perform pg_temp.t(true, '40 purge_account só para service_role'); end;
  reset role;

  v := public.account_dossier(p2);
  perform pg_temp.t((v -> 'provider' ->> 'total_profit')::numeric = 6 * 88,
                    '41 dossiê do profissional soma o lucro líquido');
  v := public.account_dossier(c);
  perform pg_temp.t((v -> 'client' ->> 'total_spent')::numeric >= 700 and jsonb_array_length(v -> 'client' -> 'orders') >= 7,
                    '42 dossiê do cliente soma o total gasto e lista os pedidos');

  insert into public.jobs (client_id, title, description, category, urgency) values (c, 'Pedido aberto', 'segredo', 'Elétrica', 'scheduled') returning id into j_open;
  select count(*) into k from public.reviews where reviewer_id = c;
  select count(*) into n from public.payments where client_id = c;
  perform public.purge_account(c);
  select count(*) into n from public.jobs where id = j_open;
  perform pg_temp.t(n = 0, '43 purga remove pedidos do cliente sem pagamento');
  select count(*) into n from public.jobs where client_id = c and description = '[conteúdo removido a pedido do titular]'
     and address_summary is null and address_cep is null;
  perform pg_temp.t(n >= 7, '44 pedidos com pagamento ficam, sem texto nem endereço (' || n || ')');
  select count(*) into n from public.account_deletion_log where user_hash = encode(extensions.digest(c::text, 'sha256'), 'hex');
  perform pg_temp.t(n = 1, '45 a exclusão é auditada só com hash (sem dado pessoal)');

  -- Simula o deleteUser da Edge Function: o perfil some e o histórico da outra parte permanece.
  select count(*) into n from public.payments where client_id = c;
  delete from public.profiles where id = c;
  select count(*) into k from public.payments where client_id is null and provider_id in (p1, p2);
  perform pg_temp.t(k >= n and k > 0, '46 pagamentos sobrevivem à exclusão do cliente (vínculo vira NULL)');
  select count(*) into k from public.reviews where reviewer_id is null and reviewee_id = p2;
  perform pg_temp.t(k >= 5, '47 avaliações recebidas pelo profissional sobrevivem (anonimizadas)');
  perform pg_temp.login(p1);
  select count(*) into k from public.provider_showcase(p2);
  reset role;
  perform pg_temp.t(k = 4, '48 a vitrine do profissional continua com 4 cases');

  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (OFFBOARDING / VITRINE) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
