# Guia de Configuração e Provisionamento do Ambiente Flutter (Windows)

Este documento estabelece o procedimento arquitetural e sequencial para a configuração de um ambiente de desenvolvimento multiplataforma focado em **Flutter**. O rigor na execução de cada etapa é crucial para garantir a integridade da _toolchain_ de compilação, a correta resolução de dependências e a mitigação de conflitos no sistema operacional Windows.

Recomenda-se a execução de todos os downloads exclusivamente através dos repositórios e domínios oficiais citados, garantindo a segurança e a validação criptográfica dos pacotes instalados.

---

## 1. Sistema de Controle de Versão: Git

O **Git** é um sistema de controle de versão distribuído, fundamental na engenharia de software para rastrear alterações no código-fonte, coordenar o trabalho em equipa e gerir o histórico do projeto. O Flutter exige o Git não apenas para versionamento próprio do utilizador, mas também como motor interno para descarregar pacotes e atualizar o próprio _framework_.

**Procedimento de Instalação:**

1. Aceda ao repositório oficial: [https://git-scm.com/install/windows](https://git-scm.com/install/windows).
2. Execute o instalador transferido.
3. Prossiga com as configurações padrão. Se desejar, marque a opção **"(NEW!) Add a Git Bash Profile to Windows Terminal"** para melhor integração de linha de comando.
4. No último ecrã de instalação, desmarque a caixa **"View Release Notes"** e clique em _Finish_.

**Validação e Configuração de Variáveis de Ambiente (PATH):**

1. Abra o Terminal do Windows (ou Prompt de Comando) como **Administrador**.
2. Execute o comando:
   ```bash
   git --version
   ```
3. Se o terminal retornar a versão do Git, a instalação foi bem-sucedida.
4. Se o comando não for reconhecido, será necessário injetar o binário no PATH do Windows:
   - Pressione a tecla Windows e pesquise por "Editar as variáveis de ambiente do sistema".
   - Clique no botão Variáveis de Ambiente... no canto inferior direito.
   - Na secção "Variáveis do sistema", selecione a variável Path e clique em Editar.
   - Clique em Novo e cole o diretório dos binários do Git (por norma: `C:\Program Files\Git\cmd`).
   - Clique em OK em todas as janelas para guardar e reinicie o terminal.

## 2. Ambiente de Desenvolvimento Integrado (IDE): Visual Studio Code

O VS Code é um editor de código-fonte altamente extensível e leve, considerado o padrão da indústria para o desenvolvimento em Flutter devido à sua vasta telemetria de extensões e depuração integrada.

**Procedimento de Instalação:**

1. Aceda ao site oficial: https://code.visualstudio.com/docs/setup/windows.
2. Transfira o instalador e execute-o.
3. No ecrã "Selecionar Tarefas Adicionais", certifique-se de marcar as seguintes opções cruciais para a usabilidade do sistema:
   - [x] Criar um atalho na área de trabalho (Opcional)
   - [x] Adicione a ação "Abrir com Code" ao menu de contexto de arquivo do Windows Explorer
   - [x] Adicione a ação "Abrir com Code" ao menu de contexto de diretório do Windows Explorer
   - [x] Registre Code como um editor para tipos de arquivos suportados
   - [x] Adicione em PATH (disponível após reiniciar)
4. Após instalar, pode desmarcar "Iniciar o Visual Studio Code" e clicar em Concluir. Graças à opção "Adicione em PATH", o VS Code pode agora ser evocado a partir de qualquer terminal utilizando o comando `code .`.

**Instalação de Extensões Obrigatórias:**

1. Abra o VS Code.
2. Na barra lateral esquerda, clique no ícone de Extensões (ou prima Ctrl + Shift + X).
3. Pesquise por Dart (publicada por Dart Code) e instale.
4. Pesquise por Flutter (publicada por Dart Code) e instale.

## 3. Gestor de Pacotes do Windows: Chocolatey

O Chocolatey atua no Windows de forma análoga ao apt no Linux ou brew no macOS. Serve para instalar ferramentas e dependências de software ao nível da máquina diretamente via linha de comando, automatizando a gestão de binários.

**Procedimento de Instalação:**

1. O Windows, por questões de segurança, restringe a execução de scripts não assinados. Precisamos de alterar esta política temporariamente.
2. Pressione a tecla Windows, digite PowerShell, clique com o botão direito e selecione "Executar como administrador".
3. Execute o comando para libertar a política de execução:
   ```powershell
   Set-ExecutionPolicy Unrestricted
   ```
   _(Pressione S para confirmar)._
4. Feche o PowerShell e abra-o novamente como Administrador (para garantir que a nova política está ativa).
5. Aceda a https://chocolatey.org/install, copie o comando de instalação oficial fornecido no site e cole-o no PowerShell. Pressione Enter.
6. Aguarde a extração e configuração. No final, teste a instalação com:
   ```powershell
   choco -?
   ```

## 4. Java Development Kit (JDK 11)

A máquina virtual Java e as suas ferramentas de compilação são um pré-requisito estrito para o Android SDK. O Gradle (sistema de build do Android) requer uma versão estável do Java para compilar o código nativo.

**Procedimento de Instalação:**

1. Aceda ao arquivo oficial da Oracle: https://www.oracle.com/br/java/technologies/javase/jdk11-archive-downloads.html.
2. Procure pela secção Windows e faça o download do ficheiro que termina em x64 Installer (evite a versão Compressed Archive).
3. **Nota:** Será solicitado o login na Oracle. Caso não possua conta, crie uma (é um processo gratuito e rápido).
4. Execute o instalador transferido, clique em Next mantendo os caminhos padrão, e no final clique em Close.
5. **Validação:** Abra o terminal e execute:
   ```bash
   java --version
   ```
   Deverá ser impresso o output da versão 11 do Java SE Runtime Environment.

## 5. Android Studio & Emulação Virtual

O Android Studio não será usado ativamente como editor de código primário (já configurámos o VS Code para isso), mas é a entidade que fornece toda a toolchain de desenvolvimento Android, incluindo os compiladores, a ponte de depuração (ADB) e os emuladores virtuais.

**Procedimento de Instalação e Configuração Base:**

1. Aceda a https://developer.android.com/studio?hl=pt-br, aceite a licença e transfira o executável.
2. Execute o instalador. Quando solicitado a escolha de componentes, desmarque a opção "Android Virtual Device" temporariamente (criaremos um especificamente mais tarde).
3. Siga com Next até Install e, posteriormente, Finish, garantindo que a opção Start Android Studio está marcada.
4. No ecrã Import Android Studio Settings, selecione "Do not import settings" e clique em OK.
5. Se questionado sobre partilha de dados (Data Sharing), selecione "Don't send".

**Android Studio Setup Wizard:**

1. Avance no ecrã de Welcome (Next).
2. Selecione o tipo de instalação Standard e avance.
3. Escolha o tema da sua preferência (Darcula ou Light).
4. No ecrã Verify Settings, clique em Next.
5. No ecrã License Agreement, selecione android-sdk-license na barra lateral e clique em Accept. Repita o processo de aceitação para a intel-android-extra-license.
6. Clique em Finish. O IDE fará o download de gigabytes de dados do SDK. Aguarde até finalizar e clique em Finish novamente.

**Criação do Dispositivo Virtual (AVD):**

1. No menu principal do Android Studio, procure por Virtual Device Manager (ou Device Manager).
2. Clique em Create Device.
3. Em Choose a device definition, selecione o modelo Pixel 8 e avance.
4. No separador de System Image, faça o download da versão "R" (API 30). Aguarde a transferência, avance com Finish, selecione a imagem "R" acabada de descarregar e clique em Next.
5. Em AVD Name, mantenha "Pixel 8", assegure que a orientação está em Portrait e conclua (Finish).
6. Na lista do Device Manager, clique no botão de Play (▶) ao lado do Pixel 8 para arrancar o emulador pela primeira vez.

**Integração de Plugins no Android Studio:**
Mesmo não sendo o IDE principal, o Android Studio precisa de compreender o ecossistema Dart/Flutter para orquestrar as builds.

1. No menu inicial do Android Studio, clique no separador Plugins na barra lateral esquerda.
2. Pesquise por Dart (geralmente a primeira opção), instale e aceite os termos.
3. Pesquise por Flutter, instale e aceite os termos.
4. Clique em Restart IDE para consolidar a integração.

## 6. O Core Framework: Flutter SDK

O Flutter é o SDK de UI da Google projetado para criar aplicações compiladas nativamente para mobile, web e desktop a partir de uma única base de código.

**Procedimento de Instalação:**

1. Aceda a https://flutter.dev/, navegue até Get Started e transfira a versão estável para Windows (ficheiro .zip).
2. **Crucial:** Extraia o ficheiro .zip diretamente para o diretório raiz do sistema: `C:\`. Ao finalizar, deve ter uma pasta exata em `C:\flutter`.
3. Navegue até `C:\flutter\bin` e copie este caminho na barra de endereços do explorador de ficheiros.
4. Tal como fizemos com o Git, injete o Flutter no PATH:
   - Pesquise no Windows por "Editar as variáveis de ambiente do sistema".
   - Clique em Variáveis de Ambiente... -> Em "Variáveis do sistema", edite o Path -> Clique em Novo -> Cole `C:\flutter\bin`.
   - Pressione OK em todas as janelas.

**Diagnóstico e Resolução de Dependências (Flutter Doctor):**
O utilitário `flutter doctor` faz uma análise microscópica da sua toolchain. O objetivo é ter todos os requisitos com um check verde `[v]`.

1. Abra o Terminal de Comando (CMD) como Administrador e execute:
   ```bash
   flutter doctor
   ```
   Inicialmente, o sistema reportará falhas. As mais comuns incluem a ausência de cmdline-tools e status de licenciamento Android desconhecido.

**Resolução no Android Studio (SDK Manager):**

1. Abra o Android Studio. Procure a opção SDK Manager (geralmente sob More Actions ou num ícone de engrenagem).
2. Vá ao separador SDK Tools.
3. Certifique-se de que as seguintes caixas estão marcadas:
   - Android SDK Build-Tools
   - Android SDK Command-line Tools (latest)
   - Android Emulator
   - Android SDK Platform-Tools
   - Intel x86 Emulator Accelerator (HAXM installer)
4. Clique em Apply e depois em OK. O Android Studio fará o download e instalação destas ferramentas core. Após finalizar, clique em Finish e feche o Android Studio.

**Resolução de Licenças Android:**

1. No terminal CMD (Administrador), execute a rotina de aceitação de licenças:
   ```bash
   flutter doctor --android-licenses
   ```
   O terminal apresentará vários contratos. Escreva `y` (Yes) e prima Enter para todos os termos até o processo finalizar.

**Validação Final:**

1. Execute `flutter doctor` novamente.
2. Todos os itens cruciais para desenvolvimento Mobile devem apresentar um visto verde `[v]`.
3. **Nota Arquitetural:** O aviso vermelho referente a _Visual Studio - develop for Windows_ pode ser categoricamente ignorado, uma vez que a build target do projeto é Mobile (Android/iOS) e não aplicações de ambiente de trabalho nativas do Windows. Feche o terminal.

## 7. Inicialização de um Novo Projeto

A infraestrutura está agora perfeitamente alinhada. O ciclo de vida de um novo software Flutter inicia-se via interface de linha de comando.

**Procedimento de Criação:**

1. Abra o terminal (PowerShell ou Git Bash) e navegue, utilizando o comando de alteração de diretório (`cd`), até à pasta raiz onde deseja guardar os seus projetos. Exemplo:
   ```bash
   cd C:\Projetos
   ```
2. Evoque o motor do Flutter para desenhar o scaffolding (estrutura base) do projeto. Substitua "nome_do_projeto" pelo nome pretendido (utilize snake_case, sem espaços ou maiúsculas):
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
