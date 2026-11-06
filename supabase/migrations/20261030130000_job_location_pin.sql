-- ============================================================================
-- DESPERRENGUE — Pino de localização confirmado pelo cliente (geofence confiável).
--
-- POR QUÊ: o OpenStreetMap/Nominatim não conhece muitas ruas brasileiras (ex.: a rua do teste só
-- resolve até a CIDADE), o que tornaria a trava de 100 m inalcançável. O cliente — dono do endereço —
-- confirma o ponto exato no mapa; o servidor passa a validar a presença do profissional contra ele.
-- Prioridade do destino: pino do cliente > coordenadas do pedido > geocodificação (Nominatim).
-- ============================================================================

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

-- Só o cliente dono, e só enquanto o serviço não começou (não dá para "mover a casa" no meio do serviço).
create or replace function public.set_job_location(p_job uuid, p_lat double precision, p_lng double precision)
returns jsonb language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype;
begin
  if auth.uid() is null then raise exception 'Sessão expirada.' using errcode = '28000'; end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Coordenadas inválidas.' using errcode = '22023';
  end if;
  select * into j from public.jobs where id = p_job and client_id = auth.uid() for update;
  if not found or j.status not in ('open', 'awaiting_payment', 'scheduled') then
    raise exception 'Localização não pode ser alterada agora.' using errcode = 'P0001';
  end if;
  insert into public.job_geo (job_id, lat, lng, precision_level, source, display_name)
  values (p_job, p_lat, p_lng, 'house', 'client_pin', 'Pino confirmado pelo cliente')
  on conflict (job_id) do update
    set lat = excluded.lat, lng = excluded.lng, precision_level = 'house', source = 'client_pin',
        display_name = excluded.display_name, resolved_at = now();
  return public._job_destination(j);
end $$;
revoke all on function public.set_job_location(uuid, double precision, double precision) from public, anon;
grant execute on function public.set_job_location(uuid, double precision, double precision) to authenticated;
