/// Configuração de ambiente do app.
///
/// Valores podem ser sobrescritos em tempo de build:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// A chave `sb_publishable_...` é pública por design (a proteção real está nas
/// policies de RLS). NUNCA coloque aqui `service_role`, senha do banco ou chaves
/// de terceiros: use `--dart-define` (ex.: ABSTRACT_API_KEY) ou o backend.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eisfkemgooqbgqljvwvs.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_7uVAOXQaut46NP0gTTv3dA_qh5CE0e7',
  );

  /// Atualização automática do beta (APK fora da Play Store). A CI compila com
  /// `--dart-define=BETA_UPDATES=true`; builds locais e da Play Store ficam desligados.
  static const bool betaUpdates = bool.fromEnvironment('BETA_UPDATES');

  /// Repositório GitHub onde a CI publica o release rolante `beta-latest`.
  static const String updateRepo = String.fromEnvironment(
    'UPDATE_REPO',
    defaultValue: 'Washington-Freitas/DesperrengueApp_TAI3',
  );

  /// Opcional. Vazia = a validação extra de e-mail (Abstract API) é desativada
  /// e a verificação fica a cargo do código OTP enviado pelo Supabase.
  static const String abstractApiKey = String.fromEnvironment(
    'ABSTRACT_API_KEY',
  );
}
