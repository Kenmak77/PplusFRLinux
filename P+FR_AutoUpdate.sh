#!/bin/bash
#
# ======================================================
#  Project+ FR Auto Installer & Updater (Linux v2)
# ======================================================
# Compatible : Ubuntu, Linux Mint, Arch, Manjaro, Fedora
# Author : Kenmak77
# Version : 2.5.0
#
# CHANGELOG
# v2.5.0
# - Téléchargement multi-méthode (aria2c → rclone → wget)
# - Installation optionnelle des outils manquants
# - Téléchargement automatique des fichiers .ini
# - Fermeture automatique du terminal après lancement
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
SCRIPT_VERSION="2.5.0"

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

# -------------------------------
# 🧰 INSTALLATION D’UN OUTIL MANQUANT (avec confirmation)
# -------------------------------
install_tool() {
    local pkg="$1"
    local manager

    # Détection du gestionnaire
    if command -v apt &>/dev/null; then
        manager="apt"
    elif command -v pacman &>/dev/null; then
        manager="pacman"
    elif command -v dnf &>/dev/null; then
        manager="dnf"
    else
        echo "❌ Aucun gestionnaire compatible trouvé. Installez $pkg manuellement."
        return 1
    fi

    if ! command -v "$pkg" &>/dev/null; then
        read -rp "⚙️  $pkg n’est pas installé. Voulez-vous l’installer ? (y/n): " rep
        if [[ "$rep" == "y" ]]; then
            case "$manager" in
                apt) sudo apt install -y "$pkg" ;;
                pacman) sudo pacman -S --noconfirm "$pkg" ;;
                dnf) sudo dnf install -y "$pkg" ;;
            esac
        else
            echo "⏭️  $pkg ne sera pas installé. Téléchargements limités aux outils disponibles."
        fi
    fi
}

# ---------------------------
# 📦 TÉLÉCHARGEMENT AVEC FALLBACK
# ---------------------------
download_file() {
    local url="$1"
    local output="$2"

    echo "⬇️ Téléchargement : $url"
    echo "➡️ Destination : $output"

    mkdir -p "$(dirname "$output")"

    if command -v aria2c &>/dev/null; then
        aria2c -x 16 -s 16 -o "$(basename "$output")" -d "$(dirname "$output")" "$url" && return 0
        echo "⚠️ aria2c a échoué, tentative avec rclone..."
    fi

    if command -v rclone &>/dev/null; then
        rclone copyurl "$url" "$output" --multi-thread-streams=8 && return 0
        echo "⚠️ rclone a échoué, tentative avec wget..."
    fi

    wget -O "$output" "$url" || {
        echo "❌ Impossible de télécharger $url"
        return 1
    }
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
# 📦 TÉLÉCHARGEMENTS SPÉCIFIQUES
# ---------------------------
download_appimage() { download_file "$APPIMAGE_URL" "$APPIMAGE_PATH"; }
download_zip() { download_file "$ZIP_URL" "$ZIP_PATH"; }
download_sd() { download_file "$(get_json_value "$UPDATE_JSON" "download-sd")" "$SD_PATH"; }

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
    download_file "$DOLPHIN_INI_URL" "$INSTALL_DIR/Config/Dolphin.ini"
    download_file "$GFX_INI_URL" "$INSTALL_DIR/Config/GFX.ini"
    download_file "$HOTKEYS_INI_URL" "$INSTALL_DIR/Config/Hotkeys.ini"
    echo "✅ Fichiers .ini installés dans Config/"
}

# ---------------------------
# 🖥️ RACCOURCI .DESKTOP
# ---------------------------
create_desktop_entry() {
    download_file "$ICON_URL" "$INSTALL_DIR/P+ fr.png"

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
    echo "✅ Dolphin lancé — fermeture du terminal dans 3 secondes..."
    sleep 3
    exit 0
}

# ---------------------------
# 🚀 FLUX PRINCIPAL DU SCRIPT
# ---------------------------
main() {
    install_tool wget
    install_tool unzip
    install_tool curl
    install_tool aria2c
    install_tool rclone

    mkdir -p "$INSTALL_DIR"

    local local_app_hash
    local_app_hash=$(get_local_hash "$APPIMAGE_PATH")

    if [[ "$local_app_hash" != "$REMOTE_HASH" ]]; then
        echo "🆕 Nouvelle version détectée."
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
