# Publicação na Google Play — teste interno (somente convidados)

Este guia coloca o Desperrengue na Play Store **apenas para você e testadores
convidados** (faixa de **Teste interno**). O app não aparece na busca da loja nem
para o público. Cada testador instala pelo **link de convite**.

> **Por que "Teste interno"?** Até 100 testadores, **sem análise do Google**
> (disponível em minutos) e sem as exigências de publicação aberta. É o caminho
> certo para ir testando enquanto o app amadurece.

---

## 0. O que já está pronto no repositório

| Item | Estado |
|---|---|
| ID do aplicativo | `br.com.desperrengue.app` (**permanente** depois do 1º upload) |
| Nome exibido | `Desperrengue` |
| Assinatura de release | Configurada em `app/android/app/build.gradle.kts` (lê `app/android/key.properties`) |
| Chave de upload (`.jks`) | Gerada **fora do repositório**: `%USERPROFILE%\.desperrengue\keys\desperrengue-upload.jks` |
| Permissões | Internet, câmera (KYC), localização (endereço) |
| Login Google | OAuth pelo navegador via Supabase (não depende do SHA-1 do app) |
| Pacote | `app/build/app/outputs/bundle/release/app-release.aab` |

## 1. Faça backup da chave de upload (faça HOJE)

Copie a pasta `%USERPROFILE%\.desperrengue\keys\` (contém `desperrengue-upload.jks`
e `key.properties`) para um local seguro **fora do computador** (gerenciador de
senhas, pen drive, nuvem privada).

- Nunca envie esses arquivos ao GitHub nem por chat/e-mail.
- Se perder a chave de upload, é possível pedir *reset* ao Google, mas dá trabalho.
- Com o **Play App Signing** (ativo por padrão), o Google guarda a chave "de
  verdade"; a sua é só a **chave de upload**.

## 2. Criar a conta de desenvolvedor Google Play (uma vez só)

1. Acesse <https://play.google.com/console/signup>.
2. Entre com a conta Google que será a **dona** do app (use uma conta da empresa/projeto, não a pessoal de uso diário).
3. Escolha o tipo: **Pessoal** ou **Organização** (organização exige CNPJ e número D-U-N-S).
4. Pague a taxa única de **US$ 25**.
5. Faça a **verificação de identidade** (documento com foto; pode levar de horas a alguns dias).

> Contas **pessoais** criadas após nov/2023 precisam de um *teste fechado* com 12
> testadores por 14 dias **antes de publicar para o público**. Isso **não**
> atrapalha o teste interno de agora; só vale quando você for lançar de verdade.

## 3. Criar o app no Play Console

1. **Criar app** → nome `Desperrengue` → idioma padrão **Português (Brasil)**.
2. Tipo: **Aplicativo**; **Gratuito**.
3. Aceite as declarações e clique em **Criar app**.

## 4. Enviar o pacote (.aab) para o Teste interno

1. Menu **Testar e lançar → Testes → Teste interno**.
2. Aba **Testadores** → **Criar lista de e-mails** → informe os e-mails **Google (Gmail)** de cada pessoa → salvar → marque a lista.
3. **Criar nova versão**.
4. **Play App Signing**: aceite o padrão ("Usar a assinatura de apps do Google Play").
5. Arraste `app-release.aab` (caminho na seção 0).
6. Nome da versão: `0.1.0 (1)` · Notas: *"Primeira versão de testes."*
7. **Salvar → Revisar versão → Iniciar lançamento no teste interno**.

## 5. Convidar os testadores

1. Em **Teste interno → Testadores**, copie o **link de participação** ("Copiar link").
2. Envie o link aos testadores. Eles precisam:
   - abrir o link **logados com o mesmo Gmail** que você cadastrou;
   - tocar em **Tornar-se testador** e depois em **Baixar na Google Play**.
3. Atualizações chegam sozinhas pela Play Store.

## 6. Declarações do Play Console

Para o **teste interno** a Play pede pouco, mas ela vai exibir uma lista em
**Painel → Configurar o app**. Preencha o mínimo agora; precisará de tudo antes de publicar para o público:

| Seção | O que informar |
|---|---|
| **Política de privacidade** (URL pública) | Obrigatória por usarmos câmera/localização/dados pessoais. Publique um texto (pode ser uma página simples) e cole o link. |
| **Acesso ao app** | "Partes do app são restritas": informe uma **conta de teste** (e-mail/senha) para o revisor. Contas `@example.com` não recebem e-mail e não servem aqui: use um Gmail de teste. |
| **Anúncios** | Não contém anúncios. |
| **Classificação de conteúdo** | Responder o questionário (app utilitário; sem violência etc.). |
| **Público-alvo** | 18+ (serviços contratados por adultos). |
| **Segurança dos dados** | Declare: nome, e-mail, telefone, localização (aproximada/precisa), fotos/vídeos (KYC), identificadores. Dados criptografados em trânsito; usuário pode pedir exclusão. |
| **Aplicativo de notícias / saúde / finanças** | Marque "não". Observação: o pagamento atual é **simulado** (ambiente de demonstração). |
| **Exclusão de conta** | A Play exige um caminho de exclusão de conta para apps com cadastro. Está no [ROADMAP](ROADMAP.md); declare o e-mail `suporte@desperrengue.tech` enquanto não existe no app. |

## 7. Nova versão (cada atualização)

1. Em `app/pubspec.yaml` aumente o número depois do `+` (ex.: `0.1.1+2`). **O `versionCode` nunca pode repetir.**
2. Gere o pacote:
   ```powershell
   cd app
   flutter build appbundle --release
   ```
3. Envie o novo `.aab` em **Teste interno → Criar nova versão**.

## 8. Configurações do Supabase para o app de produção

- **Authentication → URL Configuration → Redirect URLs** devem conter
  `br.com.desperrengue.app://login-callback` e `desperrengue://onboarding/*`
  (já configurados).
- O app usa a **chave publicável** do Supabase (pública por design; a proteção
  está nas políticas RLS). Nenhuma chave secreta vai dentro do app.
- Como o backend é **compartilhado** (sem *staging*), os testadores gravam
  dados reais no mesmo banco. Oriente-os a usar apenas dados de teste.

## 9. Solução de problemas

| Sintoma | Causa provável | Solução |
|---|---|---|
| "Você precisa usar uma chave de assinatura diferente" ao enviar | `.aab` assinado com a chave de debug | Confirme que `app/android/key.properties` existe e rode `flutter build appbundle --release` de novo. |
| "Código de versão já usado" | `versionCode` repetido | Aumente o número depois do `+` no `pubspec.yaml`. |
| Testador não vê o app | E-mail diferente do cadastrado, ou não abriu o link de participação | Confirmar o Gmail e o passo "Tornar-se testador". |
| Login com Google abre e volta sem entrar | *Redirect URL* ausente no Supabase | Revisar a seção 8. |
| "Este app não está disponível" | Lançamento ainda em processamento | Aguarde alguns minutos após "Iniciar lançamento". |
