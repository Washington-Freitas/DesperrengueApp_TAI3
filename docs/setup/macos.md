# Guia de Configuração e Provisionamento do Ambiente Flutter (macOS)

Este documento estabelece o procedimento arquitetural e sequencial para a configuração de um ambiente de desenvolvimento multiplataforma focado em **Flutter** operando em **macOS**. O rigor na execução de cada etapa é crucial para garantir a integridade da _toolchain_ de compilação, especialmente neste ambiente, que é o único capaz de orquestrar compilações simultâneas para Android e iOS.

Recomenda-se a execução de todos os comandos através do terminal nativo e do gestor de pacotes aprovado pela comunidade (Homebrew), garantindo a mitigação de conflitos de arquitetura (Intel x86_64 vs. Apple Silicon ARM64).

---

## 0. Preparação da Arquitetura (Apenas para Apple Silicon - M1/M2/M3/M4)

Se o seu Mac possui um processador da linha M (Apple Silicon), algumas ferramentas de compilação legadas do Android e dependências C++ ainda requerem a camada de tradução Rosetta 2.

**Procedimento de Instalação do Rosetta 2:**

1. Abra o **Terminal** (pressione `Cmd + Espaço`, digite Terminal e prima Enter).
2. Execute o seguinte comando para instalar o Rosetta 2 de forma silenciosa:
   ```zsh
   sudo softwareupdate --install-rosetta --agree-to-license
   ```

## 1. O Gestor de Pacotes do macOS: Homebrew

O Homebrew é o gestor de pacotes _de facto_ para o macOS. Ele atuará como o alicerce para instalar quase todas as nossas ferramentas de forma automatizada e limpa, gerindo as variáveis de ambiente internamente.

**Procedimento de Instalação:**

1. No terminal, execute o script oficial de instalação:
   ```zsh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
2. **Importante:** No final da instalação, o terminal exibirá instruções sob o título "Next steps". Terá de executar dois comandos fornecidos lá para adicionar o Homebrew ao seu PATH. Copie-os e execute-os.
3. Valide a instalação com:
   ```zsh
   brew --version
   ```

## 2. Sistema de Controle de Versão: Git & Xcode Command Line Tools

O macOS já traz um _stub_ do Git, mas para garantir que temos as ferramentas essenciais de compilação da Apple (C/C++, Make), precisamos instalar o Command Line Tools.

**Procedimento de Instalação:**

1. No terminal, execute:
   ```zsh
   xcode-select --install
   ```
2. Uma janela pop-up surgirá pedindo para instalar as ferramentas. Clique em **Instalar** e aceite os termos.
3. Valide a instalação do Git:
   ```zsh
   git --version
   ```

## 3. Ambiente de Desenvolvimento Integrado (IDE): Visual Studio Code

Utilizaremos o Homebrew Cask, que permite instalar aplicações gráficas diretamente via terminal.

**Procedimento de Instalação:**

1. Execute no terminal:
   ```zsh
   brew install --cask visual-studio-code
   ```
2. Abra o VS Code (agora disponível na sua pasta Aplicações).
3. Na barra lateral esquerda, clique no ícone de Extensões (ou prima `Cmd + Shift + X`).
4. Pesquise por **Dart** (publicada por Dart Code) e instale.
5. Pesquise por **Flutter** (publicada por Dart Code) e instale.

## 4. Java Development Kit (JDK 17)

O Gradle requer uma versão estável do Java para compilar o código nativo do Android. Utilizaremos o OpenJDK através do Homebrew.

**Procedimento de Instalação:**

1. No terminal, execute:
   ```zsh
   brew install openjdk@17
   ```
2. Para que o sistema reconheça este JDK globalmente, crie um link simbólico executando:
   ```zsh
   sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
   ```
   _(Nota: Se usar Mac Intel, o caminho do homebrew será `/usr/local/opt/...`)_

## 5. A Toolchain Exclusiva da Apple: Xcode e CocoaPods

Para compilar e emular aplicações para iOS, o Xcode é estritamente obrigatório.

**Procedimento de Instalação do Xcode:**

1. Abra a **App Store** no seu Mac.
2. Pesquise por **Xcode** e instale (Atenção: é um ficheiro grande, pode demorar).
3. Após a instalação, abra o Xcode pelo menos uma vez para instalar componentes adicionais e feche-o.
4. No terminal, garanta que o caminho de desenvolvimento está apontado corretamente e aceite a licença:
   ```zsh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```

**Instalação do CocoaPods:**
O CocoaPods é o gestor de dependências do ecossistema iOS. O Flutter usa-o intensivamente para integrar plugins nativos.

1. No terminal, instale-o via Homebrew:
   ```zsh
   brew install cocoapods
   ```

## 6. Android Studio & Emulação Virtual

O Android Studio fornecerá a toolchain de compilação para a vertente Android da sua aplicação.

**Procedimento de Instalação:**

1. Execute no terminal:
   ```zsh
   brew install --cask android-studio
   ```
2. Abra o Android Studio (pela pasta Aplicações).
3. No ecrã "Import Android Studio Settings", selecione "Do not import settings" e clique em OK.
4. Avance no **Setup Wizard** (Standard Install), aceite todas as licenças (android-sdk-license, etc.) e aguarde o download do SDK.

**Criação do Dispositivo Virtual (AVD):**

1. No menu principal do Android Studio, procure por **Virtual Device Manager**.
2. Clique em Create Device, escolha o modelo **Pixel 8** e avance.
3. Transfira a imagem de sistema recomendada (API 34 ou superior), aceite os termos e conclua a criação.

## 7. O Core Framework: Flutter SDK

**Procedimento de Instalação e Configuração do PATH:**

1. Crie um diretório dedicado na sua pasta de utilizador:
   ```zsh
   mkdir ~/development
   cd ~/development
   ```
2. Aceda a https://flutter.dev/, vá a _Get Started -> macOS_, e baixe o ficheiro `.zip` estável correspondente ao seu processador (Apple Silicon para M-Series, ou Intel).
3. Extraia o ficheiro para o diretório criado (pode fazer duplo clique no `.zip` no Finder e arrastar a pasta `flutter` para `~/development`).
4. **Crucial (Injeção no PATH):** O macOS moderno usa o `zsh` como terminal padrão. Abra o ficheiro de configuração:
   ```zsh
   nano ~/.zshrc
   ```
5. Adicione a seguinte linha ao final do ficheiro:
   ```zsh
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
6. Guarde (`Ctrl + O`, depois `Enter`) e saia (`Ctrl + X`).
7. Recarregue as configurações do terminal:
   ```zsh
   source ~/.zshrc
   ```

**Diagnóstico (Flutter Doctor) e Licenças:**

1. Execute a análise de dependências:
   ```zsh
   flutter doctor
   ```
2. Se o _doctor_ reportar falta do "cmdline-tools", abra o Android Studio -> SDK Manager -> separador SDK Tools, marque _Android SDK Command-line Tools (latest)_, aplique e feche.
3. Aceite as licenças do Android:
   ```zsh
   flutter doctor --android-licenses
   ```
   (Escreva `y` e Enter para todos).
4. Execute `flutter doctor` novamente. Deverá ter vistos verdes em "Flutter", "Android toolchain", "Xcode" e "Android Studio".

## 8. Inicialização de um Novo Projeto

A infraestrutura está agora provisionada para desenvolvimento _cross-platform_ total (iOS e Android).

**Procedimento de Criação:**

1. No terminal, navegue até à pasta onde guarda os seus projetos:
   ```zsh
   mkdir ~/Projetos
   cd ~/Projetos
   ```
2. Crie a arquitetura base do projeto:
   ```zsh
   flutter create nome_do_projeto
   ```
3. Navegue para dentro do projeto:
   ```zsh
   cd nome_do_projeto
   ```
4. Lance o VS Code focado na raiz do projeto:
   ```zsh
   code .
   ```

No VS Code, no canto inferior direito, poderá agora selecionar não só o emulador **Android (Pixel)**, mas também o **iOS Simulator (iPhone)**, dependendo do _target_ que deseja testar. O ambiente está homologado para produção.
