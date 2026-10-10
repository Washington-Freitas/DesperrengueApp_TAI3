-- ============================================================================
-- DESPERRENGUE — Teste de fumaça de segurança/regras do banco
--
-- Roda tudo dentro de UMA transação que é SEMPRE abortada no final (RAISE
-- EXCEPTION), então nada é gravado. O relatório vem na mensagem do erro:
--
--   supabase db query --linked -f supabase/tests/security_smoke.sql
--
-- Requer pelo menos 6 linhas em public.profiles (usa contas existentes como
-- "atores" e ajusta os papéis só dentro da transação).
-- ============================================================================
do $$
declare
  ids uuid[];
  c uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; pn uuid;
  j uuid; q1 uuid; n int; st text;
  res text := '';
  ok  int := 0;
  bad int := 0;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 6 then
    raise exception 'TESTE ABORTADO: são necessários >= 6 perfis (existem %).', coalesce(array_length(ids, 1), 0);
  end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3]; p3 := ids[4]; p4 := ids[5]; pn := ids[6];

  -- Preparação (como postgres)
  update public.profiles set role = 'client' where id = c;
  update public.profiles set role = 'provider', verification_status = 'ACTIVE' where id in (p1, p2, p3, p4);
  update public.profiles set role = 'provider', verification_status = 'NOT_SUBMITTED' where id = pn;

  -- ===== 1. Auto-aprovação bloqueada =====
  perform set_config('request.jwt.claims', json_build_object('sub', pn, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    update public.profiles set verification_status = 'ACTIVE' where id = pn;
    res := res || E'FAIL  1 auto-aprovação permitida\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    1 auto-aprovação bloqueada (' || sqlerrm || E')\n'; ok := ok + 1;
  end;

  -- ===== 2. Escalada de papel bloqueada =====
  begin
    update public.profiles set role = 'admin' where id = pn;
    res := res || E'FAIL  2 escalada para admin permitida\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    2 escalada para admin bloqueada (' || sqlerrm || E')\n'; ok := ok + 1;
  end;

  -- ===== 3. Escrita direta em kyc_submissions bloqueada =====
  begin
    insert into public.kyc_submissions (user_id, front_path, back_path, selfie_path, registry_type, registry_number)
    values (pn, 'x', 'y', 'z', 'CREA', '1');
    res := res || E'FAIL  3 insert direto em kyc_submissions permitido\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    3 insert direto em kyc_submissions bloqueado\n'; ok := ok + 1;
  end;

  -- ===== 4. submit_kyc: caminho de outra pasta rejeitado; correto aceito; reenvio rejeitado =====
  begin
    perform public.submit_kyc(c || '/a.jpg', pn || '/b.jpg', pn || '/c.jpg', 'CREA', '123');
    res := res || E'FAIL  4a caminho de outro usuário aceito\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    4a caminho de outro usuário rejeitado\n'; ok := ok + 1;
  end;
  begin
    perform public.submit_kyc(pn || '/a.jpg', pn || '/b.jpg', pn || '/c.jpg', 'CREA', '123');
    select verification_status::text into st from public.profiles where id = pn;
    if st = 'PENDING' then res := res || E'ok    4b submit_kyc válido -> PENDING\n'; ok := ok + 1;
    else res := res || E'FAIL  4b status após submit = ' || st || E'\n'; bad := bad + 1; end if;
  exception when others then
    res := res || E'FAIL  4b submit_kyc válido falhou: ' || sqlerrm || E'\n'; bad := bad + 1;
  end;
  begin
    perform public.submit_kyc(pn || '/a.jpg', pn || '/b.jpg', pn || '/c.jpg', 'CREA', '123');
    res := res || E'FAIL  4c reenvio durante análise permitido\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    4c reenvio durante análise rejeitado\n'; ok := ok + 1;
  end;

  -- ===== 5. Cliente cria demanda; não consegue forjar pagamento =====
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.jobs (client_id, title, description, category)
  values (c, 'Vazamento', 'Torneira da cozinha', 'encanador') returning id into j;
  res := res || E'ok    5a cliente criou demanda\n'; ok := ok + 1;
  begin
    update public.jobs set payment_status = 'released' where id = j;
    res := res || E'FAIL  5b cliente alterou payment_status\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    5b payment_status protegido\n'; ok := ok + 1;
  end;
  begin
    insert into public.jobs (client_id, title, description, category, status)
    values (c, 'x', 'x', 'x', 'completed');
    res := res || E'FAIL  5c cliente criou demanda já concluída\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    5c status inicial forçado a open\n'; ok := ok + 1;
  end;

  -- ===== 6. Orçamentos: só prestador ativo; máximo 3 =====
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', pn, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, pn, 100);
    res := res || E'FAIL  6a prestador NÃO verificado orçou\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    6a prestador não verificado bloqueado\n'; ok := ok + 1;
  end;

  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', p1, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.quotes (job_id, provider_id, price, message) values (j, p1, 100, 'a') returning id into q1;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', p2, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.quotes (job_id, provider_id, price) values (j, p2, 120);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', p3, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.quotes (job_id, provider_id, price) values (j, p3, 140);
  res := res || E'ok    6b três orçamentos aceitos\n'; ok := ok + 1;

  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', p4, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into public.quotes (job_id, provider_id, price) values (j, p4, 160);
    res := res || E'FAIL  6c 4º orçamento aceito\n'; bad := bad + 1;
  exception when others then
    if sqlerrm like 'QUOTE_LIMIT_REACHED%' then res := res || E'ok    6c 4º orçamento bloqueado (limite de 3)\n'; ok := ok + 1;
    else res := res || E'FAIL  6c erro inesperado: ' || sqlerrm || E'\n'; bad := bad + 1; end if;
  end;

  -- ===== 7. Privacidade: concorrente não vê orçamento alheio =====
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', p2, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.quotes;
  if n = 1 then res := res || E'ok    7a prestador vê só o próprio orçamento\n'; ok := ok + 1;
  else res := res || E'FAIL  7a prestador vê ' || n || E' orçamentos\n'; bad := bad + 1; end if;

  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.quotes;
  if n = 3 then res := res || E'ok    7b cliente vê os 3 orçamentos da sua demanda\n'; ok := ok + 1;
  else res := res || E'FAIL  7b cliente vê ' || n || E' orçamentos\n'; bad := bad + 1; end if;

  -- ===== 8. Aceite atômico =====
  perform public.accept_quote(q1);
  reset role;
  select status into st from public.jobs where id = j;
  select count(*) into n from public.quotes where job_id = j and status = 'rejected';
  if st = 'in_progress' and n = 2 then
    res := res || E'ok    8 aceite -> demanda in_progress e 2 concorrentes rejeitados\n'; ok := ok + 1;
  else
    res := res || E'FAIL  8 demanda=' || st || E', rejeitados=' || n || E'\n'; bad := bad + 1;
  end if;
  -- ===== 9. Anônimo sem acesso =====
  set local role anon;
  begin
    perform 1 from public.profiles limit 1;
    res := res || E'FAIL  9 anon leu profiles\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    9 anon sem acesso a profiles\n'; ok := ok + 1;
  end;
  reset role;

  -- ===== 10. Storage: só a própria pasta =====
  perform set_config('request.jwt.claims', json_build_object('sub', pn, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into storage.objects (bucket_id, name, owner_id) values ('kyc-documents', pn || '/t.jpg', pn::text);
    res := res || E'ok    10a upload na própria pasta permitido\n'; ok := ok + 1;
  exception when others then
    res := res || E'FAIL  10a upload na própria pasta negado: ' || sqlerrm || E'\n'; bad := bad + 1;
  end;
  begin
    insert into storage.objects (bucket_id, name, owner_id) values ('kyc-documents', c || '/t.jpg', pn::text);
    res := res || E'FAIL  10b upload na pasta de outro permitido\n'; bad := bad + 1;
  exception when others then
    res := res || E'ok    10b upload na pasta de outro bloqueado\n'; ok := ok + 1;
  end;
  reset role;

  -- Relatório (a exceção também desfaz toda a transação)
  raise exception E'RELATORIO_DE_TESTE\n%\nTotal ok = %, falhas = %', res, ok, bad;end $$;
