import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/widgets.dart';

/// Endereço estruturado digitado pelo usuário.
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
}

/// Consulta o CEP no ViaCEP (API pública, sem chave). Devolve null se não achar.
Future<AddressData?> lookupCep(String cep) async {
  final digits = cep.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;
  try {
    final res = await http.get(Uri.parse('https://viacep.com.br/ws/$digits/json/')).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (m['erro'] == true) return null;
    return AddressData(
      cep: digits,
      street: (m['logradouro'] as String?) ?? '',
      neighborhood: (m['bairro'] as String?) ?? '',
      city: (m['localidade'] as String?) ?? '',
      uf: (m['uf'] as String?) ?? '',
    );
  } catch (_) {
    return null;
  }
}

/// Formulário de endereço (CEP + GPS), compartilhado entre cadastro e edição.
class AddressForm extends StatefulWidget {
  const AddressForm({super.key, required this.onChanged, this.initial});

  final ValueChanged<AddressData> onChanged;
  final AddressData? initial;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final TextEditingController _cep;
  late final TextEditingController _street;
  late final TextEditingController _number;
  late final TextEditingController _complement;
  late final TextEditingController _neighborhood;
  late final TextEditingController _city;
  late final TextEditingController _uf;
  late final TextEditingController _reference;
  double? _lat;
  double? _lng;
  bool _loadingCep = false;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    final a = widget.initial ?? const AddressData();
    _cep = TextEditingController(text: a.cep);
    _street = TextEditingController(text: a.street);
    _number = TextEditingController(text: a.number);
    _complement = TextEditingController(text: a.complement);
    _neighborhood = TextEditingController(text: a.neighborhood);
    _city = TextEditingController(text: a.city);
    _uf = TextEditingController(text: a.uf);
    _reference = TextEditingController(text: a.reference);
    _lat = a.latitude;
    _lng = a.longitude;
    for (final c in [_cep, _street, _number, _complement, _neighborhood, _city, _uf, _reference]) {
      c.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final c in [_cep, _street, _number, _complement, _neighborhood, _city, _uf, _reference]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(AddressData(
    cep: _cep.text,
    street: _street.text.trim(),
    number: _number.text.trim(),
    complement: _complement.text.trim(),
    neighborhood: _neighborhood.text.trim(),
    city: _city.text.trim(),
    uf: _uf.text.trim().toUpperCase(),
    reference: _reference.text.trim(),
    latitude: _lat,
    longitude: _lng,
  ));

  Future<void> _searchCep() async {
    setState(() => _loadingCep = true);
    final found = await lookupCep(_cep.text);
    if (!mounted) return;
    setState(() => _loadingCep = false);
    if (found == null) {
      showSnack(context, 'CEP não encontrado. Preencha o endereço manualmente.', error: true);
      return;
    }
    _street.text = found.street;
    _neighborhood.text = found.neighborhood;
    _city.text = found.city;
    _uf.text = found.uf;
    _emit();
  }

  Future<void> _useGps() async {
    setState(() => _loadingGps = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showSnack(context, 'Permissão de localização negada.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;
      _emit();
      if (mounted) showSnack(context, 'Localização capturada! Complete o endereço abaixo.');
    } catch (_) {
      if (mounted) showSnack(context, 'Não foi possível obter a localização.', error: true);
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Acesso rápido'),
        OutlinedButton.icon(
          onPressed: _loadingGps ? null : _useGps,
          icon: _loadingGps
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location_rounded),
          label: Text(_lat != null ? 'Localização capturada ✓' : 'Usar minha localização atual'),
        ),
        const SizedBox(height: 18),
        const Center(child: Text('Ou digite o endereço abaixo', style: TextStyle(color: AppColors.muted))),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _cep,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                decoration: const InputDecoration(labelText: 'CEP', hintText: '00000000'),
                onSubmitted: (_) => _searchCep(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              width: 56,
              child: IconButton.filledTonal(
                onPressed: _loadingCep ? null : _searchCep,
                style: IconButton.styleFrom(backgroundColor: accent.withValues(alpha: 0.12), foregroundColor: accent),
                icon: _loadingCep
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _street, decoration: const InputDecoration(labelText: 'Rua / Avenida (obrigatório)')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _number,
                decoration: const InputDecoration(labelText: 'Número (obrigatório)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _complement, decoration: const InputDecoration(labelText: 'Complemento')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _neighborhood, decoration: const InputDecoration(labelText: 'Bairro (obrigatório)')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'Cidade (obrigatório)')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _uf,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(2)],
                decoration: const InputDecoration(labelText: 'UF'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ponto de referência / instruções de acesso (opcional)',
            hintText: 'Ex: portão de madeira ao lado da padaria; avise o porteiro.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
