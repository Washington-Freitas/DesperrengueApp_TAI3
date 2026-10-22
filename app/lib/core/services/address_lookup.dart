import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/address_data.dart';

/// Consulta de endereço por CEP e por coordenadas (GPS).
///
/// Só usa serviços públicos GRATUITOS e SEM CHAVE/CADASTRO:
///  * ViaCEP (principal) e BrasilAPI (reserva) para CEP -> endereço;
///  * OpenStreetMap Nominatim para coordenadas -> endereço.
/// Os parsers são funções puras para serem testados sem rede.
class AddressLookup {
  AddressLookup([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  /// Política de uso do Nominatim exige um User-Agent identificável.
  static const _headers = {
    'User-Agent': 'DesperrengueApp/0.1 (suporte@desperrengue.tech)',
    'Accept': 'application/json',
  };

  /// CEP -> endereço (ViaCEP; se falhar/estiver fora do ar, BrasilAPI).
  Future<AddressData?> byCep(String cep) async {
    final digits = onlyDigits(cep);
    if (digits.length != 8) return null;
    final viaCep = await _getJson('https://viacep.com.br/ws/$digits/json/');
    final a = viaCep == null ? null : parseViaCep(viaCep, digits);
    if (a != null) return a;
    final brasil = await _getJson('https://brasilapi.com.br/api/cep/v2/$digits');
    return brasil == null ? null : parseBrasilApi(brasil, digits);
  }

  /// Coordenadas -> endereço (rua, bairro, cidade, UF e CEP). O NÚMERO fica em
  /// branco de propósito: o usuário confirma manualmente.
  Future<AddressData?> byCoordinates(double lat, double lng) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': lat.toString(),
      'lon': lng.toString(),
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'pt-BR',
    });
    final json = await _getJson(uri.toString(), headers: _headers);
    if (json == null) return null;
    var found = parseNominatim(json, lat, lng);
    if (found == null) return null;
    // Refina com o CEP (ViaCEP é mais fiel à nomenclatura dos Correios).
    if (found.cep.length == 8) {
      final byZip = await byCep(found.cep);
      if (byZip != null) {
        found = AddressData(
          cep: found.cep,
          street: byZip.street.isNotEmpty ? byZip.street : found.street,
          neighborhood: byZip.neighborhood.isNotEmpty ? byZip.neighborhood : found.neighborhood,
          city: byZip.city.isNotEmpty ? byZip.city : found.city,
          uf: byZip.uf.isNotEmpty ? byZip.uf : found.uf,
          latitude: lat,
          longitude: lng,
        );
      }
    }
    return found;
  }

  Future<Map<String, dynamic>?> _getJson(String url, {Map<String, String>? headers}) async {
    try {
      final res = await _client.get(Uri.parse(url), headers: headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ parsers

  static String onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Resposta do ViaCEP. Devolve null para `{"erro": true}`.
  static AddressData? parseViaCep(Map<String, dynamic> m, String cep) {
    if (m['erro'] == true || m['erro'] == 'true') return null;
    return AddressData(
      cep: onlyDigits(cep),
      street: ((m['logradouro'] as String?) ?? '').trim(),
      complement: '',
      neighborhood: ((m['bairro'] as String?) ?? '').trim(),
      city: ((m['localidade'] as String?) ?? '').trim(),
      uf: ((m['uf'] as String?) ?? '').trim().toUpperCase(),
    );
  }

  /// Resposta da BrasilAPI v2 (inclui coordenadas quando disponíveis).
  static AddressData? parseBrasilApi(Map<String, dynamic> m, String cep) {
    final city = ((m['city'] as String?) ?? '').trim();
    if (city.isEmpty) return null;
    double? lat;
    double? lng;
    final coords = (m['location'] as Map<String, dynamic>?)?['coordinates'] as Map<String, dynamic>?;
    if (coords != null) {
      lat = double.tryParse('${coords['latitude'] ?? ''}');
      lng = double.tryParse('${coords['longitude'] ?? ''}');
    }
    return AddressData(
      cep: onlyDigits(cep),
      street: ((m['street'] as String?) ?? '').trim(),
      neighborhood: ((m['neighborhood'] as String?) ?? '').trim(),
      city: city,
      uf: ((m['state'] as String?) ?? '').trim().toUpperCase(),
      latitude: lat,
      longitude: lng,
    );
  }

  /// Resposta do Nominatim (`/reverse?format=jsonv2&addressdetails=1`).
  static AddressData? parseNominatim(Map<String, dynamic> m, double lat, double lng) {
    final a = m['address'];
    if (a is! Map<String, dynamic>) return null;
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final city = pick(['city', 'town', 'village', 'municipality', 'city_district', 'county']);
    final street = pick(['road', 'pedestrian', 'residential', 'footway', 'path']);
    final neighborhood = pick(['suburb', 'neighbourhood', 'quarter', 'city_district', 'borough']);
    if (street.isEmpty && city.isEmpty) return null;

    var uf = '';
    final iso = a['ISO3166-2-lvl4'] ?? a['ISO3166-2-lvl3'];
    if (iso is String && iso.contains('-')) {
      uf = iso.split('-').last.toUpperCase();
    } else {
      uf = _ufByName[_fold(pick(['state', 'region']))] ?? '';
    }

    final zip = onlyDigits(pick(['postcode']));
    return AddressData(
      cep: zip.length == 8 ? zip : '',
      street: street,
      neighborhood: neighborhood == city ? '' : neighborhood,
      city: city,
      uf: uf.length <= 3 ? uf : '',
      latitude: lat,
      longitude: lng,
    );
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .trim();

  static const Map<String, String> _ufByName = {
    'acre': 'AC', 'alagoas': 'AL', 'amapa': 'AP', 'amazonas': 'AM', 'bahia': 'BA', 'ceara': 'CE',
    'distrito federal': 'DF', 'espirito santo': 'ES', 'goias': 'GO', 'maranhao': 'MA',
    'mato grosso': 'MT', 'mato grosso do sul': 'MS', 'minas gerais': 'MG', 'para': 'PA',
    'paraiba': 'PB', 'parana': 'PR', 'pernambuco': 'PE', 'piaui': 'PI', 'rio de janeiro': 'RJ',
    'rio grande do norte': 'RN', 'rio grande do sul': 'RS', 'rondonia': 'RO', 'roraima': 'RR',
    'santa catarina': 'SC', 'sao paulo': 'SP', 'sergipe': 'SE', 'tocantins': 'TO',
  };
}
