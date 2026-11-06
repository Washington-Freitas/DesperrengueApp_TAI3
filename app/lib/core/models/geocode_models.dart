/// Geocodificação de endereço (Nominatim/OSM) em Dart puro: montagem das consultas e parse.
///
/// O app do CLIENTE geocodifica no próprio celular (o Nominatim público bloqueia IPs de
/// datacenter, então não dá para fazer no servidor) e registra o ponto com a qualidade
/// (`house`/`street`/`locality`) via `set_job_location`. A qualidade define o raio do geofence.
library;

import 'scheduling_models.dart';

/// Partes do endereço "Rua X, 203 - Bairro, Cidade - MG".
class AddressParts {
  const AddressParts({required this.street, required this.number, required this.hood, required this.city, required this.uf});
  final String street;
  final String number;
  final String hood;
  final String city;
  final String uf;
}

AddressParts parseAddressLine(String line, {String? summary}) {
  final parts = line.split(' - ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final first = parts.isNotEmpty ? parts.first : line.trim();
  final streetBits = first.split(',').map((s) => s.trim()).toList();
  final street = streetBits.first;
  final number = RegExp(r'\d+').firstMatch(streetBits.length > 1 ? streetBits[1] : '')?.group(0) ?? '';

  var place = parts.length > 1 ? parts[1] : '';
  var uf = parts.length > 2 ? parts[2] : '';
  if (place.isEmpty && summary != null) {
    // Sem "Bairro, Cidade" na linha: usa o resumo público ("Bairro, Cidade - UF").
    final s = summary.split(' - ').map((x) => x.trim()).toList();
    place = s.first;
    if (uf.isEmpty && s.length > 1) uf = s[1];
  }
  final placeBits = place.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final city = placeBits.length > 1 ? placeBits.last : (placeBits.isNotEmpty ? placeBits.first : '');
  final hood = placeBits.length > 1 ? placeBits.first : '';
  return AddressParts(street: street, number: number, hood: hood, city: city, uf: uf);
}

/// Consultas do mais específico (rua + número) ao menos (só a cidade), sem repetição.
List<String> buildGeocodeQueries(AddressParts a) {
  final tail = [a.city, a.uf, 'Brasil'].where((s) => s.isNotEmpty).join(', ');
  final hood = a.hood.isEmpty ? '' : '${a.hood}, ';
  final out = <String>[
    if (a.number.isNotEmpty) '${a.street} ${a.number}, $hood$tail',
    '${a.street}, $hood$tail',
    if (a.hood.isNotEmpty) '${a.hood}, $tail',
    if (a.city.isNotEmpty) tail,
  ];
  return out.toSet().toList();
}

class GeocodeHit {
  const GeocodeHit({required this.lat, required this.lng, required this.precision, this.display = ''});
  final double lat;
  final double lng;
  final DestinationPrecision precision;
  final String display;
}

/// Resposta do Nominatim `/search?format=jsonv2&addressdetails=1&limit=1`.
GeocodeHit? parseNominatimSearch(Object? body) {
  if (body is! List || body.isEmpty || body.first is! Map) return null;
  final r = (body.first as Map).cast<String, dynamic>();
  final lat = double.tryParse('${r['lat'] ?? ''}');
  final lng = double.tryParse('${r['lon'] ?? ''}');
  if (lat == null || lng == null) return null;
  final addr = (r['address'] as Map?)?.cast<String, dynamic>() ?? const {};
  final type = '${r['addresstype'] ?? ''}';
  DestinationPrecision p;
  if (addr['house_number'] != null) {
    p = DestinationPrecision.house;
  } else if (r['class'] == 'highway' || const ['road', 'residential', 'pedestrian', 'footway', 'path', 'street'].contains(type)) {
    p = DestinationPrecision.street;
  } else {
    p = DestinationPrecision.locality;
  }
  return GeocodeHit(lat: lat, lng: lng, precision: p, display: '${r['display_name'] ?? ''}');
}
