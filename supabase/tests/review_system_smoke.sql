-- ============================================================================
-- DESPERRENGUE — Teste de fumaça do SISTEMA DE AVALIAÇÕES
--
-- Roda dentro de UMA transação SEMPRE abortada (nada é gravado). Relatório na
-- mensagem do erro:
--
--   supabase db query --linked -f supabase/tests/review_system_smoke.sql
--
-- Requer >= 5 linhas em public.profiles. Cobre: avaliação cega, revelação,
-- direito de resposta único, fotos, Média Bayesiana, selos e reputação do cliente.
--   c = cliente   p1 = profissional (avaliado)   p2 = profissional (selos)
--   p3 = profissional (volume)   p4 = profissional (nota baixa → baixa C)
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

-- cria um serviço concluído (cliente c, profissional p)
create function pg_temp.done_job(c uuid, p uuid, title text) returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  insert into public.jobs (client_id, title, description, category)
  values (c, title, 'desc', 'Elétrica') returning id into j;
  update public.jobs set provider_id = p, status = 'completed', payment_status = 'released' where id = j;
  return j;
end $$;

do $$
declare
  ids uuid[]; c uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid;
  j uuid; jj uuid; n int; r record; s text; rid uuid; a numeric; b numeric; ca numeric; i int;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'TESTE ABORTADO: são necessários >= 5 perfis.';
  end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3]; p3 := ids[4]; p4 := ids[5];

  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_client = true, client_setup_done = true where id = c;
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true
   where id in (p1, p2, p3, p4);
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee)
    select id, array['Elétrica'], 30 from public.profiles where id in (p1, p2, p3, p4);

  -- ===== AVALIAÇÃO CEGA =====
  j := pg_temp.done_job(c, p1, 'Trocar disjuntor');
  perform pg_temp.login(c);
  perform public.submit_review(j, 5, 'Excelente', array['Super pontual', 'Preço honesto']);
  perform pg_temp.t(public.review_status(j) = 'waiting', '01 após avaliar, o status é "waiting" (aguardando a outra parte)');
  reset role;
  select count(*) into n from public.reviews where job_id = j and revealed_at is null;
  perform pg_temp.t(n = 1, '02 a avaliação fica OCULTA (revealed_at nulo)');

  perform pg_temp.login(p1);
  select count(*) into n from public.reviews where reviewee_id = p1;
  perform pg_temp.t(n = 0, '03 o avaliado NÃO vê a nota recebida antes da revelação');
  select count(*) into n from public.public_reviews where provider_id = p1;
  perform pg_temp.t(n = 0, '04 avaliação oculta não aparece no perfil público');
  begin
    perform public.reply_to_review((select id from public.reviews where job_id = j limit 1), 'Obrigado!');
    perform pg_temp.t(false, '05 responder avaliação oculta PERMITIDO');
  exception when others then perform pg_temp.t(true, '05 não responde avaliação ainda oculta'); end;
  reset role;
  select rating_count into n from public.provider_profiles where user_id = p1;
  perform pg_temp.t(n = 0, '06 nota agregada NÃO muda enquanto a avaliação está oculta');

  -- ===== REVELAÇÃO (as duas partes avaliaram) =====
  perform pg_temp.login(p1);
  perform public.submit_review(j, 4, 'Cliente educado', array['Ambiente seguro']);
  select count(*) into n from public.reviews where reviewee_id = p1;
  perform pg_temp.t(n = 1, '07 depois que ambos avaliam, o profissional vê a nota recebida');
  reset role;
  select rating_count, rating_avg::int into r from public.provider_profiles where user_id = p1;
  perform pg_temp.t(r.rating_count = 1 and r.rating_avg = 5, '08 nota agregada atualizada na revelação');
  select count(*) into n from public.public_reviews where provider_id = p1;
  perform pg_temp.t(n = 1, '09 avaliação revelada aparece no perfil público');

  -- ===== DIREITO DE RESPOSTA =====
  select id into rid from public.reviews where job_id = j and reviewee_id = p1;
  perform pg_temp.login(c);
  begin
    perform public.reply_to_review(rid, 'Eu mesmo respondo');
    perform pg_temp.t(false, '10 quem escreveu respondeu à própria avaliação PERMITIDO');
  exception when others then perform pg_temp.t(true, '10 só o avaliado responde'); end;
  reset role;
  perform pg_temp.login(p1);
  perform public.reply_to_review(rid, 'Obrigado pela confiança!');
  perform pg_temp.t(true, '11 profissional responde publicamente');
  begin
    perform public.reply_to_review(rid, 'Segunda resposta');
    perform pg_temp.t(false, '12 segunda resposta PERMITIDA');
  exception when others then perform pg_temp.t(true, '12 resposta só uma vez por avaliação'); end;
  select count(*) into n from public.public_reviews where provider_id = p1 and reply = 'Obrigado pela confiança!';
  perform pg_temp.t(n = 1, '13 resposta aparece junto da avaliação');
  reset role;

  -- ===== FOTOS =====
  jj := pg_temp.done_job(c, p1, 'Instalar tomada');
  perform pg_temp.login(c);
  begin
    perform public.submit_review(jj, 5, null, '{}', 0, null, array[p2::text || '/foto.jpg']);
    perform pg_temp.t(false, '14 foto de outro usuário PERMITIDA');
  exception when others then perform pg_temp.t(true, '14 foto precisa estar na pasta do próprio usuário'); end;
  begin
    perform public.submit_review(jj, 5, null, '{}', 0, null,
      array[c::text || '/1.jpg', c::text || '/2.jpg', c::text || '/3.jpg', c::text || '/4.jpg']);
    perform pg_temp.t(false, '15 4 fotos PERMITIDAS');
  exception when others then perform pg_temp.t(true, '15 máximo de 3 fotos'); end;
  begin
    perform public.submit_review(jj, 9);
    perform pg_temp.t(false, '16 nota 9 PERMITIDA');
  exception when others then perform pg_temp.t(true, '16 nota fora de 1..5 rejeitada'); end;
  perform public.submit_review(jj, 5, 'Ficou ótimo', array['Mestre no que faz'], 0, null, array[c::text || '/antes.jpg', c::text || '/depois.jpg']);
  reset role;
  perform pg_temp.login(p1);
  begin
    perform public.submit_review(jj, 5, null, '{}', 0, null, array[p1::text || '/x.jpg']);
    perform pg_temp.t(false, '17 profissional anexou foto PERMITIDO');
  exception when others then perform pg_temp.t(true, '17 só o cliente anexa fotos'); end;
  perform public.submit_review(jj, 5);
  select count(*) into n from public.public_reviews where provider_id = p1 and cardinality(photo_paths) = 2;
  perform pg_temp.t(n = 1, '18 fotos do serviço aparecem na avaliação pública');
  reset role;

  -- ===== SELOS (15 marcações / 20 notas 5) =====
  for i in 1..20 loop
    jj := pg_temp.done_job(c, p2, 'Serviço ' || i);
    insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, tags, revealed_at)
    values (jj, c, p2, 5, case when i <= 15 then array['Limpou tudo depois'] else '{}'::text[] end, now() - (21 - i) * interval '1 hour');
  end loop;
  perform public.refresh_provider_reputation(p2);
  select badges, rating_count into r from public.provider_profiles where user_id = p2;
  perform pg_temp.t('organizacao' = any (r.badges), '19 15 marcações "Limpou tudo depois" -> selo Mestre da Organização');
  perform pg_temp.t('super' = any (r.badges), '20 20 últimas notas 5 -> selo Super Profissional');
  perform pg_temp.t(r.rating_count = 20, '21 contador reflete só avaliações reveladas');
  select count(*) into n from public.notifications where user_id = p2 and kind = 'badge_earned';
  perform pg_temp.t(n = 2, '22 profissional é notificado de cada selo novo');

  -- ===== MÉDIA BAYESIANA =====
  for i in 1..20 loop
    jj := pg_temp.done_job(c, p4, 'Ruim ' || i);
    insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, revealed_at) values (jj, c, p4, 1, now());
  end loop;
  -- A: 1 serviço nota 5,0   |   B: 85 serviços média 4,88
  update public.provider_profiles set rating_count = 1,  rating_avg = 5,    rating_recent_avg = 5    where user_id = p1;
  update public.provider_profiles set rating_count = 85, rating_avg = 4.88, rating_recent_avg = 4.88 where user_id = p3;
  select rank_score into a from public.provider_public_profiles where id = p1;
  select rank_score into b from public.provider_public_profiles where id = p3;
  ca := public.platform_avg_rating();
  perform pg_temp.t(b > a, '23 Bayes: 85 serviços (4,88) fica ACIMA de 1 serviço (5,0) — A=' || a || ' B=' || b || ' C=' || ca);
  perform pg_temp.t(abs(b - round((85.0 / 90) * 4.88 + (5.0 / 90) * ca, 3)) < 0.002, '24 rank_score segue WR = v/(v+m)*R + m/(v+m)*C');
  update public.provider_profiles set rating_count = 0, rating_avg = 0, rating_recent_avg = 0 where user_id = p3;
  select rank_score into b from public.provider_public_profiles where id = p3;
  perform pg_temp.t(abs(b - ca) < 0.002, '25 novato sem avaliações começa na média da plataforma (C)');

  -- ===== REPUTAÇÃO DO CLIENTE =====
  perform pg_temp.login(p3);
  begin
    perform * from public.client_reputation(c);
    perform pg_temp.t(false, '26 profissional sem relação leu reputação do cliente PERMITIDO');
  exception when others then perform pg_temp.t(true, '26 reputação do cliente só para profissionais envolvidos'); end;
  reset role;
  perform pg_temp.login(p1);
  select avg_rating, rating_count into r from public.client_reputation(c);
  perform pg_temp.t(r.rating_count >= 1 and r.avg_rating >= 4, '27 profissional contratado vê a reputação do cliente (' || r.avg_rating || ' / ' || r.rating_count || ')');
  reset role;

  -- ===== SEGURANÇA =====
  perform pg_temp.login(p1);
  begin
    update public.provider_profiles set badges = array['super'] where user_id = p1;
    perform pg_temp.t(false, '28 profissional deu selo a si mesmo PERMITIDO');
  exception when others then perform pg_temp.t(true, '28 selos só pelo sistema'); end;
  begin
    update public.reviews set rating = 5, reply = 'hack' where reviewee_id = p1;
    perform pg_temp.t(false, '29 UPDATE direto em reviews PERMITIDO');
  exception when others then perform pg_temp.t(true, '29 reviews só por RPC'); end;
  reset role;
  execute 'set local role anon';
  begin
    perform 1 from public.public_reviews limit 1;
    perform pg_temp.t(false, '30 anon leu avaliações PERMITIDO');
  exception when others then perform pg_temp.t(true, '30 anon sem acesso às avaliações'); end;
  reset role;

  -- ---------------------------------------------------------------- relatório
  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (AVALIAÇÕES) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
