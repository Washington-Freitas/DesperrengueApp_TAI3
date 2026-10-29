import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:desperrengue_app/core/services/update_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/boot/update_gate.dart';

String release({int build = 29712345, String version = '0.2.0', String notes = 'corrige o login', bool withApk = true}) => jsonEncode({
      'tag_name': 'beta-latest',
      'body': 'build: $build\nversion: $version\n## Novidades\n$notes\n\n---\nInstalador beta para testadores.',
      'assets': [
        if (withApk) {'name': 'desperrengue.apk', 'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk', 'size': 64471667},
      ],
    });

void main() {
  group('UpdateService.parse', () {
    test('lê build, versão, tamanho, URL e novidades (só até o separador ---)', () {
      final i = UpdateService.parse(release())!;
      expect(i.build, 29712345);
      expect(i.version, '0.2.0');
      expect(i.apkUrl, endsWith('/beta-latest/desperrengue.apk'));
      expect(i.sizeLabel, '61 MB');
      expect(i.notes, 'corrige o login');
    });

    test('release sem "build:" ou sem APK é ignorado', () {
      expect(UpdateService.parse(jsonEncode({'body': 'sem build', 'assets': []})), isNull);
      expect(UpdateService.parse(release(withApk: false)), isNull);
      expect(UpdateService.parse('lixo'), isNull);
    });
  });

  group('UpdateService.check', () {
    UpdateService svc(http.Client c, {int installed = 100, bool enabled = true}) =>
        UpdateService(client: c, installedBuild: () async => installed, repo: 'x/y', enabled: enabled);

    test('versão mais nova => devolve a atualização', () async {
      final s = svc(MockClient((r) async {
        expect(r.url.path, '/repos/x/y/releases/tags/beta-latest');
        return http.Response(release(build: 101), 200, headers: {'etag': 'W/"a"'});
      }));
      expect((await s.check())?.build, 101);
    });

    test('mesma versão ou mais antiga => null', () async {
      expect(await svc(MockClient((_) async => http.Response(release(build: 100), 200)), installed: 100).check(), isNull);
      expect(await svc(MockClient((_) async => http.Response(release(build: 50), 200)), installed: 100).check(), isNull);
    });

    test('usa ETag: a 2ª consulta manda If-None-Match e o 304 reaproveita o cache', () async {
      var calls = 0;
      String? sent;
      final s = svc(MockClient((r) async {
        calls++;
        sent = r.headers['If-None-Match'];
        return calls == 1 ? http.Response(release(build: 101), 200, headers: {'etag': 'W/"v1"'}) : http.Response('', 304);
      }));
      expect((await s.check())?.build, 101);
      expect(sent, isNull);
      expect((await s.check())?.build, 101, reason: '304 mantém a informação em cache');
      expect(sent, 'W/"v1"');
    });

    test('erro de rede, 404 e 500 nunca lançam (devolvem null)', () async {
      expect(await svc(MockClient((_) async => throw Exception('sem rede'))).check(), isNull);
      expect(await svc(MockClient((_) async => http.Response('nf', 404))).check(), isNull);
      expect(await svc(MockClient((_) async => http.Response('err', 500))).check(), isNull);
    });

    test('desativado (build da Play Store / debug) não faz nenhuma requisição', () async {
      var calls = 0;
      final s = svc(MockClient((_) async {
        calls++;
        return http.Response(release(build: 999), 200);
      }), enabled: false);
      expect(await s.check(), isNull);
      expect(calls, 0);
    });
  });

  group('UpdateGate (aviso na tela)', () {
    UpdateInfo info(int b) => UpdateInfo(build: b, version: '0.2.0', apkUrl: 'https://x/y.apk', sizeBytes: 64471667, notes: 'novidade');

    Future<void> pump(WidgetTester t, {required Future<UpdateInfo?> Function() check, Future<void> Function(String)? open, Brightness b = Brightness.light}) async {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, b),
        home: const SizedBox(),
        builder: (c, child) => UpdateGate(check: check, openUrl: open, initialDelay: const Duration(milliseconds: 50), interval: const Duration(minutes: 5), child: child!),
      ));
    }

    testWidgets('mostra o aviso quando há versão nova e esconde com "Depois"', (t) async {
      await pump(t, check: () async => info(5));
      expect(find.text('Nova versão'), findsNothing, reason: 'ainda não checou');
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      expect(find.text('Nova versão'), findsOneWidget);
      expect(find.text('Versão 0.2.0 · 61 MB'), findsOneWidget);
      await t.tap(find.text('Depois'));
      await t.pump();
      expect(find.text('Nova versão'), findsNothing);
      await t.pumpWidget(const SizedBox()); // desmonta e cancela os timers
    });

    testWidgets('"Atualizar" abre o APK e mostra as instruções de instalação', (t) async {
      String? opened;
      await pump(t, check: () async => info(5), open: (u) async => opened = u);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      await t.tap(find.text('Atualizar'));
      await t.pump();
      expect(opened, 'https://x/y.apk');
      expect(find.text('Baixando...'), findsOneWidget);
      expect(find.textContaining('toque na notificação'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('sem versão nova não aparece nada (e funciona no tema escuro)', (t) async {
      await pump(t, check: () async => null, b: Brightness.dark);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      expect(find.text('Nova versão'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  });
}
