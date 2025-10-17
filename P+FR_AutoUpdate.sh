#!/bin/bash
#
# ======================================================
#  Project+ FR Auto Installer & Updater (Linux v2)
# ======================================================
# Compatible : Ubuntu, Linux Mint, Arch, Manjaro, Fedora
# Author : Kenmak77
# Version : 2.4.0
#
# CHANGELOG
# v2.4.0
# - Téléchargement automatique des fichiers .ini depuis GitHub
# - Terminal se ferme après le lancement de Dolphin
# - Code simplifié et nettoyé
# ======================================================

# ======================================================
# 🔹 Force l’ouverture du script dans un terminal visible
# ======================================================
if [ -z "$TERM" ] || [ ! -t 1 ]; then
    TERMINAL_CMD=""
    if command -v gnome-terminal &>/dev/null; then
        TERMINAL_CMD="gnome-terminal -- bash -c"
    elif command -v konsole &>/dev/null; then
        TERMINAL_CMD="konsole -e bash -c"
    elif command -v xfce4-terminal &>/dev/null; then
        TERMINAL_CMD="xfce4-terminal -e"
    elif command -v xterm &>/dev/null; then
        TERMINAL_CMD="xterm -e"
    fi

    if [ -n "$TERMINAL_CMD" ]; then
        $TERMINAL_CMD "'$0'; exec bash"
        exit 0
    else
        echo "⚠️ Aucun terminal graphique trouvé. Exécutez ce script depuis un terminal."
        exit 1
    fi
fi

# -----------------------
# 🔧 CONFIGURATION DE BASE
# -----------------------
SCRIPT_VERSION="2.4.0"

INSTALL_DIR="$HOME/.local/share/P+FR"
APPIMAGE_PATH="$INSTALL_DIR/P+FR.AppImage"
ZIP_PATH="$INSTALL_DIR/P+FR_Netplay2.zip"
SD_PATH="$INSTALL_DIR/Wii/sd.raw"
UPDATE_JSON="https://update.pplusfr.org/update.json"
UPDATE2_JSON="https://update.pplusfr.org/update2.json"
SCRIPT_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P+FR_AutoUpdate.sh"
SCRIPT_NAME="P+FR_AutoUpdate.sh"
ICON_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P%2B%20fr.png"

# URLs des fichiers de configuration
DOLPHIN_INI_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Dolphin.ini"
GFX_INI_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/GFX.ini"
HOTKEYS_INI_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Hotkeys.ini"

# 🔹 Localisation du dossier Desktop selon la langue
if [ -d "$HOME/Desktop" ]; then
    DESKTOP_PATH="$HOME/Desktop"
elif [ -d "$HOME/Bureau" ]; then
    DESKTOP_PATH="$HOME/Bureau"
else
    DESKTOP_PATH="$HOME/Desktop"
    mkdir -p "$DESKTOP_PATH"
fi
DESKTOP_FILE="$DESKTOP_PATH/P+FR.desktop"

# ---------------------------
# 🧩 DÉTECTION DU PACKAGE MANAGER
# ---------------------------
detect_package_manager() {
    if command -v apt &>/dev/null; then
        echo "apt"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    else
        echo ""
    fi
}

# -------------------------------
# 🧰 INSTALLATION D’UN OUTIL MANQUANT
# -------------------------------
install_if_missing() {
    local pkg="$1"
    if ! command -v "$pkg" &>/dev/null; then
        echo "⚙️  $pkg n’est pas installé. Installation..."
        case $(detect_package_manager) in
            apt) sudo apt install -y "$pkg" ;;
            pacman) sudo pacman -S --noconfirm "$pkg" ;;
            dnf) sudo dnf install -y "$pkg" ;;
            *) echo "❌ Aucun gestionnaire compatible trouvé. Installez $pkg manuellement."; return 1 ;;
        esac
    fi
}

# ---------------------------
# 🧠 AUTO-MISE À JOUR DU SCRIPT
# ---------------------------
verify_script_update() {
    local tmp_script
    tmp_script="$(mktemp)"
    wget -q -O "$tmp_script" "$SCRIPT_URL" || return
    local remote_version
    remote_version=$(grep '^SCRIPT_VERSION=' "$tmp_script" | cut -d '"' -f2)

    if [[ "$remote_version" != "$SCRIPT_VERSION" && -n "$remote_version" ]]; then
        echo -e "\n🔄 Nouvelle version du script disponible : $remote_version (local $SCRIPT_VERSION)"
        read -rp "Mettre à jour le script automatiquement ? (y/n): " rep
        if [[ "$rep" == "y" ]]; then
            mkdir -p "$INSTALL_DIR"
            wget -q -O "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL"
            echo "✅ Script mis à jour."
            read -rp "Relancer maintenant la nouvelle version ? (y/n): " relaunch
            if [[ "$relaunch" == "y" ]]; then
                bash "$INSTALL_DIR/$SCRIPT_NAME"
                exit 0
            fi
        fi
    fi
    rm -f "$tmp_script"
}

# ---------------------------
# 🌐 RÉCUPÉRATION DES DONNÉES JSON
# ---------------------------
get_json_value() {
    local json_url="$1"
    local key="$2"
    curl -s "$json_url" | grep -oP "\"${key//-/\\-}\"\\s*:\\s*\"\\K[^\"]+"
}

APPIMAGE_URL=$(get_json_value "$UPDATE_JSON" "download-linux-appimage")
ZIP_URL=$(curl -s "$UPDATE2_JSON" | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' | head -1)
REMOTE_HASH=$(get_json_value "$UPDATE2_JSON" "hash-linux")

# ---------------------------
# 🔐 CALCUL DU HASH LOCAL
# ---------------------------
get_local_hash() {
    [[ -f "$1" ]] && sha1sum "$1" 2>/dev/null | awk '{print $1}'
}

# ---------------------------
# 📦 TÉLÉCHARGEMENTS
# ---------------------------
download_appimage() {
    echo "⬇️ Téléchargement du AppImage..."
    wget -O "$APPIMAGE_PATH" "$APPIMAGE_URL"
}

download_zip() {
    echo "⬇️ Téléchargement du build..."
    wget -O "$ZIP_PATH" "$ZIP_URL"
}

download_sd() {
    echo "⬇️ Téléchargement de la SD..."
    mkdir -p "$INSTALL_DIR/Wii"
    wget -O "$SD_PATH" "$(get_json_value "$UPDATE_JSON" "download-sd")"
}

# ---------------------------
# 🧰 EXTRACTION DU BUILD
# ---------------------------
extract_zip() {
    echo "📦 Extraction du build..."
    unzip -o "$ZIP_PATH" -d "$INSTALL_DIR/unzipped"

    mkdir -p "$INSTALL_DIR"/{Load,Launcher,Config}
    mv "$INSTALL_DIR/unzipped/user/Launcher/"* "$INSTALL_DIR/Launcher/" 2>/dev/null || true
    mv "$INSTALL_DIR/unzipped/user/Load/"* "$INSTALL_DIR/Load/" 2>/dev/null || true

    if [[ ! -d "$INSTALL_DIR/Wii" ]]; then
        echo "📁 Déplacement du dossier Wii..."
        mv "$INSTALL_DIR/unzipped/user/Wii" "$INSTALL_DIR/" 2>/dev/null || true
    fi

    rm -rf "$INSTALL_DIR/unzipped"
    rm -f "$ZIP_PATH"
}

# ---------------------------
# ⚙️ CONFIGURATION DES FICHIERS INI
# ---------------------------
setup_ini_files() {
    mkdir -p "$INSTALL_DIR/Config"

    echo "⬇️ Téléchargement des fichiers de configuration..."
    wget -q -O "$INSTALL_DIR/Config/Dolphin.ini" "$DOLPHIN_INI_URL"
    wget -q -O "$INSTALL_DIR/Config/GFX.ini" "$GFX_INI_URL"
    wget -q -O "$INSTALL_DIR/Config/Hotkeys.ini" "$HOTKEYS_INI_URL"
    echo "✅ Fichiers .ini installés dans Config/"
}

# ---------------------------
# 🖥️ RACCOURCI .DESKTOP
# ---------------------------
create_desktop_entry() {
    wget -nc -q -O "$INSTALL_DIR/P+ fr.png" "$ICON_URL"
    local desktop_local="$INSTALL_DIR/P+FR.desktop"
    local desktop_user="$DESKTOP_PATH/P+FR.desktop"

    cat > "$desktop_local" <<EOF
[Desktop Entry]
Type=Application
Name=P+FR
Exec=sh -c '$INSTALL_DIR/$SCRIPT_NAME'
Icon=$INSTALL_DIR/P+ fr.png
Terminal=true
Categories=Game;
EOF

    chmod +x "$desktop_local"
    cp "$desktop_local" "$desktop_user"
    chmod +x "$desktop_user"
    echo "✅ Raccourci créé : $desktop_user"
}

# ---------------------------
# 🎮 LANCEMENT DU JEU
# ---------------------------
launch_app() {
    chmod +x "$APPIMAGE_PATH"
    echo "🎮 Démarrage de Project+ FR..."
    cd "$INSTALL_DIR" || exit 1
    nohup "$APPIMAGE_PATH" -u "$INSTALL_DIR" >/dev/null 2>&1 &
    sleep 4
    echo "✅ Dolphin lancé — fermeture du terminal..."
    sleep 1
    exit 0
}

# ---------------------------
# 🚀 FLUX PRINCIPAL DU SCRIPT
# ---------------------------
main() {
    verify_script_update
    install_if_missing wget
    install_if_missing unzip
    install_if_missing curl

    mkdir -p "$INSTALL_DIR"

    local local_app_hash
    local_app_hash=$(get_local_hash "$APPIMAGE_PATH")

    if [[ "$local_app_hash" != "$REMOTE_HASH" ]]; then
        echo "🆕 Mise à jour détectée."
        download_appimage
        download_sd
        download_zip
        extract_zip
    fi

    setup_ini_files
    create_desktop_entry

    echo -e "\n✅ Installation complète !"
    echo "🚀 Lancement de P+FR..."
    sleep 2
    launch_app
}

# ---------------------------
# 🏁 LANCEMENT DU SCRIPT
# ---------------------------
main
