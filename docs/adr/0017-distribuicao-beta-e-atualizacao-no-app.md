# ADR-0017 — Distribuição beta por GitHub Actions/Releases e atualização dentro do app

* **Status:** Aceito
* **Data:** 2026-10-29
* **Decisores:** Desenvolvedor
* **Tags:** distribuição, CI/CD, Android, segurança

## Contexto

A conta de desenvolvedor da Google Play ficou travada na verificação de documentos, mas é preciso colocar o app em celulares reais (do desenvolvedor e de terceiros) e ver o uso em tempo real. Tudo precisa ser **gratuito**, sem a Play Console e usável por quem não é técnico. A primeira solução (publicar o APK à mão num release versionado) exigia comandos manuais a cada versão.

## Decisão

1. **Instalador = APK no GitHub Releases**, num release **rolante** `beta-latest` com **link fixo** (`…/releases/download/beta-latest/desperrengue.apk`). O testador recebe o link uma única vez.
2. **Publicação automática por CI** (`beta-release.yml`): em push para `main` e para a branch de trabalho (ou manualmente), roda `flutter analyze` + `flutter test` (portão de qualidade), compila o APK assinado e **recria** o release. Pushes só de documentação são ignorados. `concurrency` serializa as execuções.
3. **`versionCode` = minutos desde 1970** (`date +%s / 60`): monotônico sem estado e sem depender de commit para incrementar. O `versionName` vem do `pubspec.yaml`.
4. **Chave de assinatura SÓ do beta**, distinta da chave de upload da Play, entregue à CI por *Secrets* (`BETA_KEYSTORE_B64`, `BETA_KEYSTORE_PASSWORD`) e apagada do *runner* no fim. Limita o dano de um vazamento (colaboradores com escrita podem ler segredos alterando o *workflow*).
5. **Atualização dentro do app** (`UpdateService` + `UpdateGate`): consulta `releases/tags/beta-latest` com **ETag** (respostas 304 não contam no limite da API), compara o `build:` do texto do release com o `versionCode` instalado e mostra um cartão "Nova versão disponível". Checa ~4 s após abrir, a cada 2 min com o app aberto e ao voltar ao primeiro plano. **Só ativa com `--dart-define=BETA_UPDATES=true`** (a CI faz); builds locais e da Play ficam sem o recurso. O download abre o APK no navegador (sem a permissão `REQUEST_INSTALL_PACKAGES`, que atrapalharia a futura publicação na Play).
6. **Falhar fechado:** se análise ou testes quebrarem, nada é publicado e os testadores seguem com a versão anterior.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Firebase App Distribution | Projeto Firebase + convites por e-mail; painel extra | Mais etapas para o iniciante; fica como evolução |
| Hospedar o APK no Supabase Storage | Limites do plano e sem versionamento | GitHub Releases já dá link, histórico e SHA |
| Usar a chave de upload da Play na CI | Vazamento comprometeria a Play | Chave separada isola o risco |
| Plugin que instala o APK dentro do app (`ota_update`) | Exige `REQUEST_INSTALL_PACKAGES` (declaração na Play) | Abrir no navegador evita a permissão |
| Atualização silenciosa | O Android não permite fora da Play/MDM | Impossível; confirmamos com 2 toques |
| `versionCode` pelo número da execução (`run_number`) | Reinicia se o workflow for renomeado | Minutos desde 1970 não dependem do workflow |

## Consequências

* (+) Fluxo de um passo: `git push`; testadores avisados em minutos; link único.
* (+) Zero custo e zero ação manual além do push.
* (−) Não é instalação silenciosa (limite do Android).
* (−) O repositório é público: o APK é baixável por quem tiver o link.
* (−) Quem instalar o beta precisa desinstalá-lo para migrar para o app da Play (assinaturas diferentes).
* (−) A branch `fix/foundation-hardening` está na lista de gatilhos enquanto não é mesclada; remover depois.

## Referências

* `.github/workflows/beta-release.yml`; `app/lib/core/services/update_service.dart`; `app/lib/features/boot/update_gate.dart`; `app/test/update_test.dart`.
* Guia: [TESTE_COM_AMIGOS.md](../TESTE_COM_AMIGOS.md).
