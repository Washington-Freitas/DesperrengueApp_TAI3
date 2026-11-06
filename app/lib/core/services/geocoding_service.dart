import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geocode_models.dart';
import '../models/scheduling_models.dart';
import 'scheduling_service.dart';

/// Geocodificação direta no Nominatim (OpenStreetMap), feita no celular do CLIENTE.
///
/// Política do OSM: User-Agent identificável, ≤ 1 requisição/segundo e baixo volume — por isso as
/// consultas são sequenciais com 1,1 s de intervalo e o resultado é gravado (`set_job_location`)
/// uma única vez por serviço.
class GeocodingService {
  GeocodingService({http.Client? client, this.timeout = const Duration(seconds: 8), this.gap = const Duration(milliseconds: 1100)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final Duration gap;

  static const _headers = {'User-Agent': 'Desperrengue/1.0 (suporte@desperrengue.tech)', 'Accept-Language': 'pt-BR'};

  Future<GeocodeHit?> geocode(String addressLine, {String? summary}) async {
    final queries = buildGeocodeQueries(parseAddressLine(addressLine, summary: summary));
    for (var i = 0; i < queries.length; i++) {
      if (i > 0) await Future<void>.delayed(gap);
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
        'countrycodes': 'br',
        'q': queries[i],
      });
      try {
        final res = await _client.get(uri, headers: _headers).timeout(timeout);
        if (res.statusCode != 200) continue;
        final hit = parseNominatimSearch(jsonDecode(utf8.decode(res.bodyBytes)));
        if (hit != null) return hit;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Geocodifica o endereço do serviço e registra o ponto (melhor esforço, nunca lança).
/// Só o cliente dono consegue gravar; um pino já confirmado nunca é sobrescrito (regra no banco).
Future<JobDestination?> registerGeocodedLocation({
  required String jobId,
  required String addressLine,
  String? summary,
  GeocodingService? geocoder,
  SchedulingBackend? backend,
}) async {
  try {
    final hit = await (geocoder ?? GeocodingService()).geocode(addressLine, summary: summary);
    if (hit == null) return null;
    return await (backend ?? SupabaseSchedulingBackend()).setLocation(
      jobId,
      hit.lat,
      hit.lng,
      source: 'client_geocode',
      precision: hit.precision == DestinationPrecision.exact ? 'house' : hit.precision.wire,
    );
  } catch (_) {
    return null;
  }
}
