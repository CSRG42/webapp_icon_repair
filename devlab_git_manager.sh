#!/bin/bash
# =========================
# CONFIGURAÇÕES
# =========================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# =========================
# DEVLAB ENGINE
# =========================
clear
echo -e "${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│                  🧠 DEVLAB GIT MANAGER                   │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"

# =========================
# FUNÇÕES DE SUPORTE
# =========================
pause() {
    echo
    read -rp "Pressione ENTER para continuar..."
}

# =========================================================
# ATUALIZA APENAS HEADERS JÁ GERADOS
# =========================================================
update_file_versions() {
    local FILE

    # pega apenas arquivos modificados
    for FILE in $(git diff --name-only); do

        # ignora se não existir
        [[ ! -f "$FILE" ]] && continue

        if grep -Eq 'Version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' "$FILE"; then

            sed -Ei \
            "s/(Version:[[:space:]]+)[0-9]+\.[0-9]+\.[0-9]+/\1$PROJECT_VERSION/g" \
            "$FILE"

        fi
    done
}

# =========================
# CONTEXTO
# =========================
get_context() {
    # 1. Nome do Repo e Path
    REPO_NAME=$(basename "$PWD")
    LOCAL_PATH=$(pwd)
    
    # 2. Branch e Versão
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
    [[ -z "$CURRENT_BRANCH" ]] && CURRENT_BRANCH="main"
    
    PROJECT_VERSION=$(cat .devlab_version 2>/dev/null || echo "1.0.0")
    VERSION="$PROJECT_VERSION"
    
    # 3. Stack
    STACK_NAME=$(cat .devlab_stack 2>/dev/null || echo "Não Definida")

    # 4. Verificação de Remote e Privacidade baseada exclusivamente no Git local
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)

    if [[ -n "$REMOTE_URL" ]]; then
        DISPLAY_REMOTE="$REMOTE_URL"
        
        # Tenta checar visibilidade sem remover origin em caso de falha
        IS_PRIVATE=$(gh repo view --json isPrivate -q .isPrivate 2>/dev/null)
        if [[ "$IS_PRIVATE" == "true" ]]; then
            PRIVACY_STATUS="PRIVADO"
            PRIVACY_LABEL="PRIVADO"
            COLOR="${GREEN}"
        elif [[ "$IS_PRIVATE" == "false" ]]; then
            PRIVACY_STATUS="PÚBLICO"
            PRIVACY_LABEL="PÚBLICO"
            COLOR="${YELLOW}"
        else
            PRIVACY_STATUS="CONECTADO"
            PRIVACY_LABEL="REMOTO"
            COLOR="${GREEN}"
        fi
    else
        DISPLAY_REMOTE="Não Sincronizado"
        REMOTE_URL="Sem Remote"
        PRIVACY_STATUS="Localhost (sem GH)"
        PRIVACY_LABEL="LOCAL"
        COLOR="${YELLOW}"
    fi
}

# =========================================================
# VERIFICADOR DE AUTENTICAÇÃO E CONEXÃO COM A NUVEM
# =========================================================

ensure_gh_auth() {
    local HAS_SSH=false

    if compgen -G "$HOME/.ssh/id_*" > /dev/null 2>&1; then
        HAS_SSH=true
    fi

    if ! gh auth status &>/dev/null; then
        echo -e "${YELLOW}🔐 Login no GitHub necessário...${NC}"
        
        if [ "$HAS_SSH" = true ]; then
            echo -e "${GREEN}🔑 Chave SSH detectada em ~/.ssh/${NC}"
            echo -e "${BLUE}Iniciando autenticação... (Escolha SSH no menu a seguir)${NC}\n"
        else
            echo -e "${YELLOW}⚠️ Nenhuma chave SSH encontrada em ~/.ssh/${NC}"
            echo -e "${BLUE}Iniciando autenticação via Web/HTTPS...${NC}\n"
        fi

        gh auth login || {
            echo -e "${RED}❌ Falha na autenticação com o GitHub.${NC}"
            return 1
        }
    fi

    return 0
}

startup_check() {
    echo -e "${BLUE}🔍 Executando verificações iniciais...${NC}"

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${YELLOW}⚠️ Diretório não é um repositório Git local. Inicializando...${NC}"
        git init -b main &>/dev/null
    fi

    ensure_gh_auth || return 1

    if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚙️ Configurando identidade do Git a partir do GitHub...${NC}"
        local GH_NAME GH_EMAIL GH_LOGIN GH_ID

        GH_LOGIN=$(gh api user -q .login 2>/dev/null)
        GH_NAME=$(gh api user -q '.name // .login' 2>/dev/null)
        GH_EMAIL=$(gh api user -q '.email // empty' 2>/dev/null)

        if [ -z "$GH_EMAIL" ]; then
            GH_ID=$(gh api user -q .id 2>/dev/null)
            GH_EMAIL="${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
        fi

        git config --global user.name "$GH_NAME"
        git config --global user.email "$GH_EMAIL"
        echo -e "${GREEN}✅ Configurado: $GH_NAME <$GH_EMAIL>${NC}"
    fi

    local REPO_NAME GH_USER CURRENT_BRANCH
    REPO_NAME=$(basename "$PWD")
    GH_USER=$(gh api user -q .login 2>/dev/null)
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

    if [[ -z "$GH_USER" ]]; then
        echo -e "${RED}❌ Não foi possível identificar seu usuário do GitHub.${NC}"
        return 1
    fi

    if gh repo view "$GH_USER/$REPO_NAME" &>/dev/null; then
        echo -e "${GREEN}✅ Repositório encontrado no GitHub!${NC}"

        if ! git remote get-url origin &>/dev/null; then
            echo -e "${BLUE}🔗 Vinculando repositório remoto...${NC}"
            if compgen -G "$HOME/.ssh/id_*" > /dev/null 2>&1; then
                git remote add origin "git@github.com:$GH_USER/$REPO_NAME.git"
            else
                git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git"
            fi
        fi
    else
        echo -e "${BLUE}ℹ️ Repositório '${REPO_NAME}' não existe no GitHub (apenas local).${NC}"
    fi

    echo -e "${GREEN}------------------------------------------${NC}"
    sleep 1
}

# Executa o verificador assim que abre o script
startup_check

# =========================
# INPUT / MENU PRINCIPAL
# =========================
while true; do
    printf "\033[H\033[J"
    get_context
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")

    echo -e "${GREEN}✅ STATUS ATUAL:${NC}"
    echo -e "    📂 Repo:       ${NC}${REPO_NAME}"
    echo -e "    🌿 Branch:     ${NC}${CURRENT_BRANCH}"
    echo -e "    🏷️ Versão:     ${COLOR}${VERSION}${NC} (Commit: ${COMMIT_HASH})"
    echo -e "    🔗 Remote:     ${COLOR}${REMOTE_URL}${NC}"
    echo -e "    🔐 Privacidade: ${COLOR}${PRIVACY_LABEL}${NC}"
    echo -e "${GREEN}------------------------------------------${NC}"

    echo -e "\n${YELLOW}📦 DEVLAB • GIT MANAGER:${NC}"
    echo -e "  1) 🔄 Sincronizar repositório"
    echo -e "  2) 📝 Commit Salvar alterações"
    echo -e "  3) ⬆️ Push Enviar para repositório"
    echo -e "  4) ⬇️ Pull Atualizar repositório local"
    echo -e "  5) 🧾 Log Histórico de Commits"
    echo -e "  6) 🧹 Limpar Cache/Temp"
    echo -e "  7) ⏪ Reset (Seguro)"
    echo -e "  8) ✏️ Renomear repositório"
    echo -e "  9) 🔐 Privacidade do repositório"
    echo -e " 10) 🗑️ Deletar repositório"
    echo -e " 11) ✏️ Corrigir último commit (texto)"
    echo -e "\n  0) 👋 Sair"
    echo -e "${GREEN}------------------------------------------${NC}"
    
    read -p "👉 Escolha: " OPT
    
    case $OPT in
        1) # SINCRONIZAR REPOSITÓRIO
            printf "\033[H\033[J"
            get_context
            ensure_gh_auth

            echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
            echo -e "${GREEN}│        🔄 SINCRONIZAÇÃO INTELIGENTE      │${NC}"
            echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"

            GH_USER=$(gh api user -q .login 2>/dev/null)

            if git remote | grep -q "origin"; then
                echo -e "${BLUE}📡 Puxando atualizações e enviando alterações para o GitHub...${NC}"
                git pull origin "$CURRENT_BRANCH" --rebase
                
                if git push -u origin "$CURRENT_BRANCH"; then
                    echo -e "\n${GREEN}✅ Repositório local e GitHub sincronizados com sucesso!${NC}"
                else
                    echo -e "\n${RED}❌ Falha ao enviar arquivos. Verifique os erros acima.${NC}"
                fi
            else
                REPO_EXISTS=$(gh repo view "$GH_USER/$REPO_NAME" --json name -q .name 2>/dev/null)
                
                if [[ -n "$REPO_EXISTS" ]]; then
                    echo -e "${BLUE}🔗 Vinculando e enviando para o repositório existente no GitHub...${NC}"
                    if compgen -G "$HOME/.ssh/id_*" > /dev/null 2>&1; then
                        git remote add origin "git@github.com:$GH_USER/$REPO_NAME.git"
                    else
                        git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git"
                    fi
                    git push -u origin "$CURRENT_BRANCH"
                else
                    echo -e "${YELLOW}✨ Criando novo repositório no GitHub...${NC}"
                    if gh repo create "$REPO_NAME" --private --source=. --remote=origin; then
                        git branch -M main
                        git push -u origin main
                        echo -e "${GREEN}✅ Novo repositório criado e sincronizado!${NC}"
                    else
                        echo -e "${RED}❌ Falha ao criar repositório no GitHub.${NC}"
                    fi
                fi
            fi

            pause
            ;;

        2) # COMMIT PADRONIZADO
            printf "\033[H\033[J"
            get_context

            if [[ -z $(git status --porcelain) ]]; then
                echo -e "${GREEN}✨ Tudo atualizado. Nada para commitar.${NC}"
            else
                ensure_gh_auth

                # 1. SCANNER DE STACKS
                MAP_STACKS=""

                if [[ -d "src" ]]; then
                    FILES=$(find src -type f 2>/dev/null)

                    [[ "$FILES" =~ \.html ]] && MAP_STACKS+="HTML+"
                    [[ "$FILES" =~ \.css ]] && MAP_STACKS+="CSS+"
                    [[ "$FILES" =~ \.js ]] && MAP_STACKS+="JavaScript+"
                    [[ "$FILES" =~ \.ts ]] && MAP_STACKS+="TypeScript+"

                    [[ "$FILES" =~ \.php ]] && MAP_STACKS+="PHP+"
                    [[ "$FILES" =~ \.py ]] && MAP_STACKS+="Python+"
                    [[ "$FILES" =~ \.rb ]] && MAP_STACKS+="Ruby+"
                    [[ "$FILES" =~ \.java ]] && MAP_STACKS+="Java+"
                    [[ "$FILES" =~ \.go ]] && MAP_STACKS+="Go+"
                    [[ "$FILES" =~ \.rs ]] && MAP_STACKS+="Rust+"
                    [[ "$FILES" =~ \.cs ]] && MAP_STACKS+="CSharp+"

                    [[ "$FILES" =~ \.sh ]] && MAP_STACKS+="Bash+"
                    [[ "$FILES" =~ \.sql ]] && MAP_STACKS+="SQL+"
                fi

                [[ -f "package.json" ]] && MAP_STACKS+="Node+"
                [[ -f "composer.json" ]] && MAP_STACKS+="Composer+"
                [[ -f "requirements.txt" || -f "pyproject.toml" ]] && MAP_STACKS+="PythonEnv+"
                [[ -f "Dockerfile" || -f "docker-compose.yml" ]] && MAP_STACKS+="Docker+"

                MAP_STACKS="${MAP_STACKS%+}"

                STACK_COUNT=$(echo "$MAP_STACKS" | tr -cd '+' | wc -c)
                [[ -n "$MAP_STACKS" ]] && ((STACK_COUNT++))

                if [[ $STACK_COUNT -gt 1 ]]; then
                    FINAL_STACK="Multi-Stack"
                else
                    FINAL_STACK="${MAP_STACKS:-$STACK_NAME}"
                fi

                # 2. CONTROLE DE VERSÃO
                CURRENT_LINE=$(tail -n 1 .devlab_version 2>/dev/null)

                if [[ -z "$CURRENT_LINE" ]]; then
                    CURRENT_VERSION="1.0.0"
                else
                    CURRENT_VERSION=$(echo "$CURRENT_LINE" | awk '{print $1}')
                fi

                IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

                PATCH=$((PATCH + 1))
                PROJECT_VERSION="${MAJOR}.${MINOR}.${PATCH}"

                update_file_versions

                # 3. MENU DE TIPO DE COMMIT
                echo -e "${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
                echo -e "${GREEN}│             📝 SELECIONE O TIPO DE COMMIT                │${NC}"
                echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
                echo

                echo -e "  1) 🚀 Adicionado           2) 🐛 Corrigido"
                echo -e "  3) 🛠️  Manutenção           4) ♻️  Refatorado"
                echo -e "  5) ⚡ Performance          6) 🎨 Estilo"
                echo
                echo -e "  7) 📝 Documentação         8) 🧪 Testes"
                echo -e "  9) 🔧 Build                10) ⚙️  CI/CD"
                echo -e "  11) 🔙 Reversão            12) 🔥 Inicial"
                echo
                echo -e "  13) 🔐 Segurança           14) 📦 Dependências"
                echo -e "  15) 🌐 Traduções           16) 📎 Assets"

                echo -e "${GREEN}------------------------------------------------------------${NC}"

                read -rp "👉 Tipo: " T_OPT

                case $T_OPT in
                    1) TYPE="🚀 feat:"; CAT="### 🚀 Novas Funcionalidades" ;;
                    2) TYPE="🐛 fix:"; CAT="### 🐛 Correções de Bugs" ;;
                    3) TYPE="🛠️ chore:"; CAT="### 🛠️ Manutenção Geral" ;;
                    4) TYPE="♻️ refactor:"; CAT="### ♻️ Refatoração de Código" ;;
                    5) TYPE="⚡ perf:"; CAT="### ⚡ Melhorias de Performance" ;;
                    6) TYPE="🎨 style:"; CAT="### 🎨 Ajustes Visuais" ;;
                    7) TYPE="📝 docs:"; CAT="### 📝 Atualizações de Documentação" ;;
                    8) TYPE="🧪 test:"; CAT="### 🧪 Testes Automatizados" ;;
                    9) TYPE="🔧 build:"; CAT="### 🔧 Sistema de Build" ;;
                    10) TYPE="⚙️ ci:"; CAT="### ⚙️ Integração Contínua" ;;
                    11) TYPE="🔙 revert:"; CAT="### 🔙 Reversão de Alterações" ;;
                    12) TYPE="🔥 init:"; CAT="### 🚀 Inicialização do Projeto" ;;
                    13) TYPE="🔐 security:"; CAT="### 🔐 Atualizações de Segurança" ;;
                    14) TYPE="📦 deps:"; CAT="### 📦 Atualizações de Dependências" ;;
                    15) TYPE="🌐 i18n:"; CAT="### 🌐 Suporte a Idiomas" ;;
                    16) TYPE="📎 assets:"; CAT="### 📎 Atualizações de Recursos" ;;
                    *) TYPE="🛠️ chore:"; CAT="### 🛠️ Manutenção Geral Automática" ;;
                esac

                if [[ "$T_OPT" -eq 12 ]]; then
                    DESC="Início de projeto"
                else
                    read -rp "💬 Descrição: " DESC_RAW
                    DESC_CLEAN=$(echo "${DESC_RAW:-Atualização automática}" | xargs)
                    DESC="$(echo "${DESC_CLEAN:0:1}" | tr '[:lower:]' '[:upper:]')${DESC_CLEAN:1}"
                fi

                # 4. MENSAGEM DE COMMIT
                COMMIT_MSG="$TYPE ($REPO_NAME) | $FINAL_STACK | v$PROJECT_VERSION | $DESC"

                # 5. CHANGELOG
                if [[ -f "CHANGELOG.md" ]]; then
                    DATE_NOW=$(date +'%Y-%m-%d')
                    BLOCK="## [$PROJECT_VERSION] - $DATE_NOW\n$CAT\n- $DESC\n- [Descrição manual]\n"
                    sed -i "5i $BLOCK" CHANGELOG.md
                fi

                # 6. EXECUÇÃO DO COMMIT
                git add .

                if git commit -m "$COMMIT_MSG"; then
                    COMMIT_HASH=$(git rev-parse --short HEAD)
                    COMMIT_DATE=$(date +"%Y-%m-%d %H:%M")

                    echo "$PROJECT_VERSION" > .devlab_version
                    echo "$PROJECT_VERSION - $COMMIT_HASH - $DESC - $COMMIT_DATE" >> .devlab_history

                    git add .devlab_version
                    git commit --amend --no-edit >/dev/null 2>&1

                    echo -e "\n${GREEN}✅ Commit v$PROJECT_VERSION realizado com sucesso!${NC}"

                    if git remote | grep -q "origin"; then
                        echo -e "${YELLOW}🚀 Enviando alterações para o GitHub...${NC}"
                        if git push origin "$CURRENT_BRANCH"; then
                            echo -e "${GREEN}🚀 Sincronizado com GitHub!${NC}"
                        else
                            echo -e "${RED}⚠️ Commit salvo localmente, mas ocorreu um erro no push para o GitHub.${NC}"
                        fi
                    else
                        echo -e "${YELLOW}ℹ️ Commit salvo apenas localmente. Use a opção 1 para conectar ao GitHub.${NC}"
                    fi
                fi
            fi

            pause
            ;;

        3) # PUSH - ENVIAR PARA O REPOSITÓRIO
            printf "\033[H\033[J"
            get_context
            
            echo -e "${YELLOW}⬆️  PREPARANDO ENVIO PARA GITHUB...${NC}"
            ensure_gh_auth
            
            if ! git remote | grep -q "origin"; then
                echo -e "${RED}❌ Erro: Nenhum repositório remoto (origin) configurado.${NC}"
                echo -e "Use a opção 1 para sincronizar primeiro."
            else
                echo -e "📡 Enviando branch ${GREEN}$CURRENT_BRANCH${NC} para ${GREEN}origin${NC}..."
                
                if git push -u origin "$CURRENT_BRANCH"; then
                    echo -e "\n${GREEN}┌──────────────────────────────────────────┐${NC}"
                    echo -e "${GREEN}│      🚀 SUCESSO! PROJETO ATUALIZADO      │${NC}"
                    echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
                    echo -e "✨ Seus arquivos já estão seguros no GitHub."
                else
                    echo -e "\n${RED}❌ FALHA NO PUSH!${NC}"
                    echo -e "Dica: Talvez existam mudanças no GitHub que você não tem localmente."
                    echo -e "Tente usar a opção ${YELLOW}4) Pull${NC} antes de tentar o Push novamente."
                fi
            fi
            
            pause
            ;;

        4) # PULL - ATUALIZAR REPOSITÓRIO LOCAL
            printf "\033[H\033[J"
            get_context

            echo -e "${YELLOW}⬇️  BUSCANDO ATUALIZAÇÕES NO GITHUB...${NC}"

            if ! git remote | grep -q "origin"; then
                echo -e "${RED}❌ Erro: Remote 'origin' não encontrado.${NC}"
            else
                echo -e "📡 Sincronizando branch ${GREEN}$CURRENT_BRANCH${NC}..."
                
                if git pull origin "$CURRENT_BRANCH" --rebase; then
                    echo -e "\n${GREEN}┌──────────────────────────────────────────┐${NC}"
                    echo -e "${GREEN}│       ✅ REPOSITÓRIO ATUALIZADO!         │${NC}"
                    echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
                    echo -e "✨ Seu código local está em sincronia com a nuvem."
                else
                    echo -e "\n${RED}⚠️  ATENÇÃO: CONFLITO DETECTADO!${NC}"
                    echo -e "Resolva os conflitos manualmente antes de continuar."
                fi
            fi

            pause
            ;;

        5) # LOG - HISTÓRICO DE COMMITS
            printf "\033[H\033[J"
            get_context

            echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
            echo -e "${GREEN}│      📜 HISTÓRICO DE COMMITS DEVLAB      │${NC}"
            echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
            echo -e "Exibindo os últimos 15 commits do projeto: ${YELLOW}$REPO_NAME${NC}\n"

            git log -n 15 --pretty=format:"%C(yellow)%h%C(reset) | %s %C(bold green)(%ad)%C(reset) %C(blue)[%an]%C(reset)" --date=format:'%d/%m/%Y %H:%M'
            
            echo -e "\n\n${GREEN}------------------------------------------${NC}"
            echo -e "${YELLOW}Dica:${NC} Seus commits seguem o padrão Conventional Commits."
            
            pause
            ;;

        6) # LIMPAR CACHE / TEMP
            printf "\033[H\033[J"
            get_context

            echo -e "${YELLOW}🧹 INICIANDO LIMPEZA DO PROJETO: ${NC}$REPO_NAME"
            echo -e "${GREEN}------------------------------------------${NC}"

            echo -e "📦 ${YELLOW}Otimizando banco de dados Git...${NC}"
            git gc --prune=now --aggressive &>/dev/null
            
            echo -e "📁 ${YELLOW}Removendo arquivos temporários e logs...${NC}"
            
            find . -type f -name "*.log" -delete 2>/dev/null
            find . -type f -name "*~" -delete 2>/dev/null
            find . -type f -name ".DS_Store" -delete 2>/dev/null
            
            case $STACK_NAME in
                "Node.js") [ -d "node_modules/.cache" ] && rm -rf node_modules/.cache ;;
                "Python") find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null ;;
            esac

            echo -e "\n${GREEN}┌──────────────────────────────────────────┐${NC}"
            echo -e "${GREEN}│    ✨ LIMPEZA CONCLUÍDA COM SUCESSO!     │${NC}"
            echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"

            pause
            ;;

        7) # RESET (SEGURO)
            printf "\033[H\033[J"
            get_context

            echo -e "${RED}┌──────────────────────────────────────────┐${NC}"
            echo -e "${RED}│          ⚠️  AVISO DE RESET SEGURO        │${NC}"
            echo -e "${RED}└──────────────────────────────────────────┘${NC}"
            echo -e "Isso irá descartar todas as alterações não salvas nos arquivos existentes."
            echo -e "\n${YELLOW}Tem certeza que deseja continuar? (y/n)${NC}"
            read -rp "👉 Escolha: " CONFIRM

            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo -e "\n${YELLOW}⏪ Restaurando arquivos para o último commit...${NC}"
                git checkout .
                echo -e "\n${GREEN}✅ Reset concluído!${NC}"
            else
                echo -e "\n${BLUE}ℹ️  Operação cancelada pelo usuário.${NC}"
            fi

            pause
            ;;

        8) # RENOMEAR REPOSITÓRIO
            printf "\033[H\033[J"
            get_context
            ensure_gh_auth

            echo -e "${YELLOW}✏️  RENOMEAR PROJETO ATUAL: ${NC}$REPO_NAME"
            echo -e "${GREEN}------------------------------------------${NC}"
            
            read -rp "👉 Digite o novo nome para o repositório: " NEW_NAME
            
            if [[ -z "$NEW_NAME" ]]; then
                echo -e "${RED}❌ O nome não pode ser vazio.${NC}"
            else
                NEW_SAFE_NAME=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
                USER_NAME=$(gh api user -q .login)
                
                echo -e "\n${YELLOW}📡 Enviando solicitação para o GitHub...${NC}"
                
                if gh api -X PATCH "repos/$USER_NAME/$REPO_NAME" -f name="$NEW_SAFE_NAME" > /dev/null; then
                    NEW_URL="https://github.com/$USER_NAME/$NEW_SAFE_NAME.git"
                    git remote set-url origin "$NEW_URL" 2>/dev/null
                    
                    echo -e "${GREEN}✅ Sucesso no GitHub!${NC}"

                    OLD_NAME="$REPO_NAME"
                    REPO_NAME="$NEW_SAFE_NAME"
                    
                    echo -e "${YELLOW}📂 Renomeando pasta local de ${NC}$OLD_NAME ${YELLOW}para ${NC}$NEW_SAFE_NAME..."
                    
                    if cd .. && mv "$OLD_NAME" "$NEW_SAFE_NAME"; then
                        cd "$NEW_SAFE_NAME"
                        echo -e "${GREEN}✅ Pasta local renomeada e sincronizada!${NC}"
                    else
                        echo -e "${RED}⚠️  GitHub alterado, mas não foi possível renomear a pasta local.${NC}"
                        cd "$OLD_NAME"
                    fi
                else
                    echo -e "${RED}❌ O GitHub recusou a alteração.${NC}"
                fi
            fi

            pause
            ;;

        9) # PRIVACIDADE DO REPOSITÓRIO
            printf "\033[H\033[J"
            get_context
            ensure_gh_auth

            echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
            echo -e "${GREEN}│        🔐 GESTÃO DE PRIVACIDADE GH       │${NC}"
            echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
            echo -e "Repositório atual: ${YELLOW}$REPO_NAME${NC}"
            
            USER_NAME=$(gh api user -q .login)
            IS_PRIVATE=$(gh api "repos/$USER_NAME/$REPO_NAME" -q .private 2>/dev/null)

            if [[ "$IS_PRIVATE" == "true" ]]; then
                echo -e "Status atual: ${RED}🔒 PRIVADO${NC}"
            else
                echo -e "Status atual: ${GREEN}🌐 PÚBLICO${NC}"
            fi

            echo -e "\n${YELLOW}ALTERAR PARA:${NC}"
            echo "1) Tornar PRIVADO"
            echo "2) Tornar PÚBLICO"
            echo "0) Cancelar"
            echo -e "${GREEN}------------------------------------------${NC}"
            read -rp "👉 Escolha: " P_OPT

            case $P_OPT in
                1)
                    echo -e "\n${YELLOW}🔒 Alterando para PRIVADO...${NC}"
                    if gh api -X PATCH "repos/$USER_NAME/$REPO_NAME" -f visibility='private' > /dev/null; then
                        echo -e "${GREEN}✅ Sucesso! Agora o repositório é PRIVADO.${NC}"
                    else
                        echo -e "${RED}❌ Falha ao alterar. Verifique o repositório no GitHub.${NC}"
                    fi
                    ;;
                2)
                    echo -e "\n${YELLOW}🌐 Alterando para PÚBLICO...${NC}"
                    if gh api -X PATCH "repos/$USER_NAME/$REPO_NAME" -f visibility='public' > /dev/null; then
                        echo -e "${GREEN}✅ Sucesso! Agora o repositório é PÚBLICO.${NC}"
                    else
                        echo -e "${RED}❌ Falha ao alterar. Verifique as permissões.${NC}"
                    fi
                    ;;
                0) echo -e "\n${BLUE}ℹ️ Operação cancelada.${NC}" ;;
                *) echo -e "\n${RED}❌ Opção inválida.${NC}" ;;
            esac

            pause
            ;;

        10) # DELETAR REPOSITÓRIO (GITHUB)
            printf "\033[H\033[J"
            get_context
            ensure_gh_auth

            echo -e "${RED}┌──────────────────────────────────────────┐${NC}"
            echo -e "${RED}│          🚨 PERIGO: DELETAR REPO         │${NC}"
            echo -e "${RED}└──────────────────────────────────────────┘${NC}"
            echo -e "Você está prestes a deletar: ${YELLOW}$REPO_NAME${NC}"
            echo -e "${RED}Esta ação não pode ser desfeita no GitHub!${NC}"
            
            echo -e "\n${YELLOW}Para confirmar, digite o nome do projeto (${NC}${REPO_NAME}${YELLOW}):${NC}"
            read -rp "👉 " CONFIRM_NAME

            if [[ "$CONFIRM_NAME" == "$REPO_NAME" ]]; then
                USER_NAME=$(gh api user -q .login)
                echo -e "\n${RED}💣 Deletando repositório no GitHub...${NC}"
                
                if gh repo delete "$USER_NAME/$REPO_NAME" --yes &>/dev/null; then
                    echo -e "${GREEN}✅ Repositório deletado do GitHub com sucesso!${NC}"
                    if git remote | grep -q "origin"; then
                        git remote remove origin
                        echo -e "${YELLOW}🧹 Vinculação remota (origin) removida do projeto local.${NC}"
                    fi
                else
                    echo -e "${RED}❌ Falha ao deletar repositório. Verifique permissões do GH CLI.${NC}"
                fi
            else
                echo -e "\n${BLUE}ℹ️ Confirmação incorreta. Operação cancelada.${NC}"
            fi

            pause
            ;;

        11) # CORRIGIR ÚLTIMO COMMIT (TEXTO)
            printf "\033[H\033[J"
            get_context

            LAST_MSG=$(git log -1 --pretty=%B 2>/dev/null)

            if [[ -z "$LAST_MSG" ]]; then
                echo -e "${RED}❌ Nenhum commit encontrado neste repositório.${NC}"
            else
                echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
                echo -e "${GREEN}│      ✏️ CORRIGIR MENSAGEM DE COMMIT      │${NC}"
                echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
                echo -e "Mensagem atual:\n${YELLOW}$LAST_MSG${NC}\n"
                
                read -rp "💬 Digite a nova mensagem: " NEW_MSG
                
                if [[ -n "$NEW_MSG" ]]; then
                    if git commit --amend -m "$NEW_MSG"; then
                        echo -e "\n${GREEN}✅ Mensagem de commit atualizada com sucesso!${NC}"
                        if git remote | grep -q "origin"; then
                            echo -e "${YELLOW}⚠️ Caso já tenha feito push anteriormente, será necessário forçar a atualização (push --force-with-lease).${NC}"
                        fi
                    else
                        echo -e "\n${RED}❌ Falha ao alterar a mensagem do commit.${NC}"
                    fi
                else
                    echo -e "\n${BLUE}ℹ️ Operação cancelada. Nenhuma mensagem fornecida.${NC}"
                fi
            fi

            pause
            ;;

        0) # SAIR
            printf "\033[H\033[J"
            echo -e "${GREEN} Atividades encerradas no DevLab Manager. Até logo! 👋${NC}\n"
            exit 0
            ;;

        *)
            echo -e "\n${RED}❌ Opção inválida. Escolha um número do menu.${NC}"
            pause
            ;;
    esac
done