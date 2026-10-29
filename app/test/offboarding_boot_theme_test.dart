import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/boot/app_initialization_service.dart';
import 'package:desperrengue_app/core/models/account_models.dart';
import 'package:desperrengue_app/core/models/showcase_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/provider_service.dart';
import 'package:desperrengue_app/core/state/privacy_mode.dart';
import 'package:desperrengue_app/core/state/theme_controller.dart';
import 'package:desperrengue_app/core/storage/local_prefs.dart';
import 'package:desperrengue_app/core/storage/secure_session_storage.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/features/auth/presentation/role_selection_screen.dart';
import 'package:desperrengue_app/features/boot/animated_splash_screen.dart';

UserProfile profile({bool client = false, bool provider = false, bool clientDone = false, bool providerDone = false, String ver = 'ACTIVE', String? last}) =>
    UserProfile.fromMap({
      'id': 'u1',
      'full_name': 'Ana Souza',
      'role': null,
      'is_client': client,
      'is_provider': provider,
      'client_setup_done': clientDone,
      'provider_setup_done': providerDone,
      'last_mode': last,
      'verification_status': ver,
    });

void main() {
  group('Design tokens (WCAG)', () {
    test('modo escuro usa fundo #121212 e sem sombra', () {
      expect(AppTokens.dark.background, const Color(0xFF121212));
      expect(AppTokens.dark.cardShadow(), isEmpty);
      expect(AppTokens.light.cardShadow(), isNotEmpty);
    });

    test('elevação tonal: quanto mais alto o nível, mais clara a superfície', () {
      final d = AppTokens.dark;
      final l = [d.background, d.surface, d.card, d.raised].map((c) => c.computeLuminance()).toList();
      for (var i = 1; i < l.length; i++) {
        expect(l[i], greaterThan(l[i - 1]), reason: 'nível $i deveria ser mais claro que ${i - 1}');
      }
      expect(AppTokens.tonal(const Color(0xFF121212), 0), const Color(0xFF121212));
    });

    for (final tk in [AppTokens.light, AppTokens.dark]) {
      final n = tk.isDark ? 'escuro' : 'claro';
      test('contraste do texto ≥ 4,5:1 ($n)', () {
        for (final bg in [tk.background, tk.surface, tk.card, tk.raised]) {
          expect(AppTokens.contrast(tk.text, bg), greaterThanOrEqualTo(4.5), reason: 'text sobre $bg');
          expect(AppTokens.contrast(tk.textMuted, bg), greaterThanOrEqualTo(4.5), reason: 'textMuted sobre $bg');
        }
      });
      test('acentos e estados legíveis (≥ 3:1) sobre o fundo e o cartão ($n)', () {
        final accents = {
          'providerAccent': tk.providerAccent,
          'clientAccent': tk.clientAccent,
          'brand': tk.brand,
          'danger': tk.danger,
          'info': tk.info,
          'security': tk.security,
          'successInk': tk.successInk,
          'warningInk': tk.warningInk,
        };
        accents.forEach((name, c) {
          expect(AppTokens.contrast(c, tk.background), greaterThanOrEqualTo(3.0), reason: '$name/background');
          expect(AppTokens.contrast(c, tk.card), greaterThanOrEqualTo(3.0), reason: '$name/card');
        });
      });
      test('texto de estado sobre o fundo suave correspondente ≥ 4,5:1 ($n)', () {
        expect(AppTokens.contrast(tk.successInk, tk.successSoft), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(tk.warningInk, tk.warningSoft), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(tk.text, tk.dangerSoft), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(tk.text, tk.infoSoft), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(tk.text, tk.clientSoft), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(tk.text, tk.providerSoft), greaterThanOrEqualTo(4.5));
      });
    }

    test('desaturate: mantém o matiz, reduz a saturação e clareia (anti-halation)', () {
      const vivid = Color(0xFFF26B0F);
      final out = AppTokens.desaturate(vivid);
      final a = HSLColor.fromColor(vivid);
      final b = HSLColor.fromColor(out);
      expect(b.hue, closeTo(a.hue, 1.5));
      expect(b.saturation, lessThan(a.saturation));
      expect(b.lightness, greaterThanOrEqualTo(a.lightness));
    });

    test('onColor escolhe o texto com mais contraste', () {
      expect(AppTokens.onColor(const Color(0xFF1B3A78)), Colors.white);
      expect(AppTokens.onColor(const Color(0xFFF2C14E)), isNot(Colors.white));
    });

    test('os mesmos tokens existem nos dois temas e o lerp não quebra', () {
      final mid = AppTokens.light.lerp(AppTokens.dark, 0.5);
      expect(mid.background, isNot(AppTokens.light.background));
      expect(AppTokens.light.lerp(null, .5), AppTokens.light);
    });
  });

  group('AppTheme', () {
    test('resolve devolve tema claro/escuro por modo, com cache', () {
      final dark = AppTheme.resolve(UserMode.provider, Brightness.dark);
      final light = AppTheme.resolve(UserMode.provider, Brightness.light);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF121212));
      expect(light.scaffoldBackgroundColor, Colors.white);
      expect(dark.extension<AppTokens>()!.isDark, isTrue);
      expect(identical(dark, AppTheme.resolve(UserMode.provider, Brightness.dark)), isTrue);
    });

    test('no escuro o acento do botão vem do token dessaturado (não da constante)', () {
      final dark = AppTheme.resolve(UserMode.client, Brightness.dark);
      expect(dark.colorScheme.primary, AppTokens.dark.clientAccent);
      expect(dark.colorScheme.primary, isNot(AppColors.clientAccent));
    });

    testWidgets('context.tk lê o tema ativo (themeMode dark)', (tester) async {
      late AppTokens seen;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.light),
        darkTheme: AppTheme.resolve(null, Brightness.dark),
        themeMode: ThemeMode.dark,
        home: Builder(builder: (c) {
          seen = c.tk;
          return const SizedBox();
        }),
      ));
      expect(seen.isDark, isTrue);
      expect(seen.background, const Color(0xFF121212));
    });
  });

  group('Tri-state do tema (persistido)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('parse com fallback seguro', () {
      expect(AppThemeMode.parse('dark'), AppThemeMode.dark);
      expect(AppThemeMode.parse('light'), AppThemeMode.light);
      expect(AppThemeMode.parse('lixo'), AppThemeMode.system);
      expect(AppThemeMode.parse(null), AppThemeMode.system);
      expect(AppThemeMode.dark.material, ThemeMode.dark);
    });

    test('select grava no cache e hydrate não regrava', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(themeModeProvider), AppThemeMode.system);
      await c.read(themeModeProvider.notifier).select(AppThemeMode.dark);
      expect(c.read(themeModeProvider), AppThemeMode.dark);
      expect(await LocalPrefs.read(LocalPrefs.keyTheme), 'dark');

      c.read(themeModeProvider.notifier).hydrate(AppThemeMode.light);
      expect(c.read(themeModeProvider), AppThemeMode.light);
      expect(await LocalPrefs.read(LocalPrefs.keyTheme), 'dark');
    });
  });

  group('Último perfil usado (por conta)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('codifica/decodifica e ignora outra conta ou lixo', () {
      final raw = LocalPrefs.encodeLastProfile('u1', UserMode.provider);
      expect(LocalPrefs.decodeLastProfile(raw, 'u1'), UserMode.provider);
      expect(LocalPrefs.decodeLastProfile(raw, 'u2'), isNull);
      expect(LocalPrefs.decodeLastProfile('sem-dois-pontos', 'u1'), isNull);
      expect(LocalPrefs.decodeLastProfile('u1:xxx', 'u1'), isNull);
      expect(LocalPrefs.decodeLastProfile(null, 'u1'), isNull);
    });

    test('persiste e recupera', () async {
      await LocalPrefs.saveLastProfile('u1', UserMode.client);
      expect(await LocalPrefs.lastProfile('u1'), UserMode.client);
      expect(await LocalPrefs.lastProfile('u9'), isNull);
    });

    test('roteamento: dois perfis prontos + último perfil abre direto nele', () {
      final p = profile(client: true, provider: true, clientDone: true, providerDone: true);
      expect(destinationFor(p), AppDestination.modeSelection, reason: 'sem preferência, escolhe');
      expect(destinationFor(p, preferred: UserMode.client), AppDestination.clientHome);
      expect(destinationFor(p, preferred: UserMode.provider), AppDestination.providerHome);
      expect(destinationFor(p, preferred: UserMode.client, forceSelection: true), AppDestination.modeSelection, reason: 'Trocar de modo');
      expect(destinationFor(p, mode: UserMode.provider, preferred: UserMode.client), AppDestination.providerHome, reason: 'escolha da sessão vence');
    });

    test('roteamento: preferência só vale se aquele perfil estiver pronto', () {
      final p = profile(client: true, provider: true, clientDone: false, providerDone: true);
      expect(destinationFor(p, preferred: UserMode.client), AppDestination.modeSelection, reason: 'cadastro de cliente incompleto');
      final novo = profile();
      expect(destinationFor(novo, preferred: UserMode.provider), AppDestination.modeSelection, reason: 'primeiro acesso sempre escolhe');
    });
  });

  group('AppInitializationService (Future.wait + fallback)', () {
    AppInitializationService svc({
      Future<void> Function()? warm,
      Future<void> Function()? init,
      Future<void> Function()? wipe,
      Future<AppThemeMode> Function()? theme,
    }) =>
        AppInitializationService(
          warmUp: warm ?? () async {},
          initBackend: init ?? () async {},
          wipeSecureStorage: wipe ?? () async {},
          readTheme: theme ?? () async => AppThemeMode.dark,
        );

    test('caminho feliz devolve o tema salvo', () async {
      final r = await svc().run();
      expect(r.backendReady, isTrue);
      expect(r.recoveredFromCorruption, isFalse);
      expect(r.theme, AppThemeMode.dark);
    });

    test('as 3 tarefas rodam em PARALELO (tempo ≈ a mais lenta, não a soma)', () async {
      Future<void> slow() => Future<void>.delayed(const Duration(milliseconds: 150));
      final sw = Stopwatch()..start();
      await svc(warm: slow, init: slow, theme: () async {
        await slow();
        return AppThemeMode.light;
      }).run();
      expect(sw.elapsedMilliseconds, lessThan(330), reason: 'sequencial levaria ≥ 450 ms');
    });

    test('armazenamento corrompido: limpa, tenta de novo e segue (cai no Login)', () async {
      var calls = 0;
      var wiped = false;
      final r = await svc(
        init: () async {
          calls++;
          if (calls == 1) throw StateError('json corrompido');
        },
        wipe: () async => wiped = true,
      ).run();
      expect(wiped, isTrue);
      expect(calls, 2);
      expect(r.backendReady, isTrue);
      expect(r.recoveredFromCorruption, isTrue);
    });

    test('falha persistente vira backendReady=false (tela de "tentar novamente"), sem exceção', () async {
      final r = await svc(init: () async => throw StateError('x'), wipe: () async => throw StateError('y')).run();
      expect(r.backendReady, isFalse);
    });

    test('falha no warm-up ou no tema é ignorada', () async {
      final r = await svc(warm: () async => throw StateError('asset'), theme: () async => throw StateError('prefs')).run();
      expect(r.backendReady, isTrue);
      expect(r.theme, AppThemeMode.system);
    });
  });

  group('Sessão no armazenamento seguro', () {
    const key = 'sb-abc-auth-token';
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      SharedPreferences.setMockInitialValues({});
    });

    test('keyFor segue o padrão do supabase_flutter', () {
      expect(SecureSessionStorage.keyFor('https://eisfkemgooqbgqljvwvs.supabase.co'), 'sb-eisfkemgooqbgqljvwvs-auth-token');
    });

    test('persiste, lê e remove a sessão', () async {
      final s = SecureSessionStorage(persistSessionKey: key);
      await s.initialize();
      expect(await s.hasAccessToken(), isFalse);
      await s.persistSession('{"access_token":"a"}');
      expect(await s.hasAccessToken(), isTrue);
      expect(await s.accessToken(), '{"access_token":"a"}');
      await s.removePersistedSession();
      expect(await s.accessToken(), isNull);
    });

    test('sessão corrompida (JSON inválido) é descartada: devolve "sem sessão"', () async {
      FlutterSecureStorage.setMockInitialValues({key: '{quebrado'});
      final s = SecureSessionStorage(persistSessionKey: key);
      expect(await s.accessToken(), isNull);
      expect(await s.hasAccessToken(), isFalse);
    });

    test('migra a sessão antiga do SharedPreferences (ninguém precisa entrar de novo)', () async {
      SharedPreferences.setMockInitialValues({key: '{"access_token":"antigo"}'});
      final s = SecureSessionStorage(persistSessionKey: key);
      await s.initialize();
      expect(await s.accessToken(), '{"access_token":"antigo"}');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(key), isFalse, reason: 'o token não fica mais em texto puro');
    });
  });

  group('Modo privacidade', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('máscara R\$ ••••• quando oculto', () {
      expect(PrivacyMode.money('R\$ 1.234,00', hidden: true), 'R\$ •••••');
      expect(PrivacyMode.money('R\$ 1.234,00', hidden: false), 'R\$ 1.234,00');
    });

    test('toggle alterna e lembra a escolha', () async {
      final p = PrivacyMode.instance;
      p.hidden.value = false;
      await p.toggle();
      expect(p.hidden.value, isTrue);
      expect(await LocalPrefs.read('modo_privacidade'), '1');
      await p.toggle();
      expect(await LocalPrefs.read('modo_privacidade'), '0');
    });
  });

  group('Carteira: saldo = liberado - saques', () {
    Payment pay(String status, double net) => Payment.fromMap({
          'id': 'p',
          'job_id': 'j',
          'client_id': 'c',
          'provider_id': 'pr',
          'amount': net / 0.88,
          'fee_pct': 12,
          'fee_amount': net / 0.88 - net,
          'net_amount': net,
          'method': 'pix',
          'status': status,
          'created_at': DateTime.now().toIso8601String(),
          'released_at': status == 'released' ? DateTime.now().toIso8601String() : null,
        });

    test('saque reduz o disponível; custódia não é afetada; nunca fica negativo', () {
      final ps = [pay('released', 100), pay('released', 50), pay('escrow', 30)];
      expect(ProviderService.summarize(ps).available, 150);
      expect(ProviderService.summarize(ps, withdrawn: 40).available, 110);
      expect(ProviderService.summarize(ps, withdrawn: 40).held, 30);
      expect(ProviderService.summarize(ps, withdrawn: 999).available, 0);
    });
  });

  group('Chave Pix (validação local)', () {
    test('CPF e CNPJ com dígitos verificadores', () {
      expect(PixKeyValidator.isValid(PixKeyType.cpf, '529.982.247-25'), isTrue);
      expect(PixKeyValidator.isValid(PixKeyType.cpf, '52998224725'), isTrue);
      expect(PixKeyValidator.isValid(PixKeyType.cpf, '529.982.247-24'), isFalse);
      expect(PixKeyValidator.isValid(PixKeyType.cpf, '111.111.111-11'), isFalse);
      expect(PixKeyValidator.isValid(PixKeyType.cnpj, '11.222.333/0001-81'), isTrue);
      expect(PixKeyValidator.isValid(PixKeyType.cnpj, '11.222.333/0001-82'), isFalse);
    });

    test('e-mail, celular e chave aleatória', () {
      expect(PixKeyValidator.isValid(PixKeyType.email, 'ana@exemplo.com.br'), isTrue);
      expect(PixKeyValidator.isValid(PixKeyType.email, 'ana@exemplo'), isFalse);
      expect(PixKeyValidator.isValid(PixKeyType.phone, '(35) 99876-5432'), isTrue);
      expect(PixKeyValidator.isValid(PixKeyType.phone, '(35) 3521-0000'), isFalse);
      expect(PixKeyValidator.isValid(PixKeyType.random, '123e4567-e89b-12d3-a456-426614174000'), isTrue);
      expect(PixKeyValidator.isValid(PixKeyType.random, 'abc'), isFalse);
    });
  });

  group('Trava da exclusão de conta', () {
    test('saldo > 0 → sheet do Pix; custódia/serviço → aguardar; limpo → pode excluir', () {
      final saldo = DeletionStatus.fromMap({'available': 120.5, 'held': 0, 'active_jobs': 0, 'blockers': ['balance']});
      expect(saldo.canDelete, isFalse);
      expect(saldo.hasBalance, isTrue);
      expect(saldo.hasOngoing, isFalse);

      final andamento = DeletionStatus.fromMap({'available': 0, 'held': 44, 'active_jobs': 1, 'blockers': ['escrow', 'active_jobs']});
      expect(andamento.hasBalance, isFalse);
      expect(andamento.hasOngoing, isTrue);

      final limpo = DeletionStatus.fromMap({'available': 0, 'held': 0, 'active_jobs': 0, 'blockers': []});
      expect(limpo.canDelete, isTrue);
      expect(DeletionStatus.fromMap({}).canDelete, isTrue, reason: 'payload vazio não explode');
    });
  });

  group('Vitrine e Case de Sucesso (modelos)', () {
    test('ShowcaseCase.fromMap', () {
      final c = ShowcaseCase.fromMap({
        'job_id': 'j1',
        'title': 'Troca de chuveiro',
        'category': 'Elétrica',
        'cover_path': 'u/clean.jpg',
        'rating': 5,
        'comment': 'Perfeito!',
        'client_name': 'Ana S.',
        'revealed_at': '2026-10-29T12:00:00Z',
        'pinned': true,
        'pos': 0,
      });
      expect(c.pinned, isTrue);
      expect(c.position, 0);
      expect(c.coverPath, 'u/clean.jpg');
      expect(c.revealedAt, isNotNull);
    });

    test('CaseDetail: relatório, fotos, vídeo e tags', () {
      final d = CaseDetail.fromMap({
        'job_id': 'j1',
        'provider_id': 'p1',
        'title': 'X',
        'category': 'Elétrica',
        'report': '  Troquei o disjuntor.  ',
        'photos': ['a', 'b', 'c', 'd'],
        'video': 'v.mp4',
        'rating': 5,
        'tags': ['Super pontual'],
        'client_name': 'Ana S.',
        'pinned': false,
      });
      expect(d.hasReport, isTrue);
      expect(d.photos.length, 4);
      expect(d.video, 'v.mp4');
      expect(CaseDetail.fromMap({'job_id': 'j', 'provider_id': 'p', 'report': '   '}).hasReport, isFalse);
    });

    test('limites da vitrine: 4 vagas, no máximo 3 fixados (sobra 1 vaga LIFO)', () {
      expect(kShowcaseSlots, 4);
      expect(kMaxPinnedCases, 3);
      expect(kMaxPinnedCases, lessThan(kShowcaseSlots));
    });

    test('CaseHistoryItem: só 5★ pode ser fixado (flag do servidor)', () {
      final h = CaseHistoryItem.fromMap({'job_id': 'j', 'title': 'T', 'rating': 4, 'pinned': false, 'in_showcase': true, 'can_pin': false});
      expect(h.canPin, isFalse);
      expect(h.inShowcase, isTrue);
    });
  });

  group('Splash coreografada', () {
    test('traço parcial do símbolo: 0% vazio, 50% ≈ metade, 100% inteiro', () {
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      double len(Path x) => x.computeMetrics().fold(0.0, (a, m) => a + m.length);
      expect(len(SplashSymbolPainter.partial(p, 0)), closeTo(0, 0.01));
      expect(len(SplashSymbolPainter.partial(p, .5)), closeTo(50, 0.5));
      expect(len(SplashSymbolPainter.partial(p, 1)), closeTo(100, 0.5));
      expect(len(SplashSymbolPainter.partial(p, 7)), closeTo(100, 0.5), reason: 'clamp');
    });

    test('repinta só quando o progresso muda', () {
      final a = SplashSymbolPainter(draw: .3, glow: 0);
      expect(a.shouldRepaint(SplashSymbolPainter(draw: .3, glow: 0)), isFalse);
      expect(a.shouldRepaint(SplashSymbolPainter(draw: .4, glow: 0)), isTrue);
      expect(ConfettiPainter(progress: .2).shouldRepaint(ConfettiPainter(progress: .2)), isFalse);
    });

    testWidgets('espera ≥ 1,8 s mesmo com init instantâneo e só então libera o app', (tester) async {
      BootResult? result;
      await tester.pumpWidget(MaterialApp(
        home: AnimatedSplashScreen(
          init: Future.value(const BootResult(theme: AppThemeMode.dark, backendReady: true)),
          onFinished: (r) => result = r,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      expect(result, isNull, reason: 'animação ainda tocando');
      await tester.pump(const Duration(milliseconds: 1100));
      expect(result, isNotNull);
      expect(result!.theme, AppThemeMode.dark);
      expect(find.text('Desperrengue'), findsOneWidget);
    });

    testWidgets('init lento: a splash aguarda a inicialização terminar', (tester) async {
      final done = Completer<BootResult>();
      BootResult? result;
      await tester.pumpWidget(MaterialApp(
        home: AnimatedSplashScreen(init: done.future, onFinished: (r) => result = r),
      ));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(result, isNull, reason: 'init ainda pendente');
      done.complete(const BootResult(theme: AppThemeMode.system, backendReady: true));
      await tester.pump();
      await tester.pump();
      expect(result, isNotNull);
    });
  });

  group('Seleção de perfil (redesign)', () {
    Future<void> pump(WidgetTester tester, UserProfile p, {ThemeMode mode = ThemeMode.light}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.light),
        darkTheme: AppTheme.resolve(null, Brightness.dark),
        themeMode: mode,
        home: RoleSelectionScreen(profile: p),
      ));
      await tester.pump();
    }

    testWidgets('primeiro acesso: saudação, subtítulo e duas pílulas "Criar Perfil"', (tester) async {
      await pump(tester, profile());
      expect(find.text('Olá, Ana'), findsOneWidget);
      expect(find.text('Como você deseja usar o Desperrengue hoje?'), findsOneWidget);
      expect(find.text('Preciso de um serviço'), findsOneWidget);
      expect(find.text('Quero trabalhar'), findsOneWidget);
      expect(find.text('Criar Perfil'), findsNWidgets(2));
      expect(find.text('Perfil Ativo'), findsNothing);
    });

    testWidgets('perfil pronto vira "Perfil Ativo"; incompleto, "Termine o seu cadastro"', (tester) async {
      await pump(tester, profile(client: true, clientDone: true, provider: true, providerDone: false));
      expect(find.text('Perfil Ativo'), findsOneWidget);
      expect(find.text('Termine o seu cadastro'), findsOneWidget);
      expect(find.text('Criar Perfil'), findsNothing);
    });

    testWidgets('aguardando análise mostra "Em análise"', (tester) async {
      await pump(tester, profile(provider: true, ver: 'PENDING'));
      expect(find.text('Em análise'), findsOneWidget);
    });

    testWidgets('cartões inteiros clicáveis (InkWell) e seta de voltar presentes', (tester) async {
      await pump(tester, profile());
      expect(find.byType(InkWell), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('renderiza no tema escuro sem estourar o layout', (tester) async {
      await pump(tester, profile(client: true, clientDone: true), mode: ThemeMode.dark);
      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFF121212));
    });
  });
}
