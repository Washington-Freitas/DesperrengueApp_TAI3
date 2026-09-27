# Guia de Configuração e Provisionamento do Ambiente Flutter (Linux/Ubuntu)

Este documento estabelece o procedimento arquitetural e sequencial para a configuração de um ambiente de desenvolvimento multiplataforma focado em **Flutter** operando em sistemas baseados em Linux (com foco em distribuições Debian/Ubuntu). O rigor na execução de cada etapa é crucial para garantir a integridade da _toolchain_ de compilação, a correta resolução de dependências, permissões de sistema e a mitigação de conflitos no sistema operacional.

Recomenda-se a execução de todos os downloads e instalações através dos repositórios oficiais e gestores de pacotes homologados, garantindo a segurança e a validação criptográfica dos pacotes instalados.

---

## 1. Sistema de Controle de Versão: Git

O **Git** é um sistema de controle de versão distribuído, fundamental na engenharia de software para rastrear alterações no código-fonte. O Flutter exige o Git não apenas para versionamento próprio do utilizador, mas também como motor interno para descarregar pacotes, gerir dependências e atualizar o próprio _framework_.

**Procedimento de Instalação:**

1. Abra o emulador de terminal do seu sistema (atalho padrão: `Ctrl + Alt + T`).
2. Atualize o índice do gestor de pacotes e instale o Git executando:
   ```bash
   sudo apt update && sudo apt install git -y
   ```
3. _(Opcional)_ Configure as suas credenciais globais:
   ```bash
   git config --global user.name "O Seu Nome"
   git config --global user.email "seu.email@exemplo.com"
   ```

**Validação:**

1. No terminal, execute o comando:
   ```bash
   git --version
   ```
2. Se o terminal retornar a versão do Git (ex: `git version 2.34.1`), a instalação foi bem-sucedida. Em ambientes Linux, a injeção no PATH é resolvida nativamente pelo gestor de pacotes.

## 2. Ambiente de Desenvolvimento Integrado (IDE): Visual Studio Code

O VS Code é um editor de código-fonte altamente extensível e leve, considerado o padrão da indústria para o desenvolvimento em Flutter devido à sua vasta telemetria de extensões e depuração integrada.

**Procedimento de Instalação:**
A forma mais limpa e isolada de instalar o VS Code no Linux é através do gestor de pacotes _Snap_, mantido pela Canonical.

1. No terminal, execute:
   ```bash
   sudo snap install --classic code
   ```
2. Graças à instalação via snap clássico, o VS Code é automaticamente injetado no PATH e pode ser evocado a partir de qualquer terminal utilizando o comando `code .`.

**Instalação de Extensões Obrigatórias:**

1. Abra o VS Code.
2. Na barra lateral esquerda, clique no ícone de Extensões (ou prima `Ctrl + Shift + X`).
3. Pesquise por **Dart** (publicada por Dart Code) e instale.
4. Pesquise por **Flutter** (publicada por Dart Code) e instale.

## 3. Gestor de Pacotes do Linux: APT e Snap (Nativos)

Diferente do Windows (onde configurámos o Chocolatey), sistemas Linux possuem gestores de pacotes nativos e robustos. O `apt` (Advanced Package Tool) e o `snap` serão os responsáveis por instalar ferramentas e dependências ao nível da máquina.

**Preparação das Bibliotecas Base (Pré-requisitos C/C++):**
O Flutter compila código nativo e necessita de bibliotecas de desenvolvimento essenciais do Linux.

1. Execute no terminal para garantir que as ferramentas de compilação essenciais estão presentes:
   ```bash
   sudo apt install curl file git unzip xz-utils zip libglu1-mesa -y
   ```

## 4. Java Development Kit (OpenJDK)

A máquina virtual Java e as suas ferramentas de compilação são um pré-requisito estrito para o Android SDK. O Gradle (sistema de build do Android) requer uma versão estável do Java para compilar o código nativo. No Linux, utilizaremos o OpenJDK.

**Procedimento de Instalação:**

1. No terminal, execute o comando para instalar o OpenJDK 17 (versão atualmente recomendada para estabilidade com o Gradle moderno):
   ```bash
   sudo apt install openjdk-17-jdk -y
   ```
2. **Validação:** Ainda no terminal, execute:
   ```bash
   java -version
   ```
   Deverá ser impresso o output do OpenJDK 64-Bit Server VM.

## 5. Android Studio & Emulação Virtual

O Android Studio fornece toda a toolchain de desenvolvimento Android, incluindo os compiladores, a ponte de depuração (ADB) e os emuladores virtuais.

**Aceleração de Hardware para o Emulador (KVM):**
No Linux, para que o emulador corra fluidamente, é estritamente necessário configurar o KVM (Kernel-based Virtual Machine).

1. Instale os pacotes KVM:
   ```bash
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils -y
   ```
2. Adicione o seu utilizador aos grupos `libvirt` e `kvm`:
   ```bash
   sudo adduser $USER libvirt
   sudo adduser $USER kvm
   ```
   _(Nota: Poderá ser necessário reiniciar o computador para que os grupos tenham efeito)._

**Procedimento de Instalação do Android Studio via Snap:**

1. Para uma gestão simplificada no Linux, execute:
   ```bash
   sudo snap install android-studio --classic
   ```
2. Inicie o Android Studio procurando-o no menu de aplicações do seu sistema ou digitando `android-studio` no terminal.
3. No ecrã "Import Android Studio Settings", selecione "Do not import settings" e clique em OK.
4. Se questionado sobre partilha de dados (Data Sharing), selecione "Don't send".

**Android Studio Setup Wizard:**

1. Avance no ecrã de Welcome (Next).
2. Selecione o tipo de instalação **Standard** e avance.
3. Escolha o tema da sua preferência e avance.
4. No ecrã License Agreement, selecione as licenças na barra lateral e clique em **Accept** para cada uma delas.
5. Clique em Finish. O IDE fará o download do SDK do Android. Aguarde até finalizar.

**Criação do Dispositivo Virtual (AVD):**

1. No menu principal do Android Studio, procure por Virtual Device Manager (ou Device Manager).
2. Clique em Create Device.
3. Selecione o modelo **Pixel 8** e avance.
4. No separador de System Image, faça o download da imagem mais recente (ex: API 34). Aguarde a transferência, aceite os termos e avance com Finish.
5. Em AVD Name, mantenha "Pixel 8" e conclua (Finish).

**Integração de Plugins no Android Studio:**

1. No menu inicial, clique no separador **Plugins** na barra lateral esquerda.
2. Pesquise e instale os plugins **Dart** e **Flutter**.
3. Clique em Restart IDE para consolidar a integração.

## 6. O Core Framework: Flutter SDK

O Flutter é o SDK de UI da Google projetado para criar aplicações compiladas nativamente.

**Procedimento de Instalação e Configuração do PATH:**

1. Crie um diretório dedicado para desenvolvimento na sua pasta de utilizador:
   ```bash
   mkdir ~/development
   cd ~/development
   ```
2. Aceda a https://flutter.dev/, navegue até Get Started -> Linux, e transfira o ficheiro compactado (ex: `flutter_linux_x.x.x-stable.tar.xz`).
3. Extraia o ficheiro para o diretório criado:
   ```bash
   tar xf ~/Downloads/flutter_linux_*.tar.xz -C ~/development/
   ```
4. **Crucial (Injeção no PATH):** Para que os comandos do Flutter estejam disponíveis globalmente, precisamos adicionar o binário ao perfil do seu _shell_ (geralmente Bash ou Zsh).
   Abra o ficheiro `.bashrc` (ou `.zshrc`) no editor nano:
   ```bash
   nano ~/.bashrc
   ```
5. Navegue com as setas até ao final do ficheiro e cole a seguinte linha:
   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
6. Guarde (prima `Ctrl + O`, depois `Enter`) e saia (prima `Ctrl + X`).
7. Atualize a janela do terminal atual:
   ```bash
   source ~/.bashrc
   ```

**Diagnóstico e Resolução de Dependências (Flutter Doctor):**
O utilitário `flutter doctor` faz uma análise microscópica da sua toolchain.

1. No terminal, execute:
   ```bash
   flutter doctor
   ```

**Resolução no Android Studio (SDK Manager):**
Caso o _doctor_ aponte a falta de "cmdline-tools":

1. Abra o Android Studio e vá a SDK Manager.
2. No separador **SDK Tools**, marque:
   - Android SDK Command-line Tools (latest)
3. Clique em Apply, aguarde o download, clique em Finish e feche o Android Studio.

**Resolução de Licenças Android:**

1. No terminal, execute a rotina de aceitação de licenças:
   ```bash
   flutter doctor --android-licenses
   ```
   Escreva `y` (Yes) e prima Enter para todos os contratos apresentados.

**Validação Final:**

1. Execute `flutter doctor` novamente. Todos os itens cruciais para desenvolvimento Mobile devem apresentar um visto verde `[v]`.
2. _(Nota: O aviso sobre "Linux toolchain" refere-se à compilação de aplicações desktop nativas para Linux usando GTK/C++. Pode ser ignorado se o seu foco for apenas Android/iOS/Web)._

## 7. Inicialização de um Novo Projeto

A infraestrutura está agora perfeitamente alinhada e aprovisionada no seu ambiente Linux.

**Procedimento de Criação:**

1. No terminal, navegue até à pasta onde deseja guardar os seus projetos. Exemplo:
   ```bash
   mkdir ~/Projetos
   cd ~/Projetos
   ```
2. Evoque o motor do Flutter para desenhar a arquitetura base do projeto (utilize _snake_case_):
   ```bash
   flutter create nome_do_projeto
   ```
3. Navegue para dentro da pasta do novo projeto:
   ```bash
   cd nome_do_projeto
   ```
4. Lance o VS Code focado na raiz do projeto:
   ```bash
   code .
   ```

O workspace no Ambiente de Desenvolvimento Integrado (IDE) Visual Studio Code será inicializado. A instanciação da máquina virtual, correspondente ao emulador do dispositivo Pixel 8, deve ser orquestrada via gerenciador de devices, interface alocada na extremidade inferior direita da ferramenta. Subsequentemente, o processo de compilação, acoplamento do debugger e execução do artefato de software é disparado por meio do acionamento da tecla de atalho F5. Ressalta-se que a atual infraestrutura do ambiente encontra-se rigorosamente homologada e validada para implantação em nível de produção (production-ready).
