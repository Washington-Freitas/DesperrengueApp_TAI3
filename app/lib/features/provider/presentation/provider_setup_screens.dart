import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/widgets.dart';
import 'provider_profile_screens.dart';
import '../../../core/ui/app_tokens.dart';

/// Cadastro inicial do PROFISSIONAL (após o KYC ser ativado):
/// 1) perfil (foto, bio, especialidades, preços) 2) portfólio 3) conclusão.
/// Substitui os 4 arquivos `profile_setup` que estavam vazios.
class ProviderSetupFlow extends StatefulWidget {
  const ProviderSetupFlow({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProviderSetupFlow> createState() => _ProviderSetupFlowState();
}

class _ProviderSetupFlowState extends State<ProviderSetupFlow> {
  int _step = 0;
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ProfileService().completeSetup(UserMode.provider);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 0:
        return EditProviderProfileScreen(setupMode: true, onDone: () => setState(() => _step = 1));
      case 1:
        return PortfolioScreen(setupMode: true, onDone: () => setState(() => _step = 2));
      default:
        return Scaffold(
          appBar: AppBar(automaticallyImplyLeading: false, title: const BrandLogo()),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const StepperBar(total: 3, current: 3),
              const SizedBox(height: 28),
              Center(child: CircleAvatar(radius: 52, backgroundColor: context.tk.successSoft, child: Icon(Icons.rocket_launch_rounded, size: 50, color: context.tk.success))),
              const SizedBox(height: 20),
              Text('Tudo pronto, ${widget.profile.firstName}!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                'Seu perfil está no ar. Agora você recebe solicitações de clientes da sua região e pode enviar orçamentos.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.45, color: context.tk.textMuted),
              ),
              const SizedBox(height: 22),
              const InfoBanner(
                'Você pode editar foto, bio, especialidades e portfólio quando quiser, em Perfil.',
                tone: BannerTone.info,
              ),
              const SizedBox(height: 10),
              const InfoBanner(
                'Também pode usar o app como cliente a qualquer momento: basta trocar de modo na tela inicial.',
                tone: BannerTone.promo,
                icon: Icons.swap_horiz_rounded,
              ),
            ],
          ),
          bottomNavigationBar: BottomBar(
            child: PrimaryButton(label: 'Ir para o meu painel', trailingArrow: true, loading: _saving, onPressed: _finish),
          ),
        );
    }
  }
}
