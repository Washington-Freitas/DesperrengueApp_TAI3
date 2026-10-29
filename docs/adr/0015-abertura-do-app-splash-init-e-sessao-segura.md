# ADR-0015 — Abertura do app: splash nativa + animada, init paralela, sessão no Keystore e último perfil

* **Status:** Aceito
* **Data:** 2026-10-29
* **Decisores:** Desenvolvedor
* **Tags:** performance, UX, segurança, offline-first, Flutter

## Contexto

A primeira impressão define a retenção. O app iniciava com `Supabase.initialize` **antes** do primeiro frame (tela branca/preta no *cold start*), guardava o token em `SharedPreferences` (texto puro) e perguntava o perfil a cada abertura.

## Decisão

1. **Fase 1 — splash nativa** (`flutter_native_splash`): fundo `#1E3B70` + símbolo, renderizada pelo SO. Sem tela branca. (Geração exige fixar `image 4.5.4`/`archive 4.0.7` em `dependency_overrides`; afeta só a ferramenta.)
2. **Fase 2 — splash animada** (`AnimatedSplashScreen`): traço do contorno do símbolo, *glow*, nome com Fade+Scale e confetes sutis; **1,8 s**. Feita em `CustomPainter` + **um** `AnimationController` + `RepaintBoundary` (sem Lottie/Rive: zero KB de asset, 60/120 fps). Respeita "remover animações" do sistema. Saída por **FadeOut** (`PageRouteBuilder`).
3. **Engenharia de tráfego** (`AppInitializationService`): `Future.wait` de (a) warm-up de imagens, (b) `Supabase.initialize` com a sessão no **armazenamento seguro**, (c) tema salvo. O custo é o da tarefa mais lenta; a splash só sai quando animação **e** init terminam.
4. **Sessão no Keystore/Keychain** (`SecureSessionStorage`, `flutter_secure_storage`): migra a sessão antiga sem deslogar ninguém e remove o texto puro do `SharedPreferences`.
5. **Graceful fallback:** todo I/O local é protegido. Sessão corrompida → limpa e refaz; se ainda falhar, tela "Tentar novamente"; nunca *crash*. Cache do perfil (`cachedProfile`) deixa o app abrir **sem rede** (stale-while-revalidate).
6. **Último perfil usado** (`ultimo_perfil_usado` = `<uid>:<modo>`): com os dois perfis prontos, abre direto no último (a seleção segue a um toque em "Trocar de modo"). Atrelado à conta, para outra pessoa no mesmo aparelho não herdar.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Lottie/Rive | Asset a mais, mesmo resultado | Canvas é mais leve e testável |
| Inicializar tudo antes do `runApp` | Tela branca/preta no cold start | É o problema a resolver |
| Manter token em `SharedPreferences` | Texto puro no armazenamento do app | Keystore é o padrão da indústria |

## Consequências

* (+) Primeiro frame imediato; init paralela; token protegido; abre offline.
* (−) `flutter_secure_storage` exige minSdk 24 (já atendido).
* (−) Usuário com os dois perfis deixa de ver a seleção a cada abertura (comportamento pedido; reversível apagando a preferência).

## Referências

* `app/lib/features/boot/`, `app/lib/core/boot/app_initialization_service.dart`, `app/lib/core/storage/`.
