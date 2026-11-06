/// Geração de identificadores sem dependência externa.
library;

import 'dart:math';

final Random _secure = Random.secure();

/// UUID v4 (RFC 4122) a partir de [Random.secure] (ou de [random], nos testes).
///
/// Usado como `client_message_id` do chat: o id nasce no clique de enviar e
/// acompanha qualquer reenvio, para o banco poder recusar duplicatas.
String uuidV4([Random? random]) {
  final r = random ?? _secure;
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versão 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122 (10xx)
  String hex(int from, int to) =>
      b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// `true` se [s] tem o formato de um UUID v4.
bool isUuidV4(String s) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(s);
