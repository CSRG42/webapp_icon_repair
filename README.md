# Corretor Web App

Ferramenta Bash para **corrigir automaticamente os ícones de Web Apps e atalhos `.desktop` presentes na Área de Trabalho do Linux**.

O projeto foi criado principalmente para resolver um problema comum no **Zorin OS**: Web Apps instalados pelo navegador aparecem normalmente no menu do sistema, com seus respectivos ícones, mas ao serem adicionados novamente à Área de Trabalho o atalho pode aparecer sem o ícone correto.

O **Corretor Web App** procura o ícone real instalado no sistema e atualiza o atalho existente sem recriá-lo.

---

## 📌 Objetivo

Corrigir atalhos de Web Apps que apresentam problemas com a referência:

```ini
Icon=nome-do-icone
```

quando o sistema não consegue localizar corretamente o arquivo do ícone.

O programa transforma a referência em um caminho válido para o arquivo do ícone, por exemplo:

```ini
Icon=brave-agimnkijcaahngcdmfeangaknmldooml-Default
```

para:

```ini
Icon=/home/usuario/.local/share/icons/hicolor/256x256/apps/brave-agimnkijcaahngcdmfeangaknmldooml-Default.png
```

---

## ✨ Características

* Corrige ícones de atalhos `.desktop`.
* Atua somente nos atalhos existentes na **Área de Trabalho**.
* Não cria novos atalhos.
* Não remove atalhos.
* Não altera Web Apps que estão somente no menu do sistema.
* Não reinstala navegadores ou Web Apps.
* Faz backup antes de modificar um arquivo.
* Procura automaticamente os arquivos de ícone instalados.
* Prioriza ícones de maior resolução.
* Suporta PNG, SVG, SVGZ, XPM, ICO e WEBP.
* Pode funcionar com Web Apps de diferentes navegadores.
* Pode ser executado várias vezes com segurança.
* Ignora atalhos que já possuem um caminho válido para o ícone.
* Mantém os demais dados do arquivo `.desktop`.

---

## 🌐 Navegadores

O projeto não depende exclusivamente do Brave.

Ele pode localizar ícones utilizados por Web Apps de diferentes navegadores, desde que o navegador tenha instalado o respectivo ícone em um dos diretórios pesquisados pelo script.

Exemplos:

* Brave
* Google Chrome
* Chromium
* Microsoft Edge
* Vivaldi
* Outros navegadores baseados em Chromium

---

## 🖥️ Sistema

O script utiliza ferramentas padrão do ambiente Linux, como:

* Bash
* `find`
* `sed`
* `grep`
* `cp`
* `xdg-user-dir`
* `gio`

---

## 📁 Estrutura

Exemplo de instalação:

```text
~
├── atualizar_icones_webapps.sh
└── Área de trabalho/
    ├── WebApp-Netflix5478.desktop
    ├── WebApp-Chatgpt4420.desktop
    ├── WebApp-NFL6906.desktop
    └── ...
```

Quando um atalho é alterado, o backup é armazenado em:

```text
Área de trabalho/.backup_icones_webapps/
```

---

## 🚀 Instalação

Clone ou copie o projeto para seu computador.

Dê permissão de execução:

```bash
chmod +x atualizar_icones_webapps.sh
```

---

## ▶️ Uso

Execute:

```bash
./atualizar_icones_webapps.sh
```

Ou, caso o script esteja no diretório pessoal:

```bash
~/atualizar_icones_webapps.sh
```

O programa identifica automaticamente a Área de Trabalho através de:

```bash
xdg-user-dir DESKTOP
```

Isso evita depender diretamente do nome da pasta, que pode ser:

```text
Desktop
```

ou:

```text
Área de trabalho
```

---

## 🔍 Funcionamento

Para cada arquivo:

```text
*.desktop
```

encontrado na Área de Trabalho, o programa:

### 1. Verifica o arquivo

Confirma se o arquivo possui:

```ini
[Desktop Entry]
```

Arquivos que não forem Desktop Entries válidos são ignorados.

### 2. Obtém as informações

O programa lê:

```ini
Name=
Exec=
Icon=
```

O `Exec=` é preservado e não é alterado.

### 3. Verifica o ícone

Se `Icon=` já apontar diretamente para um arquivo existente, o atalho não é alterado.

### 4. Procura o ícone

O programa pesquisa nos diretórios:

```text
~/.local/share/icons
~/.icons
/usr/local/share/icons
/usr/share/icons
```

### 5. Prioriza resolução

A busca tenta encontrar primeiro os tamanhos maiores:

```text
512x512
384x384
256x256
192x192
180x180
160x160
144x144
128x128
96x96
72x72
64x64
48x48
36x36
32x32
24x24
16x16
```

### 6. Cria backup

Antes de modificar o `.desktop`, o arquivo original é copiado para:

```text
Área de trabalho/.backup_icones_webapps/
```

### 7. Atualiza o `Icon=`

Somente a linha:

```ini
Icon=
```

é alterada.

As demais configurações do Web App permanecem intactas.

---

## 🛡️ Segurança

O projeto foi desenvolvido para ser conservador.

Ele **não faz**:

* instalação de aplicativos;
* remoção de aplicativos;
* alteração de configurações do navegador;
* alteração do comando `Exec=`;
* alteração do `StartupWMClass`;
* alteração das ações do Web App;
* criação de novos atalhos;
* exclusão de atalhos.

A alteração é limitada ao arquivo `.desktop` que já existe na Área de Trabalho.

---

## 💾 Backup

Antes de modificar um atalho, o programa cria uma cópia em:

```text
.backup_icones_webapps
```

Exemplo:

```text
Área de trabalho/
├── brave-agimnkijcaahngcdmfeangaknmldooml-Default.desktop
└── .backup_icones_webapps/
    └── brave-agimnkijcaahngcdmfeangaknmldooml-Default.desktop
```

O backup original não é sobrescrito durante execuções posteriores.

---

## 🔄 Exemplo

Antes:

```ini
[Desktop Entry]
Version=1.0
Terminal=false
Type=Application
Name=YouTube
Exec=/opt/brave.com/brave/brave-browser --profile-directory=Default --app-id=agimnkijcaahngcdmfeangaknmldooml
Icon=brave-agimnkijcaahngcdmfeangaknmldooml-Default
StartupWMClass=crx_agimnkijcaahngcdmfeangaknmldooml
```

Depois:

```ini
[Desktop Entry]
Version=1.0
Terminal=false
Type=Application
Name=YouTube
Exec=/opt/brave.com/brave/brave-browser --profile-directory=Default --app-id=agimnkijcaahngcdmfeangaknmldooml
Icon=/home/cesar/.local/share/icons/hicolor/256x256/apps/brave-agimnkijcaahngcdmfeangaknmldooml-Default.png
StartupWMClass=crx_agimnkijcaahngcdmfeangaknmldooml
```

O restante do arquivo permanece intacto.

---

## 📊 Relatório

Ao terminar, o script apresenta um resumo semelhante a:

```text
==============================================
RESULTADO
==============================================

Atalhos encontrados : 13
Ícones atualizados  : 1
Ignorados           : 12

Backup:
/home/cesar/Área de trabalho/.backup_icones_webapps

Concluído.
```

Isso permite verificar rapidamente quantos atalhos foram encontrados e quantos realmente precisaram de correção.

---

## ⚠️ Limitações

O projeto atualmente trabalha somente com arquivos:

```text
*.desktop
```

que estejam diretamente na Área de Trabalho.

Ele não procura atalhos dentro de subpastas.

Também não cria um `.desktop` caso o Web App esteja instalado no navegador mas não tenha um atalho na Área de Trabalho.

Essa é uma decisão intencional do projeto para evitar alterações indesejadas.

---

## 🔮 Possíveis melhorias futuras

Algumas funcionalidades podem ser adicionadas em versões futuras:

* Interface gráfica utilizando YAD.
* Modo `--dry-run` para apenas verificar sem modificar.
* Opção de restaurar backups.
* Relatório detalhado.
* Detecção mais específica de Web Apps.
* Suporte a múltiplas Áreas de Trabalho.
* Comando global:

```bash
atualizar-icones
```

* Integração com o menu de aplicativos do Zorin.
* Verificação automática ao iniciar a sessão.
* Monitoramento da Área de Trabalho para novos Web Apps.
* Sistema de logs.

---

## 📜 Licença

MIT License.

---

## 👤 Autor

**César Godinho**

GitHub:

**CSRG42**

---

## 📌 Status

**Versão inicial — funcional**

O projeto foi criado para solucionar especificamente o problema de ícones ausentes em atalhos de Web Apps na Área de Trabalho do Zorin OS.

O funcionamento foi validado com Web App instalado pelo **Brave Browser**.

