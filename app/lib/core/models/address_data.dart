/// Endereço estruturado (puro, sem dependência de Flutter) usado no cadastro do
/// cliente, na edição de localização e nos pedidos.
library;

class AddressData {
  const AddressData({
    this.cep = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.uf = '',
    this.reference = '',
    this.latitude,
    this.longitude,
  });

  final String cep;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String uf;
  final String reference;
  final double? latitude;
  final double? longitude;

  /// "Rua Augusta, 1400, Apto 42 - Consolação, São Paulo - SP"
  String get fullLine {
    final first = [street, number, if (complement.isNotEmpty) complement].where((s) => s.isNotEmpty).join(', ');
    final second = [neighborhood, if (city.isNotEmpty) uf.isNotEmpty ? '$city - $uf' : city]
        .where((s) => s.isNotEmpty)
        .join(', ');
    return [first, second].where((s) => s.isNotEmpty).join(' - ');
  }

  /// Resumo público (bairro/cidade), sem rua nem número.
  String get summary => [neighborhood, if (city.isNotEmpty) uf.isNotEmpty ? '$city - $uf' : city]
      .where((s) => s.isNotEmpty)
      .join(', ');

  /// Cidade/UF para a coluna `address_city`.
  String get cityUf => city.isEmpty ? '' : (uf.isEmpty ? city : '$city - $uf');

  bool get isValid => street.trim().isNotEmpty && number.trim().isNotEmpty && neighborhood.trim().isNotEmpty && city.trim().isNotEmpty;

  /// Nenhum campo preenchido (rascunho vazio).
  bool get isEmpty =>
      cep.isEmpty && street.isEmpty && number.isEmpty && complement.isEmpty && neighborhood.isEmpty && city.isEmpty && uf.isEmpty && reference.isEmpty;

  /// Completa campos vazios com os de [other] (não sobrescreve o que já existe).
  AddressData fillBlanksFrom(AddressData other) => AddressData(
        cep: cep.isNotEmpty ? cep : other.cep,
        street: street.isNotEmpty ? street : other.street,
        number: number.isNotEmpty ? number : other.number,
        complement: complement.isNotEmpty ? complement : other.complement,
        neighborhood: neighborhood.isNotEmpty ? neighborhood : other.neighborhood,
        city: city.isNotEmpty ? city : other.city,
        uf: uf.isNotEmpty ? uf : other.uf,
        reference: reference.isNotEmpty ? reference : other.reference,
        latitude: latitude ?? other.latitude,
        longitude: longitude ?? other.longitude,
      );

  Map<String, dynamic> toJson() => {
        'cep': cep,
        'street': street,
        'number': number,
        'complement': complement,
        'neighborhood': neighborhood,
        'city': city,
        'uf': uf,
        'reference': reference,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory AddressData.fromJson(Map<String, dynamic> m) => AddressData(
        cep: (m['cep'] as String?) ?? '',
        street: (m['street'] as String?) ?? '',
        number: (m['number'] as String?) ?? '',
        complement: (m['complement'] as String?) ?? '',
        neighborhood: (m['neighborhood'] as String?) ?? '',
        city: (m['city'] as String?) ?? '',
        uf: (m['uf'] as String?) ?? '',
        reference: (m['reference'] as String?) ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
      );
}
