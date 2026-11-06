-- ============================================================================
-- DESPERRENGUE — Geocodificação feita pelo CLIENTE (dono do endereço) com precisão registrada.
--
-- POR QUÊ: o Nominatim público devolve 403 para IPs de datacenter (Edge Functions), então a
-- geocodificação no servidor não funciona. O app do CLIENTE geocodifica no próprio celular
-- (permitido pela política do OSM, baixo volume) e registra o ponto aqui, junto com a qualidade
-- (`house`/`street`/`locality`) — que define o raio do geofence. O servidor não confia no
-- PROFISSIONAL para isso: só o cliente dono grava. O pino confirmado (`client_pin`) sempre vence.
-- ============================================================================

drop function if exists public.set_job_location(uuid, double precision, double precision);

create or replace function public.set_job_location(
  p_job uuid, p_lat double precision, p_lng double precision,
  p_source text default 'client_pin', p_precision text default 'house')
returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; g public.job_geo%rowtype; v_prec text;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Coordenadas inválidas.' using errcode = '22023';
  end if;
  if p_source not in ('client_pin', 'client_geocode') then
    raise exception 'Origem de localização inválida.' using errcode = '22023';
  end if;
  -- Pino do cliente = ele apontou a casa: sempre `house`. Geocodificação: a qualidade informada.
  v_prec := case when p_source = 'client_pin' then 'house' else p_precision end;
  if v_prec not in ('house', 'street', 'locality') then
    raise exception 'Precisão inválida.' using errcode = '22023';
  end if;

  select * into j from public.jobs where id = p_job and client_id = auth.uid() for update;
  if not found or j.status not in ('open', 'awaiting_payment', 'scheduled') then
    raise exception 'Localização não pode ser alterada agora.' using errcode = 'P0001';
  end if;

  select * into g from public.job_geo where job_id = p_job;
  if found and g.source = 'client_pin' and p_source = 'client_geocode' then
    -- Um pino já confirmado nunca é sobrescrito por geocodificação automática.
    return public._job_destination(j);
  end if;

  insert into public.job_geo (job_id, lat, lng, precision_level, source, display_name)
  values (p_job, p_lat, p_lng, v_prec, p_source,
          case when p_source = 'client_pin' then 'Pino confirmado pelo cliente' else 'Geocodificado pelo app do cliente' end)
  on conflict (job_id) do update
    set lat = excluded.lat, lng = excluded.lng, precision_level = excluded.precision_level,
        source = excluded.source, display_name = excluded.display_name, resolved_at = now();
  return public._job_destination(j);
end $$;
revoke all on function public.set_job_location(uuid, double precision, double precision, text, text) from public, anon;
grant execute on function public.set_job_location(uuid, double precision, double precision, text, text) to authenticated;

-- O destino passa a aceitar qualquer origem do cliente em `job_geo` (raio pela qualidade).
create or replace function public._job_destination(j public.jobs) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare g public.job_geo%rowtype;
begin
  select * into g from public.job_geo where job_id = j.id;
  if found and g.source = 'client_pin' then
    return jsonb_build_object('lat', g.lat, 'lng', g.lng, 'precision', 'exact', 'radius_m', 100, 'source', 'client_pin');
  end if;
  if j.latitude is not null and j.longitude is not null then
    return jsonb_build_object('lat', j.latitude, 'lng', j.longitude, 'precision', 'exact', 'radius_m', 100, 'source', 'client');
  end if;
  if found then
    return jsonb_build_object('lat', g.lat, 'lng', g.lng, 'precision', g.precision_level,
             'radius_m', case g.precision_level when 'house' then 100 when 'street' then 250 else 0 end,
             'source', g.source);
  end if;
  return null;
end $$;
revoke all on function public._job_destination(public.jobs) from public, anon, authenticated;

-- Ao pagar, também pede ao CLIENTE para confirmar o local no mapa (sem ponto confiável o geofence
-- não tem o que validar).
do $$
declare d text;
begin
  d := pg_get_functiondef('public.pay_job_mock(uuid,text,timestamptz)'::regprocedure);
  if position(E'  return v_id;\nend' in d) = 0 then raise exception 'pay_job_mock mudou: ajuste o patch desta migration.'; end if;
  execute replace(d, E'  return v_id;\nend',
    E'  if j.urgency <> ''emergency'' then\n    perform public.notify_user(j.client_id, ''confirm_location'', ''Confirme o local do serviço'',\n      ''Abra o serviço agendado e confirme no mapa onde o profissional deve chegar: ele só consegue iniciar a menos de 100 m do ponto.'', j.id);\n  end if;\n  return v_id;\nend');
end $$;
