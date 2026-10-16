# 🏠 Home Automation (Multiplataforma)

Aplicativo moderno e multiplataforma construído em **Flutter** para controle e monitoramento centralizado de dispositivos inteligentes, unificando diferentes fabricantes (**LG ThinQ** e **Samsung SmartThings**) na mesma interface com suporte nativo para **Windows** e **Android**.

---

## ✨ Funcionalidades Principais

- **Hub Multi-Vendor Unificado**:
  - Lista dispositivos **LG** e **Samsung** na mesma tela.
  - Filtros rápidos por categoria: *Todos*, *Climatização*, *TV & Áudio*, *Luzes*, *Eletrodomésticos*.
  - Badges coloridas indicando o fabricante de cada dispositivo.
  - Botão liga/desliga universal direto no card.

- **Controle Avançado de Ar-Condicionado (LG ThinQ)**:
  - Ajuste fino de temperatura com precisão de **0.5 °C**.
  - 5 níveis de velocidade de ventilação (**Nível 1 a 5**).
  - Modos de operação: *Refrigerar*, *Aquecer*, *Ventilar*, *Desumidificar*, *Automático*.
  - Oscilação das aletas (*Swing* vertical).
  - Ligar/apagar a luz do display do aparelho.
  - Programação de desligamento inteligente com contagem em horas e minutos (ex: `⏱ 50m`).
  - Diagnóstico e saúde do filtro de ar com percentual restante de vida útil.

- **Controle de TV, Soundbar e Eletrodomésticos (Samsung SmartThings)**:
  - Ajuste de volume fino com botões `[-]` e `[+]` e barra deslizante (slider).
  - Botão de Mudo rápido.
  - Exibição de canal ativo e status de mídia.
  - Monitoramento de ciclo e tempo de lavadoras.
  - Opção de excluir dispositivos obsoletos diretamente pelo aplicativo.

---

## 🚀 Pré-requisitos

1. **Flutter SDK** (versão 3.24+ ou superior instalada e configurada no PATH).
2. **Para Windows Desktop**:
   - Visual Studio 2022 com a carga de trabalho *"Desenvolvimento para Desktop com C++"*.
3. **Para Android**:
   - Android SDK e ferramentas de linha de comando (`platform-tools` / `adb`).
   - Modo de Desenvolvedor e Depuração USB ativados no celular.

---

## ⚙️ Configuração Inicial

1. **Clonar o repositório**:
   ```bash
   git clone <URL_DO_REPOSITORIO>
   cd my-home-automation
   ```

2. **Instalar dependências**:
   ```bash
   flutter pub get
   ```

3. **Configurar as Chaves de API**:
   Crie um arquivo `.env` na raiz do projeto (ou configure diretamente pela tela de **Integrações** no próprio app):
   ```env
   # LG ThinQ
   LG_PAT_TOKEN=seu_token_pat_lg_aqui
   LG_BASE_URL=https://api-aic.lgthinq.com
   LG_COUNTRY=BR

   # Samsung SmartThings
   SAMSUNG_ST_PAT_TOKEN=seu_token_pat_smartthings_aqui
   ```
   > **Como gerar os tokens:**
   > - **LG ThinQ PAT**: acesse [connect-pat.lgthinq.com](https://connect-pat.lgthinq.com), faça login, crie um novo token com escopo de dispositivos e copie o código.
   > - **Samsung SmartThings PAT**: acesse [account.smartthings.com/tokens](https://account.smartthings.com/tokens), clique em *Generate new token* marcando as permissões de `Devices`.

---

## 🖥️ Executando e Instalando no Windows

### Modo de Desenvolvimento (Hot Reload)
Execute no terminal:
```powershell
flutter run -d windows
```

### Compilar o Executável de Produção (.exe)
Para gerar a versão final otimizada para Windows:
```powershell
flutter build windows --release
```
O executável standalone e suas DLLs estarão localizados em:
`build\windows\x64\runner\Release\`

---

## 📱 Executando e Instalando no Android

### Opção 1: Instalação Direta via Cabo USB (Recomendado)
1. Conecte o celular ao computador via cabo USB.
2. Ative as **Opções do Desenvolvedor** no celular (toque 7 vezes em *Número da Versão* nas configurações do aparelho).
3. Ative a **Depuração USB**.
4. Autorize a conexão no popup que surgir na tela do celular (*"Sempre permitir a partir deste computador"*).
5. No terminal do computador, execute:
   ```powershell
   flutter run -d android
   ```
   *(O Flutter compilará, instalará e abrirá o app automaticamente no seu smartphone).*

---

### Opção 2: Gerar o Instalador APK (Instalação Manual)
Para compilar os arquivos `.apk` prontos para instalação:
```powershell
flutter build apk --split-per-abi
```
Os arquivos gerados estarão em `build\app\outputs\flutter-apk\`:
- **`app-arm64-v8a-release.apk`**: Para a grande maioria dos celulares Android modernos (64 bits).
- **`app-armeabi-v7a-release.apk`**: Para celulares Android mais antigos (32 bits).

#### Como instalar o APK gerado:
- **Via linha de comando (ADB):**
  ```powershell
  & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
  ```
- **Ou envie o arquivo `app-arm64-v8a-release.apk`** para o seu celular (via WhatsApp Web, Google Drive ou cabo) e toque nele no gerenciador de arquivos para instalar.

---

## 🧪 Testes Automatizados

Para executar os testes unitários e de integração:
```bash
flutter test
```

Para verificar análise estática e padronização de código:
```bash
flutter analyze
```

---

## 📁 Estrutura do Projeto

```
my-home-automation/
├── lib/
│   ├── models/
│   │   └── unified_device.dart       # Modelo unificado multi-vendor (LG, Samsung, etc)
│   ├── services/
│   │   ├── lg_thinq_service.dart     # Cliente REST oficial da LG ThinQ
│   │   ├── smartthings_service.dart  # Cliente REST da Samsung SmartThings
│   │   └── device_manager_provider.dart # Gerenciamento de estado global e persistência
│   ├── screens/
│   │   ├── home_screen.dart          # Dashboard principal com categorias e status
│   │   ├── device_detail_screen.dart # Painel detalhado (Climatização, TV, Som, Luz)
│   │   └── connections_screen.dart   # Gerenciamento de tokens PAT (LG e Samsung)
│   └── main.dart                     # Entrada do app com temas Material 3 Claro/Escuro
├── test/                             # Testes unitários e mocks
└── pubspec.yaml                      # Dependências do Flutter
```
