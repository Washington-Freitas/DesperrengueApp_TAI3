import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/widgets.dart';
import '../../client/presentation/client_setup_screen.dart';
import '../../client/presentation/client_shell.dart';
import '../../home/presentation/home_screens.dart';
import '../../provider/presentation/provider_setup_screens.dart';
import '../../provider/presentation/provider_shell.dart';
import 'auth_gate.dart';
import 'role_selection_screen.dart';
import 'verificacao_step1_frente.dart';
import 'verificacao_step6_feedback.dart';
import 'verificacao_step7_aprovado.dart';

/// Carrega o perfil do usuário autenticado e mostra a tela correta
/// (ver [destinationFor]), considerando o MODO escolhido na sessão
/// (o mesmo usuário pode ser cliente e profissional).
class PostAuthRouter extends StatefulWidget {
  const PostAuthRouter({super.key});

  @override
  State<PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends State<PostAuthRouter> {
  final _session = AppSession.instance;
  UserProfile? _profile;
  UserMode? _preferred;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _session.profileTick.addListener(_load);
  }

  @override
  void dispose() {
    _session.profileTick.removeListener(_load);
    super.dispose();
  }

  /// Recarrega o perfil sem apagar a tela atual (evita "piscar" a navegação).
  /// Offline-first: sem rede, abre com a última versão salva (se houver).
  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final preferred = uid == null ? null : await LocalPrefs.lastProfile(uid);
    UserProfile? p;
    try {
      p = await ProfileService().fetchCurrent();
    } catch (e) {
      p = await ProfileService().cachedProfile();
    }
    if (!mounted) return;
    setState(() {
      _profile = p;
      _preferred = preferred;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await ProfileService().signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      if (_loading) return const Scaffold(body: LoadingView());
      return Scaffold(
        body: ErrorView(
          message: 'Não foi possível carregar o seu perfil.\nVerifique a conexão e tente novamente.',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
        bottomNavigationBar: SafeArea(
          child: TextButton(onPressed: _signOut, child: const Text('Sair da conta')),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([_session.mode, _session.forceSelection]),
      builder: (context, _) {
        final dest = destinationFor(
          profile,
          mode: _session.mode.value,
          forceSelection: _session.forceSelection.value,
          preferred: _preferred,
        );
        return _screenFor(dest, profile);
      },
    );
  }
  Widget _screenFor(AppDestination dest, UserProfile profile) {
    // Sincroniza o tema do MaterialApp com o modo da tela atual.
    final wanted = switch (dest) {
      AppDestination.clientSetup || AppDestination.clientHome => UserMode.client,
      AppDestination.providerSetup || AppDestination.providerHome => UserMode.provider,
      _ => null,
    };
    if (_session.theme.value != wanted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _session.theme.value = wanted);
    }
    switch (dest) {
      case AppDestination.modeSelection:
        return RoleSelectionScreen(profile: profile);
      case AppDestination.clientEnroll:
        return _EnrollRunner(mode: UserMode.client, key: const ValueKey('enroll-client'));
      case AppDestination.providerEnroll:
        return _EnrollRunner(mode: UserMode.provider, key: const ValueKey('enroll-provider'));
      case AppDestination.clientSetup:
        return _themed(UserMode.client, ClientSetupScreen(profile: profile));
      case AppDestination.clientHome:
        return _themed(UserMode.client, ClientShell(profile: profile));
      case AppDestination.kycStart:
        return const VerificacaoStep1FrenteScreen();
      case AppDestination.kycInReview:
        return const VerificacaoStep6FeedbackScreen();
      case AppDestination.kycApproved:
        return VerificacaoStep7AprovadoScreen(nomeProfissional: profile.firstName);
      case AppDestination.providerSetup:
        return _themed(UserMode.provider, ProviderSetupFlow(profile: profile));
      case AppDestination.providerHome:
        return _themed(UserMode.provider, ProviderShell(profile: profile));
      case AppDestination.adminHome:
        return const HomeAdminScreen();
    }
  }

  Widget _themed(UserMode mode, Widget child) =>
      Theme(data: AppTheme.resolve(mode, Theme.of(context).brightness), child: child);
}

/// Cadastra o usuário no modo escolhido e recarrega o perfil.
class _EnrollRunner extends StatefulWidget {
  const _EnrollRunner({super.key, required this.mode});

  final UserMode mode;

  @override
  State<_EnrollRunner> createState() => _EnrollRunnerState();
}

class _EnrollRunnerState extends State<_EnrollRunner> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      await ProfileService().enrollMode(widget.mode);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: ErrorView(message: _error!, onRetry: _run),
        bottomNavigationBar: SafeArea(
          child: TextButton(
            onPressed: AppSession.instance.switchMode,
            child: const Text('Voltar'),
          ),
        ),
      );
    }
    return const Scaffold(body: LoadingView(message: 'Preparando sua conta...'));
  }
}
