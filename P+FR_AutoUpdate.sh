#!/bin/bash
#
# ======================================================
#  Project+ FR Auto Installer & Updater (Linux v2)
# ======================================================
# Compatible : Ubuntu, Linux Mint, Arch, Manjaro, Fedora
# Author : Kenmak77
# Version : 2.6.5
#
# CHANGELOG
# v2.6.5
# - Téléchargement SD multi-méthode (aria2c → rclone → wget)
# - AppImage & ZIP forcés en HTTP (wget)
# - SD téléchargée avant AppImage
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
SCRIPT_VERSION="2.6.7"

INSTALL_DIR="$HOME/.local/share/P+FR"
APPIMAGE_PATH="$INSTALL_DIR/P+FR.AppImage"
APPIMAGE_PATH2="$INSTALL_DIR/Ishiiruka/IshiirukaP+FR.appimage"
ZIP_PATH="$INSTALL_DIR/P+FR_Netplay2.zip"
SD_PATH="$INSTALL_DIR/Wii/sd.raw"
UPDATE_JSON="https://update.pplusfr.org/update.json"
UPDATE2_JSON="https://update.pplusfr.org/update2.json"
SCRIPT_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P+FR_AutoUpdate.sh"
SCRIPT_URL2="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Ishiiruka/P%2BFR_Ishii.sh"
SCRIPT_NAME="P+FR_AutoUpdate.sh"
ICON_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P%2B%20fr.png"
ICON_URL2="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/P%2B%20frishii.png"

DOLPHIN_INI_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Dolphin.ini"
GFX_INI_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/GFX.ini"
HOTKEYS_INI_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Hotkeys.ini"

DOLPHIN_INI_URL2="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Ishiiruka/Dolphin.ini"
GFX_INI_URL2="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Ishiiruka/GFX.ini"
HOTKEYS_INI_URL2="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/Ishiiruka/Hotkeys.ini"

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
# ⚙️  AJOUT DES FICHIERS DE GAMESETTINGS PAR DÉFAUT
# ---------------------------
download_gamesettings_files() {
    local gamesettings_dir="$INSTALL_DIR/GameSettings"
    local gamesettings_dir2="$INSTALL_DIR/Ishiiruka/GameSettings"
    local gamesettings_dir3="$INSTALL_DIR"
    mkdir -p "$gamesettings_dir"
    mkdir -p "$gamesettings_dir2"

    local ID_NETPLAY_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/ID-Project%2BFR%20Netplay%20Launcher.ini"
    local ID_OFFLINE_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/refs/heads/main/ID-Project%2BFR%20Offline%20Launcher.ini"

    echo "🧩 Vérification des GameSettings..."

    # Télécharge uniquement si les fichiers sont absents
    if [[ ! -f "$gamesettings_dir/ID-Project+FR Netplay Launcher.ini" ]]; then
        wget -q -O "$gamesettings_dir/ID-Project+FR Netplay Launcher.ini" "$ID_NETPLAY_URL"
        echo "File Add: ID-Project+FR Netplay Launcher.ini"
    fi

    if [[ ! -f "$gamesettings_dir/ID-Project+FR Offline Launcher.ini" ]]; then
        wget -q -O "$gamesettings_dir/ID-Project+FR Offline Launcher.ini" "$ID_OFFLINE_URL"
        echo "File Add : ID-Project+FR Offline Launcher.ini"
    fi

     if [[ ! -f "$gamesettings_dir2/ID-Project+FR Netplay Launcher.ini" ]]; then
        wget -q -O "$gamesettings_dir2/ID-Project+FR Netplay Launcher.ini" "$ID_NETPLAY_URL"
        echo "File Add: ID-Project+FR Netplay Launcher.ini"
    fi

     if [[ ! -f "$gamesettings_dir2/ID-Project+FR Netplay Launcher.ini" ]]; then
        wget -q -O "$gamesettings_dir2/ID-Project+FR Netplay Launcher.ini" "$ID_OFFLINE_URL"
        echo "File Add: ID-Project+FR Netplay Launcher.ini"

    fi
         if [[ ! -f "$gamesettings_dir3/P+FR_Ishii.sh" ]]; then
        wget -q -O "$gamesettings_dir3/P+FR_Ishii.sh" "$SCRIPT_URL2"
        echo "File Add: ID-Project+FR Netplay Launcher.ini"
    
    fi
}

# -------------------------------
# 🧰 INSTALLATION D’UN OUTIL MANQUANT (avec confirmation)
# -------------------------------
install_tool() {
    local pkg="$1"
    local manager

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
# 🌐 RÉCUPÉRATION DES DONNÉES JSON
# ---------------------------
get_json_value() {
    local json_url="$1"
    local key="$2"
    curl -s "$json_url" | grep -oP "\"${key//-/\\-}\"\\s*:\\s*\"\\K[^\"]+"
}

APPIMAGE_URL=$(get_json_value "$UPDATE_JSON" "download-linux-appimage")
APPIMAGE_URL2=$(get_json_value "$UPDATE_JSON" "download-linux-appimage-ishii")
ZIP_URL=$(curl -s "$UPDATE2_JSON" | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' | head -1)
REMOTE_HASH=$(get_json_value "$UPDATE2_JSON" "hash-linux")
SD_URL=$(get_json_value "$UPDATE_JSON" "download-sd")

# ---------------------------
# 🔐 CALCUL DU HASH LOCAL
# ---------------------------
get_local_hash() {
    [[ -f "$1" ]] && sha1sum "$1" 2>/dev/null | awk '{print $1}'
}

# ---------------------------
# 📦 TÉLÉCHARGEMENTS (corrigé)
# ---------------------------

download_sd() {
    echo "⬇️ Download SD CARD..."
    mkdir -p "$(dirname "$SD_PATH")"

    if [[ -f "$SD_PATH" ]]; then
        echo "🧹 Delete Old SD.raw..."
        rm -f "$SD_PATH"
    fi

    local success=false

    if command -v aria2c &>/dev/null; then
        echo "➡️  Using aria2c..."
        aria2c -x 16 -s 16 -o "sd.raw" -d "$(dirname "$SD_PATH")" "$SD_URL" && success=true
    fi

    if [[ "$success" == false && $(command -v rclone) ]]; then
        echo "➡️  aria2c failed or missing, trying rclone..."
        rclone copyurl "$SD_URL" "$SD_PATH" --multi-thread-streams=8 && success=true
    fi

    if [[ "$success" == false ]]; then
        echo "➡️  aria2c/rclone unavailable — fallback to wget..."
        wget -c --timeout=30 --tries=3 --no-dns-cache --progress=bar:force:noscroll -O "$SD_PATH" "$SD_URL" && success=true
    fi

    if [[ "$success" == true ]]; then
        echo "✅ SD downloaded successfully."
        ls -s "$INSTALL_DIR/Wii/sd.raw" "$INSTALL_DIR/Ishiiruka/Wii/"
    else
        echo "❌ Failed to download SD file."
    fi
}

download_appimage() {
    echo "⬇️ Download AppImage..."
    mkdir -p "$(dirname "$APPIMAGE_PATH")"

    if [[ -f "$APPIMAGE_PATH" ]]; then
        echo "🧹 Removing old AppImage..."
        rm -f "$APPIMAGE_PATH"
    fi

    echo "➡️  Using wget for AppImage (HTTP only)..."
    if wget -O "$APPIMAGE_PATH" "$APPIMAGE_URL";
       wget -O "$APPIMAGE_PATH2" "$APPIMAGE_URL2"; then
        echo "✅ AppImage downloaded successfully."
    else
        echo "❌ AppImage download failed!"
    fi
}

download_zip() {
    echo "⬇️ Download build..."
    wget -c --timeout=30 --tries=3 --no-dns-cache --progress=bar:force:noscroll \
         -O "$ZIP_PATH" "$ZIP_URL"
}
# ---------------------------
# 🧰 EXTRACTION DU BUILD
# ---------------------------
extract_zip() {
    echo "📦 Extract build..."
    unzip -o "$ZIP_PATH" -d "$INSTALL_DIR/unzipped"

    mkdir -p "$INSTALL_DIR"/{Load,Launcher,Config}
    mv "$INSTALL_DIR/unzipped/user/Launcher/"* "$INSTALL_DIR/Launcher/" 2>/dev/null || true
    ls -s "$INSTALL_DIR/Launcher/" "$INSTALL_DIR/User/Launcher"
    mv "$INSTALL_DIR/unzipped/user/Load/"* "$INSTALL_DIR/Load/" 2>/dev/null || true
    mv "$INSTALL_DIR/unzipped/user/Wii/title" "$INSTALL_DIR/Wii/" 2>/dev/null || true  
    
    mv "$INSTALL_DIR/unzipped/Ishiiruka P+FR/User/Wii/title" "$INSTALL_DIR/Ishiiruka/Wii/" 2>/dev/null || true
    mv "$INSTALL_DIR/unzipped/Ishiiruka P+FR/User/Load/"* "$INSTALL_DIR/Ishiiruka/Load/" 2>/dev/null || true
    
    rm -rf "$INSTALL_DIR/unzipped"
    rm -f "$ZIP_PATH"
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
Exec=$INSTALL_DIR/$SCRIPT_NAME
Icon=$INSTALL_DIR/P+ fr.png
Terminal=true
Categories=Game;
EOF

    chmod +x "$desktop_local"
}

create_desktop_entry() {
    wget -nc -q -O "$INSTALL_DIR/P+ frishii.png" "$ICON_URL2"

    local desktop_local="$INSTALL_DIR/Ishiiruka P+FR.desktop"
    local desktop_user="$DESKTOP_PATH/Ishiiruka P+FR.desktop"

    cat > "$desktop_local" <<EOF
[Desktop Entry]
Type=Application
Name=Ishiiruka P+FR
Exec=$INSTALL_DIR/P+FR_Ishii.sh
Icon=$INSTALL_DIR/P+ frishii.png
Terminal=true
Categories=Game;
EOF

    chmod +x "$desktop_local"
}

# ---------------------------
# 🎮 LANCEMENT DU JEU
# ---------------------------
launch_app() {
    chmod +x "$APPIMAGE_PATH"
    echo "🎮 Démarrage de Project+ FR..."
    cd "$INSTALL_DIR" || exit 1

    # Lancement en tâche de fond, détachée du terminal
    nohup "$APPIMAGE_PATH" -u "$INSTALL_DIR" >/dev/null 2>&1 &
    disown

    sleep 3
    echo "✅ Launch Dolphin... You can exit, Launch .desktop to keep P+FR update"
    

    # Ferme complètement le terminal sans message
    exec bash -c "sleep 0.5; exit"
}

# ---------------------------
# ⚙️  TÉLÉCHARGEMENT DES FICHIERS DE CONFIG PAR DÉFAUT (UNIQUEMENT SI ABSENTS)
# ---------------------------
download_default_configs() {
    local config_dir="$INSTALL_DIR/Config"
    mkdir -p "$config_dir"

    local GFX_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/GFX.ini"
    local DOLPHIN_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/Dolphin.ini"
    local HOTKEYS_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/Hotkeys.ini"
    local WIIMOTE_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/WiimoteNew.ini"

    [[ -f "$config_dir/GFX.ini" ]] || wget -q -O "$config_dir/GFX.ini" "$GFX_URL"
    [[ -f "$config_dir/Dolphin.ini" ]] || wget -q -O "$config_dir/Dolphin.ini" "$DOLPHIN_URL"
    [[ -f "$config_dir/Hotkeys.ini" ]] || wget -q -O "$config_dir/Hotkeys.ini" "$HOTKEYS_URL"
    [[ -f "$config_dir/WiimoteNew.ini" ]] || wget -q -O "$config_dir/WiimoteNew.ini" "$WIIMOTE_URL"

    echo "✅ Configs checked"
}


# ---------------------------
# 🚀 Main
# ---------------------------
main() {
    
    
    verify_script_update
 
    install_tool wget
    install_tool unzip
    install_tool curl
    

    mkdir -p "$INSTALL_DIR"
    
    download_gamesettings_files
    
    local local_app_hash
    local_app_hash=$(get_local_hash "$APPIMAGE_PATH")

    # Si AppImage absente ou hash différent → nouvelle version
    if [[ ! -f "$APPIMAGE_PATH" || "$local_app_hash" != "$REMOTE_HASH" ]]; then
        echo "🆕 New version Detected"
        install_tool aria2c
        install_tool rclone
        
        download_sd
        echo "⬇️ DownloadAppImage..."
        download_appimage
        echo "⬇️ Download build..."
        download_zip
        extract_zip
    else
        echo "✅ AppImage Update"
    fi

    # ✅ Copie du script dans P+FR/
    cp "$0" "$INSTALL_DIR/$SCRIPT_NAME"

    download_default_configs
     
    create_desktop_entry

    echo -e "\n✅ Installation complete !"
    echo "🚀 Lancement de P+FR..."
    sleep 2
    launch_app
}

# ---------------------------
# 🏁 LANCEMENT DU SCRIPT
# ---------------------------
main
