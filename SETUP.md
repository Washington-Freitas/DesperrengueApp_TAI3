# SETUP — Guia de Onboarding Técnico

> **Objetivo.** Levar um(a) novo(a) desenvolvedor(a), em uma sessão de trabalho, do repositório recém-clonado até **(a)** o app rodando em um emulador, **(b)** `analyze` e testes verdes, **(c)** acesso de leitura ao backend e **(d)** o primeiro *commit* aberto como *pull request*.
> **Tempo estimado:** 45–90 min (a maior parte é *download* do Android SDK e do Gradle na primeira compilação).
> **Guias detalhados por sistema operacional:** [Windows](docs/setup/windows.md) · [macOS](docs/setup/macos.md) · [Linux](docs/setup/linux.md). Este documento é o **caminho crítico**; aqueles são a referência de instalação.

---

## 1. Pré-requisitos

| Ferramenta | Versão verificada | Observação |
| :-- | :-- | :-- |
| **Git** | ≥ 2.40 | — |
| **Flutter** (canal *stable*) | 3.47.x (Dart ≥ 3.13.4) | `flutter --version`; o SDK do Dart é exigido por `environment.sdk` no `pubspec.yaml` |
| **JDK** | **17** | **Não use 11**: Gradle 9.3.1/AGP 9.1.0 exigem 17+ |
| **Android SDK** | plataformas 36/37, *build-tools*, *platform-tools*, *emulator* | Via Android Studio; `compileSdk = 37` |
| **Android Studio** (ou só as *command-line tools*) | recente | Para criar o AVD (ex.: *Pixel 8*) |
| **Xcode + CocoaPods** | somente macOS | Para iOS |
| **Supabase CLI** | ≥ 2.100 | **Opcional**, necessário para consultar/alterar o banco |
| **VS Code** ou Android Studio | — | Extensões *Flutter* e *Dart* |

Valide o ambiente:

```bash
flutter doctor -v     # todos os itens relevantes devem estar [✓]; aceite as licenças: flutter doctor --android-licenses
java -version         # deve exibir 17.x
```

---

## 2. Obter o código

```bash
git clone https://github.com/Washington-Freitas/DesperrengueApp_TAI3.git
cd DesperrengueApp_TAI3
git checkout main && git pull
git checkout -b feat/<seu-topico>      # ver CONTRIBUTING.md
```

Estrutura (resumo; detalhes em [ARCHITECTURE](ARCHITECTURE.md)):

```
app/                 # aplicativo Flutter  ← você trabalha aqui
supabase/            # migrations (fonte da verdade do banco), Edge Functions, testes SQL
docs/                # contexto, especificação, ADRs, specs de tela, guias de ambiente
```

> Usuários de **Windows**: se o PowerShell bloquear scripts, execute uma vez `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.

---

## 3. Dependências e primeira execução

```bash
cd app
flutter pub get
flutter analyze        # esperado: No issues found!
flutter test           # esperado: All tests passed!
```

Crie/ligue um emulador (ou conecte um aparelho com depuração USB):

```bash
flutter emulators                         # lista AVDs
flutter emulators --launch Pixel_8        # inicia (a 1ª vez pode levar 1–2 min)
flutter devices                           # confirme o dispositivo
flutter run -d <id-do-dispositivo>        # a 1ª compilação do Gradle pode levar vários minutos
```

Durante o `flutter run`: `r` = *hot reload*, `R` = *hot restart*, `q` = sair.

---

## 4. Configuração e variáveis de ambiente

O app **não lê arquivos `.env`**. A configuração é feita por **`--dart-define`** (valores de compilação), com padrões que apontam para o projeto Supabase do MVP (`core/constants/env.dart`):

| Variável | Padrão | Uso |
| :-- | :-- | :-- |
| `SUPABASE_URL` | `https://eisfkemgooqbgqljvwvs.supabase.co` | Endpoint do projeto |
| `SUPABASE_PUBLISHABLE_KEY` | chave *publishable* do MVP (**pública por design**) | Acesso anônimo/autenticado limitado pela RLS |
| `ABSTRACT_API_KEY` | vazio (validação extra de e-mail desativada) | Opcional |

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=ABSTRACT_API_KEY=<opcional>
```

> ⚠️ **Nunca** coloque `service_role`, senha do banco, `RESEND_API_KEY` ou tokens pessoais no app, no repositório ou em *issues*. Eles pertencem a **segredos do Supabase** ou ao seu cofre local. Ver [SECURITY](SECURITY.md).

### 4.1 Login com Google em desenvolvimento

O OAuth Google exige que o **SHA-1 do certificado de assinatura** do seu *build* esteja registrado no cliente OAuth do projeto no Google Cloud. Se o login retornar erro de configuração (`ApiException: 10`), obtenha o SHA-1 da sua *debug keystore* (`cd app/android && ./gradlew signingReport`) e peça ao mantenedor para registrá-lo. O retorno do OAuth usa `br.com.desperrengue.app://login-callback`.

---

## 5. Backend (Supabase) — opcional para trabalho só de UI

Você **não precisa** de acesso ao Supabase para alterar telas que usem apenas os serviços existentes: o app aponta para o projeto compartilhado. Para **ler/alterar o banco**:

1. Peça ao mantenedor convite ao projeto `eisfkemgooqbgqljvwvs`.
2. Instale e autentique o CLI:

   ```bash
   npm install -g supabase       # ou o método do seu SO
   supabase login
   supabase link --project-ref eisfkemgooqbgqljvwvs
   ```
3. **Sem Docker**, `db pull`/`db diff` não funcionam. Use a Management API do CLI:

   ```bash
   supabase db query --linked "select count(*) from public.profiles;"
   supabase db query --linked -f supabase/tests/security_smoke.sql     # esperado: FALHAS=0
   ```
4. Fluxo de *migrations* (resumo; regras completas no [CONTRIBUTING](CONTRIBUTING.md)): criar arquivo `supabase/migrations/AAAAMMDDHHMMSS_nome.sql` com `BEGIN … COMMIT`; **ensaiar com `ROLLBACK`**; aplicar; registrar a versão em `supabase_migrations.schema_migrations`; rodar o teste de fumaça.

> O ambiente remoto é **único** (desenvolvimento = MVP). Trate qualquer escrita como *produção*.

### 5.1 Contas de teste

Crie contas de teste com e-mails do domínio reservado `@example.com` (ex.: `qa.cliente@example.com`) e **remova-as ao terminar** — procedimento em [TESTING §7](TESTING.md#7-dados-de-teste-e-higiene-do-ambiente). Para o cadastro por e-mail real, o OTP chega ao endereço informado (SMTP via Resend).

---

## 6. Rotina diária

```bash
git pull --rebase origin main
cd app && flutter pub get
flutter analyze && flutter test        # antes de cada commit
dart format lib test                   # formatação
```

### 6.1 Executar no VS Code e no Android Studio

**VS Code** (extensões recomendadas em `.vscode/extensions.json`; *tasks* em `.vscode/tasks.json`; configurações de execução em `.vscode/launch.json`):

```powershell
cd app
flutter pub get
flutter emulators --launch Pixel_8     # inicia o AVD (aguarde ~1 min)
flutter devices                        # confirme "emulator-5554"
flutter run -d emulator-5554           # r = hot reload · R = hot restart · q = sair
```

Alternativa: `F5` com a configuração **Desperrengue (debug)**, ou `Ctrl+Shift+P` → *Tasks: Run Task*.

**Android Studio** (plugins **Flutter** e **Dart** instalados): *File → Open* e escolha a pasta **`app/`** (não a raiz do repositório, nem `app/android`). Em *Settings → Languages & Frameworks → Flutter*, aponte o *Flutter SDK path* se não for detectado. Selecione o dispositivo `Pixel_8` e clique em **Run ▶**.

> O aviso `Visual Studio not installed` do `flutter doctor` refere-se apenas a *desktop* Windows e pode ser ignorado para o app móvel.

---

## 7. Seu primeiro *commit* (checklist de Dia 1)

1. Rode `flutter analyze && flutter test` — **verde** antes de alterar qualquer coisa.
2. Escolha uma tarefa pequena (ex.: um *typo* em texto de tela, um teste novo em `app/test/`).
3. Crie a *branch*: `git checkout -b docs/ajuste-no-setup`.
4. Faça a mudança e rode a verificação novamente.
5. *Commit* seguindo **Conventional Commits** (ex.: `docs(setup): corrige versão do JDK`).
6. `git push -u origin <branch>` e abra o *pull request* (o *template* será carregado). Veja [CONTRIBUTING](CONTRIBUTING.md).

---

## 8. Solução de problemas

| Sintoma | Causa provável | Ação |
| :-- | :-- | :-- |
| `Gradle … requires Java 17` | JDK errado | Instale o JDK 17 e aponte `JAVA_HOME`; `flutter config --jdk-dir <caminho>` |
| `flutter doctor`: *Android licenses not accepted* | Licenças pendentes | `flutter doctor --android-licenses` |
| Emulador `offline` no `adb devices` | Boot incompleto | Aguarde `sys.boot_completed=1` (`adb shell getprop sys.boot_completed`); `adb kill-server && adb start-server` |
| Emulador lento/sem iniciar (Windows) | Aceleração desligada | Ative *Windows Hypervisor Platform* / virtualização na BIOS |
| `Execution failed … Directory … in use` / pasta travada | IDE ou Gradle com *handles* abertos | Feche a IDE, `cd app/android && ./gradlew --stop` |
| `AuthRetryableFetchException` / sem rede | Emulador sem Internet ou chave/URL errados | Verifique rede do AVD e `--dart-define` |
| Login Google: `ApiException: 10` | SHA-1 não cadastrado | §4.1 |
| `supabase db query` imprime `NativeCommandError` no PowerShell | O CLI escreve avisos em *stderr* | Não é falha; avalie o JSON de saída |
| Imagens/câmera não funcionam no emulador | Sem cena virtual/permissões | Configure a câmera do AVD (*Virtual scene*) e conceda permissões |
| `pubspec` avisa pacotes desatualizados | Normal | Atualizações são tratadas em PR dedicado (`chore(deps)`) |

Persistindo o problema, abra uma *issue* com o modelo **Bug** (inclua `flutter doctor -v`).
