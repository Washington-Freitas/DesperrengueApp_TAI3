/// Geodésia básica em Dart puro (sem Flutter/Supabase), testável.
library;

import 'dart:math' as math;

/// Raio médio da Terra (m) — o mesmo usado na função SQL `haversine_m`, para o app e o
/// servidor concordarem na distância (o servidor é quem decide; o app só antecipa a UI).
const double kEarthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;

/// **Fórmula de Haversine**: distância em METROS sobre a esfera entre dois pontos (graus).
///
/// a = sin²(Δφ/2) + cos φ1 · cos φ2 · sin²(Δλ/2)
/// d = 2 · R · asin(√a)
///
/// Estável para distâncias curtas (como os 100 m do geofence), ao contrário da lei dos cossenos.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * kEarthRadiusM * math.asin(math.min(1.0, math.sqrt(a.toDouble())));
}

/// "850 m" / "3,4 km".
String formatMeters(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}

/// "12 min" / "1 h 05 min".
String formatEta(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins < 60) return '${mins <= 0 ? 1 : mins} min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')} min';
}
