/// Modelos puros do serviço AGENDADO: destino, dupla trava de início (horário + geofence),
/// rota (OSRM) e erros da RPC `start_job`. Sem Flutter/Supabase → testável.
library;

import '../utils/geo.dart';

/// Janela antes do horário em que o profissional já pode iniciar (espelha `start_job`).
const Duration kStartWindow = Duration(minutes: 15);

/// Qualidade do ponto de destino (espelha `job_destination` no servidor).
enum DestinationPrecision {
  exact('exact'),
  house('house'),
  street('street'),
  locality('locality');

  const DestinationPrecision(this.wire);
  final String wire;

  static DestinationPrecision parse(String? v) =>
      DestinationPrecision.values.firstWhere((p) => p.wire == v, orElse: () => DestinationPrecision.locality);
}

class JobDestination {
  const JobDestination({
    required this.lat,
    required this.lng,
    required this.precision,
    required this.radiusM,
    required this.source,
  });

  final double lat;
  final double lng;
  final DestinationPrecision precision;

  /// Raio de tolerância do geofence (0 = ponto impreciso demais para validar presença).
  final double radiusM;

  /// `client_pin` · `client` · `nominatim`.
  final String source;

  /// O ponto serve para validar presença?
  bool get usableForCheckIn => radiusM > 0;

  /// O cliente ainda pode melhorar o ponto confirmando o pino no mapa.
  bool get needsClientPin => source != 'client_pin';

  static JobDestination? fromMap(Map<String, dynamic>? m) {
    if (m == null || m['lat'] == null || m['lng'] == null) return null;
    return JobDestination(
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      precision: DestinationPrecision.parse(m['precision'] as String?),
      radiusM: (m['radius_m'] as num?)?.toDouble() ?? 0,
      source: (m['source'] as String?) ?? 'nominatim',
    );
  }
}

/// Posição do aparelho (o que o app envia ao servidor).
class GeoFix {
  const GeoFix(this.lat, this.lng, {this.accuracyM});
  final double lat;
  final double lng;
  final double? accuracyM;
}

enum GeoGateState { ok, tooFar, noPosition, noDestination, imprecise, lowAccuracy, permissionDenied }

/// Precisão máxima aceita do GPS (espelha `START_LOW_ACCURACY` no servidor).
const double kMaxAccuracyM = 100;

/// Resultado da dupla trava que habilita o botão "Iniciar serviço".
class StartGate {
  const StartGate({
    required this.timeOk,
    required this.geo,
    this.opensAt,
    this.untilOpen,
    this.distanceM,
    this.radiusM,
  });

  /// Horário: agora (relógio do SERVIDOR) >= agendamento − 15 min.
  final bool timeOk;
  final DateTime? opensAt;
  final Duration? untilOpen;

  final GeoGateState geo;
  final double? distanceM;
  final double? radiusM;

  bool get geoOk => geo == GeoGateState.ok;

  /// Só libera com as DUAS travas verdes (o servidor revalida tudo em `start_job`).
  bool get canStart => timeOk && geoOk;
}

StartGate evaluateStartGate({
  required DateTime serverNow,
  required DateTime? scheduledFor,
  required JobDestination? destination,
  required GeoFix? position,
  bool permissionDenied = false,
  Duration window = kStartWindow,
}) {
  DateTime? opensAt;
  var timeOk = true;
  Duration? until;
  if (scheduledFor != null) {
    opensAt = scheduledFor.subtract(window);
    timeOk = !serverNow.isBefore(opensAt);
    if (!timeOk) until = opensAt.difference(serverNow);
  }

  GeoGateState geo;
  double? dist;
  double? radius;
  if (permissionDenied) {
    geo = GeoGateState.permissionDenied;
  } else if (destination == null) {
    geo = GeoGateState.noDestination;
  } else if (!destination.usableForCheckIn) {
    geo = GeoGateState.imprecise;
    radius = destination.radiusM;
  } else if (position == null) {
    geo = GeoGateState.noPosition;
    radius = destination.radiusM;
  } else {
    final r = destination.radiusM;
    radius = r;
    dist = haversineMeters(position.lat, position.lng, destination.lat, destination.lng);
    if (position.accuracyM != null && position.accuracyM! > kMaxAccuracyM) {
      geo = GeoGateState.lowAccuracy;
    } else {
      geo = dist <= r ? GeoGateState.ok : GeoGateState.tooFar;
    }
  }
  return StartGate(timeOk: timeOk, geo: geo, opensAt: opensAt, untilOpen: until, distanceM: dist, radiusM: radius);
}

// --------------------------------------------------------------------------- rota (OSRM)

class RouteInfo {
  const RouteInfo({required this.distanceM, required this.durationS, required this.points});
  final double distanceM;
  final double durationS;

  /// Polilinha da rota nas ruas, em (lat, lng).
  final List<({double lat, double lng})> points;

  Duration get eta => Duration(seconds: durationS.round());
}

/// Resposta do OSRM (`/route/v1/driving/...?overview=full&geometries=geojson`).
/// GeoJSON usa [lng, lat] — invertido aqui para (lat, lng).
RouteInfo? parseOsrmRoute(Map<String, dynamic>? json) {
  if (json == null || json['code'] != 'Ok') return null;
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty) return null;
  final r = routes.first as Map<String, dynamic>;
  final coords = ((r['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?) ?? const [];
  final pts = <({double lat, double lng})>[
    for (final c in coords)
      if (c is List && c.length >= 2) (lat: (c[1] as num).toDouble(), lng: (c[0] as num).toDouble()),
  ];
  if (pts.isEmpty) return null;
  return RouteInfo(
    distanceM: (r['distance'] as num?)?.toDouble() ?? 0,
    durationS: (r['duration'] as num?)?.toDouble() ?? 0,
    points: pts,
  );
}

// --------------------------------------------------------------------------- erros de `start_job`

enum StartFailureKind {
  tooEarly,
  tooFar,
  noPosition,
  lowAccuracy,
  noDestination,
  imprecise,
  invalidState,
  sandboxOff,
  other,
}

/// Erro tipado das RPCs de início (a mensagem do Postgres traz um código `START_*`).
class StartJobFailure implements Exception {
  const StartJobFailure(this.kind, this.message, {this.opensAt, this.distanceM, this.radiusM});

  final StartFailureKind kind;
  final String message;
  final DateTime? opensAt;
  final double? distanceM;
  final double? radiusM;

  /// Interpreta o texto do erro (`PostgrestException.message`/`toString()`).
  factory StartJobFailure.parse(Object error) {
    final raw = error.toString();
    final m = RegExp(r'START_([A-Z_]+)(?:\|([^|\s,)]+))?(?:\|([^|\s,)]+))?').firstMatch(raw);
    if (m == null) return StartJobFailure(StartFailureKind.other, 'Não foi possível iniciar o serviço agora.');
    final code = m.group(1)!;
    final a = m.group(2);
    final b = m.group(3);
    switch (code) {
      case 'TOO_EARLY':
        return StartJobFailure(StartFailureKind.tooEarly, 'Ainda não é a hora do serviço.',
            opensAt: a == null ? null : DateTime.tryParse(a)?.toLocal());
      case 'TOO_FAR':
        return StartJobFailure(
          StartFailureKind.tooFar,
          'Você ainda não está no local do cliente.',
          distanceM: double.tryParse(a ?? ''),
          radiusM: double.tryParse(b ?? ''),
        );
      case 'NO_POSITION':
        return StartJobFailure(StartFailureKind.noPosition, 'Não conseguimos ler o seu GPS. Ative a localização.');
      case 'LOW_ACCURACY':
        return StartJobFailure(StartFailureKind.lowAccuracy, 'O sinal de GPS está fraco. Vá para um local aberto e tente de novo.');
      case 'NO_DESTINATION':
        return StartJobFailure(StartFailureKind.noDestination, 'Ainda não localizamos o endereço no mapa.');
      case 'DESTINATION_IMPRECISE':
        return StartJobFailure(StartFailureKind.imprecise, 'O endereço está impreciso no mapa. Peça ao cliente para confirmar o local.');
      case 'INVALID_STATE':
        return StartJobFailure(StartFailureKind.invalidState, 'Este serviço não está mais aguardando início.');
      case 'SANDBOX_OFF':
        return StartJobFailure(StartFailureKind.sandboxOff, 'A simulação de teste está desativada.');
      default:
        return StartJobFailure(StartFailureKind.other, 'Não foi possível iniciar o serviço agora.');
    }
  }

  @override
  String toString() => message;
}
