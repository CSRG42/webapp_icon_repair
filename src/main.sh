#!/usr/bin/env bash
set -u
# ==============================================================================
# Project: webapp_icon_repair
# Stack:   Bash
# Version: 1.0.3
# Author:  César Godinho (CSRG42)
# License: MIT License
# Created: 22/09/2026 00:43
# ==============================================================================

# ============================================================
# Reparar Ícones de Web Apps
# Compatível com Zorin OS / GNOME
#
# Objetivo:
#    Corrigir ícones dos .desktop que JÁ estão na Área de Trabalho.
#
# O script:
#    - Não cria atalhos
#    - Não remove atalhos
#    - Não altera aplicativos apenas presentes no menu
#    - Faz backup antes de modificar
#    - Procura ícones em vários diretórios
#    - Prioriza ícones maiores
#    - Funciona com Brave, Chromium, Chrome, Edge, Vivaldi etc.
# ============================================================

set -o pipefail

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"

if [[ -z "$DESKTOP_DIR" || ! -d "$DESKTOP_DIR" ]]; then
    echo "ERRO: não foi possível localizar a Área de Trabalho."
    exit 1
fi

BACKUP_DIR="$DESKTOP_DIR/.backup_icones_webapps"

mkdir -p "$BACKUP_DIR"

echo
echo "=============================================="
echo "    ATUALIZADOR DE ÍCONES DE WEB APPS"
echo "=============================================="
echo
echo "Área de Trabalho:"
echo "$DESKTOP_DIR"
echo
echo "Backup:"
echo "$BACKUP_DIR"
echo

# ------------------------------------------------------------
# Diretórios onde o Linux normalmente procura ícones
# ------------------------------------------------------------

ICON_DIRS=(
    "$HOME/.local/share/icons"
    "$HOME/.icons"
    "/usr/local/share/icons"
    "/usr/share/icons"
)

# ------------------------------------------------------------
# Tamanhos preferenciais
# Maior primeiro
# ------------------------------------------------------------

ICON_SIZES=(
    "512x512"
    "384x384"
    "256x256"
    "192x192"
    "180x180"
    "160x160"
    "144x144"
    "128x128"
    "96x96"
    "72x72"
    "64x64"
    "48x48"
    "36x36"
    "32x32"
    "24x24"
    "16x16"
)

# ------------------------------------------------------------
# Verifica se um arquivo é realmente um .desktop
# ------------------------------------------------------------

is_desktop_file() {
    local file="$1"

    grep -qE '^\[Desktop Entry\]' "$file" 2>/dev/null
}

# ------------------------------------------------------------
# Obtém o valor de uma propriedade do Desktop Entry
# ------------------------------------------------------------

get_desktop_value() {
    local key="$1"
    local file="$2"

    sed -n "s/^${key}=//p" "$file" | head -n 1
}

# ------------------------------------------------------------
# Procura o ícone pelo nome informado em Icon=
# ------------------------------------------------------------

find_icon() {
    local icon_name="$1"

    # Remove aspas caso existam
    icon_name="${icon_name#\"}"
    icon_name="${icon_name%\"}"

    # --------------------------------------------------------
    # Caso Icon= já seja um caminho absoluto
    # --------------------------------------------------------

    if [[ "$icon_name" = /* && -f "$icon_name" ]]; then
        echo "$icon_name"
        return 0
    fi

    # --------------------------------------------------------
    # Extensões possíveis
    # --------------------------------------------------------

    local extensions=(
        "png"
        "svg"
        "svgz"
        "xpm"
        "ico"
        "webp"
    )

    # --------------------------------------------------------
    # Se já tiver extensão, tenta diretamente
    # --------------------------------------------------------

    if [[ "$icon_name" == *.* ]]; then

        for base in "${ICON_DIRS[@]}"; do

            [[ -d "$base" ]] || continue

            local result

            result=$(find "$base" \
                -type f \
                -iname "$(basename "$icon_name")" \
                2>/dev/null | head -n 1)

            if [[ -n "$result" ]]; then
                echo "$result"
                return 0
            fi

        done

    fi

    # --------------------------------------------------------
    # Procura por tamanho preferencial
    # --------------------------------------------------------

    local size
    local ext
    local base
    local result

    for size in "${ICON_SIZES[@]}"; do

        for ext in "${extensions[@]}"; do

            for base in "${ICON_DIRS[@]}"; do

                [[ -d "$base" ]] || continue

                result=$(find "$base" \
                    -type f \
                    -path "*/${size}/*" \
                    -iname "${icon_name}.${ext}" \
                    2>/dev/null | head -n 1)

                if [[ -n "$result" ]]; then
                    echo "$result"
                    return 0
                fi

            done

        done

    done

    # --------------------------------------------------------
    # Última tentativa:
    # procura pelo nome em qualquer pasta de ícones
    # --------------------------------------------------------

    for base in "${ICON_DIRS[@]}"; do

        [[ -d "$base" ]] || continue

        result=$(find "$base" \
            -type f \
            \( \
                -iname "${icon_name}.png" \
                -o -iname "${icon_name}.svg" \
                -o -iname "${icon_name}.svgz" \
                -o -iname "${icon_name}.xpm" \
                -o -iname "${icon_name}.ico" \
                -o -iname "${icon_name}.webp" \
            \) \
            2>/dev/null | head -n 1)

        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi

    done

    return 1
}

# ------------------------------------------------------------
# Atualiza uma linha Icon=
# ------------------------------------------------------------

update_icon_line() {
    local file="$1"
    local new_icon="$2"

    sed -i \
        "s|^Icon=.*$|Icon=$new_icon|" \
        "$file"
}

# ------------------------------------------------------------
# Processamento principal
# ------------------------------------------------------------

FOUND=0
UPDATED=0
SKIPPED=0

shopt -s nullglob

DESKTOP_FILES=(
    "$DESKTOP_DIR"/*.desktop
)

if [[ ${#DESKTOP_FILES[@]} -eq 0 ]]; then

    echo "Nenhum arquivo .desktop foi encontrado na Área de Trabalho."
    echo
    exit 0

fi

for file in "${DESKTOP_FILES[@]}"; do

    [[ -f "$file" ]] || continue

    FOUND=$((FOUND + 1))

    filename="$(basename "$file")"

    echo "----------------------------------------------"
    echo "Atalho: $filename"

    # --------------------------------------------------------
    # Confirma Desktop Entry
    # --------------------------------------------------------

    if ! is_desktop_file "$file"; then

        echo "  Ignorado: não é um Desktop Entry válido."
        SKIPPED=$((SKIPPED + 1))
        continue

    fi

    # --------------------------------------------------------
    # Obtém Name e Icon
    # --------------------------------------------------------

    name="$(get_desktop_value "Name" "$file")"
    icon="$(get_desktop_value "Icon" "$file")"

    echo "  Nome : ${name:-desconhecido}"
    echo "  Icon : ${icon:-não definido}"

    # --------------------------------------------------------
    # Sem Icon=
    # --------------------------------------------------------

    if [[ -z "$icon" ]]; then

        echo "  Ignorado: não possui Icon=."
        SKIPPED=$((SKIPPED + 1))
        continue

    fi

    # --------------------------------------------------------
    # Se já aponta para um arquivo existente, não mexe
    # --------------------------------------------------------

    if [[ "$icon" = /* && -f "$icon" ]]; then

        echo "  OK: já possui caminho válido."
        SKIPPED=$((SKIPPED + 1))
        continue

    fi

    # --------------------------------------------------------
    # Procura o ícone
    # --------------------------------------------------------

    icon_path="$(find_icon "$icon" || true)"

    if [[ -z "$icon_path" ]]; then

        echo "  NÃO ENCONTRADO: $icon"
        SKIPPED=$((SKIPPED + 1))
        continue

    fi

    echo "  Encontrado:"
    echo "  $icon_path"

    # --------------------------------------------------------
    # Backup
    # --------------------------------------------------------

    backup_file="$BACKUP_DIR/$filename"

    if [[ ! -f "$backup_file" ]]; then

        cp -a "$file" "$backup_file"

        echo "  Backup criado."

    else

        echo "  Backup já existe."

    fi

    # --------------------------------------------------------
    # Atualiza Icon=
    # --------------------------------------------------------

    update_icon_line "$file" "$icon_path"

    UPDATED=$((UPDATED + 1))

    echo "  ÍCONE ATUALIZADO."

done

# ------------------------------------------------------------
# Atualiza cache de ícones do usuário, quando disponível
# ------------------------------------------------------------

if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    echo
    echo "Atualizando cache de ícones..."

    # Não é obrigatório; erros são ignorados.
    gtk-update-icon-cache \
        -f \
        -t \
        "$HOME/.local/share/icons/hicolor" \
        >/dev/null 2>&1 || true

fi

echo
echo "=============================================="
echo "RESULTADO"
echo "=============================================="
echo
echo "Atalhos encontrados : $FOUND"
echo "Ícones atualizados   : $UPDATED"
echo "Ignorados            : $SKIPPED"
echo
echo "Backup:"
echo "$BACKUP_DIR"
echo
echo "Concluído."
echo