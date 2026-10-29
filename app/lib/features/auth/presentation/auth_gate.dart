import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'post_auth_router.dart';

/// Raiz de navegação do app.
///
/// - Sem sessão  -> [LoginScreen].
/// - Com sessão  -> [PostAuthRouter] (decide a tela pelo estado do servidor).
///
/// Reage a login/logout (inclusive OAuth Google, que retorna por deep link) e
/// ao deep link `desperrengue://onboarding/...` do e-mail de aprovação. O link
/// NÃO carrega credencial: ele só faz o app reconsultar o status no servidor.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _client = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _linkSub;

  String? _userId;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _userId = _client.auth.currentUser?.id;

    _authSub = _client.auth.onAuthStateChange.listen((state) {
      final newId = state.session?.user.id;
      if (!mounted || newId == _userId) return; // ignora refresh de token
      setState(() {
        _userId = newId;
        _refreshTick++;
      });
    });

    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _onLink(initial);
    } catch (e) {
      debugPrint('Erro ao ler o link inicial: $e');
    }
    _linkSub = appLinks.uriLinkStream.listen(_onLink);
  }

  void _onLink(Uri uri) {
    final isOnboarding =
        uri.scheme == 'desperrengue' && uri.host == 'onboarding';
    if (isOnboarding && mounted) {
      setState(() => _refreshTick++);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const LoginScreen();
    return PostAuthRouter(key: ValueKey('$_userId-$_refreshTick'));
  }
}
