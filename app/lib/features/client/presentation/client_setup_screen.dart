import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/widgets.dart';
import 'address_form.dart';

/// Salva o endereço no perfil (colunas liberadas por GRANT) e sincroniza.
Future<void> saveProfileAddress(AddressData a) async {
  final line = a.reference.isEmpty ? a.fullLine : '${a.fullLine} | Ref: ${a.reference}';
  await ProfileService().updateProfile({
    'address_line': line,
    'address_city': a.cityUf,
    'latitude': ?a.latitude,
    'longitude': ?a.longitude,
  });
  AppSession.instance.refreshProfile();
}

/// "Editar Localização" (protótipo 14.jpg).
class EditAddressScreen extends StatefulWidget {
  const EditAddressScreen({super.key, this.currentLine});

  final String? currentLine;

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  AddressData _address = const AddressData();
  bool _saving = false;

  Future<void> _save() async {
    if (!_address.isValid) {
      showSnack(context, 'Preencha rua, número, bairro e cidade.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await saveProfileAddress(_address);
      if (mounted) Navigator.pop(context, _address);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar localização')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.currentLine != null && widget.currentLine!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBanner(widget.currentLine!, title: 'Endereço atual', icon: Icons.place_outlined),
              ),
            AddressForm(onChanged: (a) => _address = a),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Salvar endereço', onPressed: _save, loading: _saving),
      ),
    );
  }
}

/// Cadastro inicial do CLIENTE: nome/telefone e endereço (substitui o fluxo
/// "profile_setup" vazio). Ao concluir chama `complete_setup('client')`.
class ClientSetupScreen extends StatefulWidget {
  const ClientSetupScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ClientSetupScreen> createState() => _ClientSetupScreenState();
}

class _ClientSetupScreenState extends State<ClientSetupScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.profile.fullName);
  final _phone = TextEditingController();
  AddressData _address = const AddressData();
  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_address.isValid) {
      showSnack(context, 'Preencha rua, número, bairro e cidade.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ProfileService();
      await service.updateProfile({
        'full_name': _name.text.trim().isEmpty ? widget.profile.fullName : _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      });
      final line = _address.reference.isEmpty ? _address.fullLine : '${_address.fullLine} | Ref: ${_address.reference}';
      await service.updateProfile({
        'address_line': line,
        'address_city': _address.cityUf,
        'latitude': ?_address.latitude,
        'longitude': ?_address.longitude,
      });
      await service.completeSetup(UserMode.client);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          setState(() => _step = 0);
        } else {
          AppSession.instance.switchMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => _step > 0 ? setState(() => _step = 0) : AppSession.instance.switchMode(),
          ),
          title: const BrandLogo(),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepperBar(total: 2, current: _step + 1),
              const SizedBox(height: 18),
              if (_step == 0) ...[
                Text('Bem-vindo, ${widget.profile.firstName}!',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Vamos configurar sua conta de cliente para você pedir serviços em minutos.',
                    style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Como podemos te chamar?', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone (opcional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText: 'Usado só para avisos do pedido.',
                  ),
                ),
              ] else ...[
                const Text('Onde você precisa do serviço?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('O endereço completo só é compartilhado com o profissional contratado.',
                    style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
                const SizedBox(height: 8),
                AddressForm(onChanged: (a) => _address = a),
              ],
            ],
          ),
        ),
        bottomNavigationBar: BottomBar(
          child: _step == 0
              ? PrimaryButton(
                  label: 'Continuar',
                  trailingArrow: true,
                  onPressed: () {
                    if (_name.text.trim().length < 2) {
                      showSnack(context, 'Informe seu nome.', error: true);
                      return;
                    }
                    setState(() => _step = 1);
                  },
                )
              : PrimaryButton(label: 'Concluir e começar', onPressed: _finish, loading: _saving),
        ),
      ),
    );
  }
}
