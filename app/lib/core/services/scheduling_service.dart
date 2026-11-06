import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/scheduling_models.dart';

/// Resultado de um início bem-sucedido.
class StartResult {
  const StartResult({required this.startedAt, required this.simulated, this.distanceM});
  final DateTime startedAt;
  final bool simulated;
  final double? distanceM;
}

/// Contrato do backend do agendamento (permite fakes nos testes).
abstract class SchedulingBackend {
  /// Hora do SERVIDOR (o relógio do celular pode ser adulterado).
  Future<DateTime> serverTime();

  /// Destino do serviço (ou null se ainda não foi localizado).
  Future<JobDestination?> destination(String jobId);

  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false});

  /// Só o CLIENTE dono grava o destino: client_pin (pino confirmado no mapa, sempre vence) ou
  /// client_geocode (geocodificação do app, com a qualidade house/street/locality).
  Future<JobDestination?> setLocation(String jobId, double lat, double lng, {String source = 'client_pin', String precision = 'house'});
}

class SupabaseSchedulingBackend implements SchedulingBackend {
  SupabaseSchedulingBackend([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<DateTime> serverTime() async {
    final r = await _client.rpc('server_time');
    return DateTime.parse(r as String).toLocal();
  }

  @override
  Future<JobDestination?> destination(String jobId) async {
    final r = await _client.rpc('job_destination', params: {'p_job': jobId});
    return JobDestination.fromMap((r as Map?)?.cast<String, dynamic>());
  }

  @override
  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false}) async {
    try {
      final r = await _client.rpc('start_job', params: {
        'p_job': jobId,
        'p_lat': position?.lat,
        'p_lng': position?.lng,
        'p_accuracy_m': position?.accuracyM,
        'p_simulate': simulate,
      });
      final m = (r as Map).cast<String, dynamic>();
      return StartResult(
        startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
        simulated: (m['simulated'] as bool?) ?? false,
        distanceM: (m['distance_m'] as num?)?.toDouble(),
      );
    } on PostgrestException catch (e) {
      throw StartJobFailure.parse(e);
    }
  }

  @override
  Future<JobDestination?> setLocation(String jobId, double lat, double lng, {String source = 'client_pin', String precision = 'house'}) async {
    final r = await _client.rpc('set_job_location', params: {'p_job': jobId, 'p_lat': lat, 'p_lng': lng, 'p_source': source, 'p_precision': precision});
    return JobDestination.fromMap((r as Map?)?.cast<String, dynamic>());
  }
}

/// Relógio sincronizado com o servidor: `now()` = hora do aparelho + deslocamento medido.
class ServerClock {
  ServerClock(this._backend, {DateTime Function()? deviceNow}) : _deviceNow = deviceNow ?? DateTime.now;

  final SchedulingBackend _backend;
  final DateTime Function() _deviceNow;
  Duration _offset = Duration.zero;
  bool synced = false;

  DateTime now() => _deviceNow().add(_offset);

  /// Mede o deslocamento usando o ponto médio da requisição (compensa a latência de ida e volta).
  Future<void> sync() async {
    final t0 = _deviceNow();
    final server = await _backend.serverTime();
    final t1 = _deviceNow();
    final mid = t0.add(Duration(microseconds: t1.difference(t0).inMicroseconds ~/ 2));
    _offset = server.difference(mid);
    synced = true;
  }
}

/// Rota de carro pela API pública e gratuita do OSRM (Open Source Routing Machine).
/// Política de uso: demo server para baixo volume; falhando, a UI usa a linha reta.
class RoutingService {
  RoutingService({http.Client? client, this.timeout = const Duration(seconds: 8)}) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<RouteInfo?> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    // OSRM espera lng,lat (GeoJSON), nesta ordem.
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson',
    );
    try {
      final res = await _client.get(uri, headers: const {'User-Agent': 'Desperrengue/1.0 (suporte@desperrengue.tech)'}).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return parseOsrmRoute(body is Map<String, dynamic> ? body : null);
    } catch (_) {
      return null;
    }
  }
}
