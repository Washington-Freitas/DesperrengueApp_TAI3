/// Nomes de exibição seguros.
///
/// Algumas contas têm `profiles.full_name` igual ao e-mail (cadastro rápido). Mostrar isso
/// vaza dado pessoal e fica feio ("wagneroliveira9819@gmail.com"). Regra do app: **nunca**
/// exibir texto que pareça e-mail como nome; usa-se um rótulo neutro.
library;

/// `true` se [s] parece um e-mail (contém `@`).
bool looksLikeEmail(String? s) => s != null && s.contains('@');

/// Nome completo pronto para exibir. Se vazio/nulo/e-mail, devolve [fallback].
String friendlyName(String? fullName, {String fallback = 'Cliente'}) {
  final n = fullName?.trim() ?? '';
  if (n.isEmpty || looksLikeEmail(n)) return fallback;
  return n;
}

/// "Maria Souza Lima" -> "Maria S." (para telas públicas). E-mail/vazio -> [fallback].
String shortName(String? fullName, {String fallback = 'Cliente'}) {
  final n = friendlyName(fullName, fallback: '');
  if (n.isEmpty) return fallback;
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first;
  return '${parts.first} ${parts[1][0].toUpperCase()}.';
}
