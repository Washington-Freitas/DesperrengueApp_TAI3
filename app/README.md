# desperrengue_app

Aplicativo Flutter do **Desperrengue** (marketplace de serviços residenciais). Visão geral do projeto no [README raiz](../README.md); backend em [`../supabase`](../supabase/README.md).

## Arquitetura

```
lib/
├── main.dart                         # init do Supabase + AuthGate
├── core/
│   ├── constants/env.dart            # config (--dart-define)
│   ├── models/user_profile.dart      # modelos puros + regra de roteamento (testável)
│   ├── providers/supabase_provider.dart
│   └── services/profile_service.dart # ÚNICA camada que conhece tabelas/RPCs
└── features/
    ├── auth/presentation/            # login, cadastro+OTP, papel, KYC (etapas 1–7)
    │   ├── auth_gate.dart            # sessão + deep link -> decide Login ou PostAuthRouter
    │   └── post_auth_router.dart     # estado do perfil no servidor -> tela correta
    ├── home/presentation/            # destinos provisórios (cliente/profissional/admin)
    └── profile_setup/                # próximos passos do perfil público (a implementar)
```

**Roteamento:** `AuthGate` observa a sessão do Supabase e o deep link `desperrengue://onboarding/...`; `PostAuthRouter` lê `profiles` e aplica `destinationFor(profile)` (`core/models/user_profile.dart`). Nenhuma tela decide "para onde ir" por conta própria.

## Comandos

```bash
flutter pub get
flutter analyze     # deve retornar "No issues found!"
flutter test
flutter run
```

Parâmetros opcionais de build: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `ABSTRACT_API_KEY` (ver README raiz).

## Plataformas

- **Android:** `applicationId = br.com.desperrengue.app`; permissão `INTERNET` no manifest principal; deep links `desperrengue://onboarding` e `br.com.desperrengue.app://login-callback`.
- **iOS:** `Info.plist` com descrições de câmera/fotos e os mesmos esquemas de URL.

## Banco de dados

O schema **não** vive mais neste diretório: a fonte da verdade é [`../supabase/migrations`](../supabase/migrations).
