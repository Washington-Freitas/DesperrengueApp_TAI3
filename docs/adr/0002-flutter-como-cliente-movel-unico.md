# ADR-0002 — Flutter como cliente móvel multiplataforma

* **Status:** Aceito
* **Data:** 2026-09-19
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** mobile, frontend

## Contexto

O produto é essencialmente **móvel** (câmera para KYC e evidências, geolocalização, notificações, deep links). O público usa Android e iOS. A equipe técnica é de uma pessoa; manter duas bases nativas inviabiliza o prazo. Os protótipos hi-fi exigem UI customizada (anéis de contagem, radar animado, teclado de PIN), pouco aderente a componentes nativos padrão.

## Decisão

Adotar **Flutter (Dart ≥ 3.13)** com uma única base de código para Android e iOS, usando `supabase_flutter` como SDK de acesso ao backend. Pacotes de plataforma: `image_picker`, `geolocator`, `app_links`, `google_sign_in`, `camera`, `permission_handler`.

## Alternativas consideradas

| Alternativa | Vantagens | Desvantagens | Motivo da rejeição |
| :-- | :-- | :-- | :-- |
| Nativo (Kotlin + Swift) | Máximo desempenho/aderência | Duplicação de esforço | Prazo e equipe |
| React Native / Expo | Ecossistema JS | UI customizada exige mais bibliotecas; desempenho de animações | Preferência por renderização própria do Flutter (Skia/Impeller) |
| PWA | Distribuição simples | Acesso limitado a câmera/deep links/background | Requisitos de dispositivo |

## Consequências

**Positivas:** produtividade; *hot reload*; consistência visual; um único conjunto de testes de UI/unidade.
**Negativas:** *toolchain* pesada (JDK 17, Android SDK, Gradle 9); dependência do ciclo de versões do Flutter; tamanho do binário.
**Riscos:** quebras de pacotes em atualizações → fixar versões no `pubspec.lock` e rodar CI a cada PR.

## Verificação

`flutter analyze` sem avisos e `flutter test` verde em CI ([TESTING](../TESTING.md)).

## Referências

[`app/README.md`](../../app/README.md) · [`docs/setup/`](../setup/windows.md)
