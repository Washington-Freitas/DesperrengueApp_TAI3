/// Formatação pt-BR sem dependência externa (moeda, datas, tempo relativo).
library;

import 'dart:math' as math;

/// 1234.5 -> "R$ 1.234,50"
String brl(num? value) {
  final v = (value ?? 0).toDouble();
  final negative = v < 0;
  final cents = (v.abs() * 100).round();
  final intPart = (cents ~/ 100).toString();
  final frac = (cents % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '${negative ? '-' : ''}R\$ $buf,$frac';
}

/// "1.234,50" / "150" / "150,5" -> 1234.5 (null se inválido)
double? parseBrl(String raw) {
  final s = raw.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (s.isEmpty) return null;
  final normalized = s.contains(',') ? s.replaceAll('.', '').replaceAll(',', '.') : s;
  return double.tryParse(normalized);
}

const _weekdays = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String monthName(int month) => _months[month - 1];
String monthNameCap(int month) => _months[month - 1][0].toUpperCase() + _months[month - 1].substring(1);
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

String two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// "quinta-feira, 15 de outubro às 14:30"
String dateLong(DateTime d) {
  final l = d.toLocal();
  final wd = weekdayName(l);
  return '${wd[0].toUpperCase()}${wd.substring(1)}${l.weekday <= 5 ? '-feira' : ''}, '
      '${l.day} de ${monthName(l.month)} às ${hhmm(l)}';
}

/// "15/10 às 14:30"
String dateShort(DateTime d) {
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)} às ${hhmm(l)}';
}

/// "há 2 dias", "há 5 min", "agora"
String relativeTime(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d.toLocal());
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays < 7) return 'há ${diff.inDays} ${diff.inDays == 1 ? 'dia' : 'dias'}';
  if (diff.inDays < 30) {
    final w = diff.inDays ~/ 7;
    return 'há $w ${w == 1 ? 'semana' : 'semanas'}';
  }
  final m = diff.inDays ~/ 30;
  return 'há $m ${m == 1 ? 'mês' : 'meses'}';
}

/// 125 -> "02:05" ; 3725 -> "01:02:05"
String clock(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Sempre HH:MM:SS (cronômetro do serviço): 2705 -> "00:45:05"
String clockHms(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  return '${two(total ~/ 3600)}:${two((total % 3600) ~/ 60)}:${two(total % 60)}';
}

/// Distância em km (haversine).
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}
String distanceLabel(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

String firstName(String full) => full.trim().split(RegExp(r'\s+')).first;

String initials(String full) {
  final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
