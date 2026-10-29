import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/env.dart';

/// Uma versão BETA mais nova que a instalada.
@immutable
class UpdateInfo {
  const UpdateInfo({required this.build, required this.version, required this.apkUrl, this.sizeBytes, this.notes = ''});

  /// `versionCode` da versão nova (sempre crescente: gerado pela CI).
  final int build;
  final String version;
  final String apkUrl;
  final int? sizeBytes;

  /// "Novidades" (mensagem do último commit), se houver.
  final String notes;

  String get sizeLabel => sizeBytes == null ? '' : '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB';
}

/// Verifica, no GitHub Releases, se existe um APK beta mais novo.
///
/// A CI (`.github/workflows/beta-release.yml`) mantém UM release "rolante"
/// (`beta-latest`) cujo texto começa com `build: <versionCode>`. O app compara com
/// o `versionCode` instalado. Usa **ETag**: respostas 304 não contam no limite da API
/// do GitHub, então checar a cada poucos minutos é barato.
///
/// Só funciona em builds feitos com `--dart-define=BETA_UPDATES=true` (a CI faz isso);
/// builds da Play Store ficam de fora (a loja atualiza sozinha).
class UpdateService {
  UpdateService({http.Client? client, Future<int> Function()? installedBuild, String? repo, bool? enabled})
      : _client = client ?? http.Client(),
        _installedBuild = installedBuild ?? _platformBuild,
        _repo = repo ?? Env.updateRepo,
        enabled = enabled ?? Env.betaUpdates;

  final http.Client _client;
  final Future<int> Function() _installedBuild;
  final String _repo;
  final bool enabled;

  static const String releaseTag = 'beta-latest';

  String? _etag;
  UpdateInfo? _cached;

  static Future<int> _platformBuild() async => int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// Devolve a atualização disponível ou null (sem versão nova, sem rede ou desativado).
  /// Nunca lança: falha de rede não pode incomodar o usuário.
  Future<UpdateInfo?> check() async {
    if (!enabled) return null;
    try {
      final installed = await _installedBuild();
      final res = await _client.get(
        Uri.https('api.github.com', '/repos/$_repo/releases/tags/$releaseTag'),
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'If-None-Match': ?_etag,
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        _etag = res.headers['etag'];
        _cached = parse(res.body);
      } else if (res.statusCode != 304) {
        return null;
      }
      final info = _cached;
      return (info != null && info.build > installed) ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// Lê o JSON do release. Formato do texto (gerado pela CI):
  /// ```
  /// build: 29712345
  /// version: 0.2.0
  /// ## Novidades
  /// mensagem do commit
  /// ---
  /// (texto para humanos)
  /// ```
  @visibleForTesting
  static UpdateInfo? parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final text = (json['body'] as String?) ?? '';
      final build = int.tryParse(RegExp(r'^build:\s*(\d+)', multiLine: true).firstMatch(text)?.group(1) ?? '');
      if (build == null) return null;
      final version = RegExp(r'^version:\s*([\w.\-+]+)', multiLine: true).firstMatch(text)?.group(1) ?? '';
      final assets = (json['assets'] as List?)?.whereType<Map>() ?? const <Map>[];
      final apk = assets.cast<Map>().firstWhere((a) => '${a['name']}'.endsWith('.apk'), orElse: () => const {});
      final url = apk['browser_download_url'] as String?;
      if (url == null) return null;
      final notes = RegExp(r'## Novidades\s*\n([\s\S]*?)(?:\n---|$)').firstMatch(text)?.group(1)?.trim() ?? '';
      return UpdateInfo(build: build, version: version, apkUrl: url, sizeBytes: (apk['size'] as num?)?.toInt(), notes: notes);
    } catch (_) {
      return null;
    }
  }
}
