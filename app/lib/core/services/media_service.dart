import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload e URLs de mídia.
///  * `public-media`: avatar e portfólio (URL pública, qualquer logado vê).
///  * `job-media`: fotos do pedido, evidências e provas de suporte (privado;
///    acesso por URL assinada, liberado por policy a quem participa do pedido).
class MediaService {
  MediaService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const publicBucket = 'public-media';
  static const privateBucket = 'job-media';

  static final Map<String, String> _signedCache = {};

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  static String mime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'image/jpeg';
    }
  }

  static String extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return 'jpg';
    final e = name.substring(i + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(e) ? (e == 'jpeg' ? 'jpg' : e) : 'jpg';
  }

  /// Envia para `public-media/<uid>/<prefix>_<ts>.<ext>` e devolve a URL pública.
  Future<String> uploadPublic(Uint8List bytes, String ext, {String prefix = 'img'}) async {
    final path = '$_uid/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(publicBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime(ext), upsert: false),
    );
    return _client.storage.from(publicBucket).getPublicUrl(path);
  }

  /// Caminho de armazenamento (para guardar no banco) de um upload público.
  Future<String> uploadPublicPath(Uint8List bytes, String ext, {String prefix = 'img'}) async {
    final path = '$_uid/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(publicBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime(ext), upsert: false),
    );
    return path;
  }

  String publicUrl(String path) => _client.storage.from(publicBucket).getPublicUrl(path);

  /// Envia para `job-media/<uid>/<prefix>_<ts>.<ext>` e devolve o caminho.
  Future<String> uploadPrivate(Uint8List bytes, String ext, {String prefix = 'img'}) async {
    final path = '$_uid/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _client.storage.from(privateBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime(ext), upsert: false),
    );
    return path;
  }

  Future<String?> signedUrl(String path) async {
    final cached = _signedCache[path];
    if (cached != null) return cached;
    try {
      final url = await _client.storage.from(privateBucket).createSignedUrl(path, 3600);
      _signedCache[path] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> removePrivate(String path) async {
    await _client.storage.from(privateBucket).remove([path]);
    _signedCache.remove(path);
  }
}
