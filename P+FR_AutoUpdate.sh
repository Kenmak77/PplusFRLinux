#!/bin/bash

SCRIPT_VERSION="1.0.0"

INSTALL_DIR="$HOME/.local/share/P+FR"
APPIMAGE_PATH="$INSTALL_DIR/P+FR.AppImage"
APPIMAGE_URL="https://pplusfr.org/P%2BFR.AppImage"
ZIP_URL="https://pplusfr.org/P%2BFR_Netplay.zip"
ZIP_PATH="$INSTALL_DIR/P+FR_Netplay.zip"
UPDATE_JSON="https://update.pplusfr.org/update.json"
GFX_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/GFX.ini"
DOLPHIN_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/Dolphin.ini"
KEY_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/Hotkeys.ini"
WII_REMOTE="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/WiimoteNew.ini"
ICON_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P%2B%20fr.png"
SCRIPT_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P%2BFR_AutoUpdate.sh"
SCRIPT_NAME="P+FR_AutoUpdate.sh"
DESKTOP_FILE="$HOME/Desktop/P+FR.desktop"

# 🔹 Vérifie si le script local est à jour
verify_script_update() {
    local tmp_script="$(mktemp)"
    wget -q -O "$tmp_script" "$SCRIPT_URL"
    remote_version=$(grep '^SCRIPT_VERSION=' "$tmp_script" | cut -d '"' -f2)
    local_version="$SCRIPT_VERSION"

    if [[ "$remote_version" != "$local_version" ]]; then
        echo -e "\n🔄 A new version of this script is available (local: $local_version → remote: $remote_version)."
        read -rp "Do you want to update it automatically? (y/n): " update_script
        if [[ "$update_script" == "y" ]]; then
            wget -O "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL"
            echo "✅ Script updated."
            read -rp "Do you want to relaunch the updated script now? (y/n): " relaunch
            if [[ "$relaunch" == "y" ]]; then
                bash "$INSTALL_DIR/$SCRIPT_NAME"
                exit 0
            else
                echo "❌ Please relaunch the updated script manually."
                exit 0
            fi
        else
            echo "❌ Please update the script before continuing."
            exit 1
        fi
    fi
    rm -f "$tmp_script"
}

verify_script_update

# 🔹 Nettoyage partiel si interruption
trap 'echo -e "\n⚠️ Script interrupted. Cleaning up..."; [[ -f "$ZIP_PATH" ]] && rm -f "$ZIP_PATH"; exit 1' INT TERM

# 🔹 Récupère le hash local de l'AppImage
get_local_hash() {
    [[ -f "$APPIMAGE_PATH" ]] && sha1sum "$APPIMAGE_PATH" | awk '{print $1}'
}

# 🔹 Récupère le hash distant depuis update.json
get_remote_hash() {
    curl -s "$UPDATE_JSON" | grep -oP '"hash-linux"\s*:\s*"\K[a-f0-9]+(?=")'
}

# 🔹 Vérifie l'intégrité du fichier téléchargé
verify_appimage_hash() {
    local downloaded_hash=$(sha1sum "$APPIMAGE_PATH" | awk '{print $1}')
    if [[ "$downloaded_hash" != "$remote_hash" ]]; then
        echo "❌ Hash mismatch! The downloaded AppImage does not match the expected hash."
        echo "Expected: $remote_hash"
        echo "Got: $downloaded_hash"
        echo "Aborting installation."
        rm -f "$APPIMAGE_PATH"
        exit 1
    fi
}

# 🔹 Récupère le changelog
get_changelog() {
    curl -s "$UPDATE_JSON" | grep -oP '"changelog"\s*:\s*".*?"' | sed -E 's/"changelog"\s*:\s*"(.*)"/\1/'
}

# 🔹 Récupère la version
get_version() {
    curl -s "$UPDATE_JSON" | grep -oP '"version"\s*:\s*".*?"' | sed -E 's/"version"\s*:\s*"(.*)"/\1/'
}

# 🔹 Lancer l'application
launch_app() {
    chmod +x "$APPIMAGE_PATH"
    setsid "$APPIMAGE_PATH" -u "$INSTALL_DIR" >/dev/null 2>&1 < /dev/null &
    sleep 2
    exit 0
}

# 🔹 Installer un outil s’il est absent
ask_install() {
    if ! command -v "$1" &>/dev/null; then
        read -rp "$1 is not installed (Highly speeds up download). Install? (y/n): " rep
        if [[ "$rep" == "y" ]]; then
            sudo apt install -y "$1"
        fi
    fi
}

# 🔹 Téléchargement avec fallback
download_zip() {
    echo "Downloading P+FR_Netplay.zip..."
    if command -v aria2c &>/dev/null; then
        aria2c -x 16 -s 16 -d "$INSTALL_DIR" -o "P+FR_Netplay.zip" "$ZIP_URL" && return
        echo "aria2c error, trying with rclone..."
    fi
    if command -v rclone &>/dev/null; then
        rclone copyurl "$ZIP_URL" "$ZIP_PATH" --multi-thread-streams=8 && return
        echo "rclone error, trying with wget..."
    fi
    wget -O "$ZIP_PATH" "$ZIP_URL"
}

# 🔹 Extraction et déplacement des bons fichiers
extract_files() {
    unzip -o "$ZIP_PATH" -d "$INSTALL_DIR/unzipped"

    mkdir -p "$INSTALL_DIR/Wii"
    rm -rf "$INSTALL_DIR/Load"
    mkdir -p "$INSTALL_DIR/Load"
    mkdir -p "$INSTALL_DIR/Launcher"
    mkdir -p "$INSTALL_DIR/Config"

    mv "$INSTALL_DIR/unzipped/P+FR_Netplay/P+FR Netplay/User/Wii/sd.raw" "$INSTALL_DIR/Wii/"
    mv "$INSTALL_DIR/unzipped/P+FR_Netplay/P+FR Netplay/User/Load/"* "$INSTALL_DIR/Load/"
    mv "$INSTALL_DIR/unzipped/P+FR_Netplay/P+FR Netplay/Launcher/"* "$INSTALL_DIR/Launcher"

    [[ -f "$INSTALL_DIR/Config/GFX.ini" ]] || wget -O "$INSTALL_DIR/Config/GFX.ini" "$GFX_URL"
    [[ -f "$INSTALL_DIR/Config/Dolphin.ini" ]] || wget -O "$INSTALL_DIR/Config/Dolphin.ini" "$DOLPHIN_URL"
    [[ -f "$INSTALL_DIR/Config/Hotkeys.ini" ]] || wget -O "$INSTALL_DIR/Config/Hotkeys.ini" "$KEY_URL"
    [[ -f "$INSTALL_DIR/Config/WiimoteNew.ini" ]] || wget -O "$INSTALL_DIR/Config/WiimoteNew.ini" "$WII_REMOTE"
    [[ -f "$INSTALL_DIR/P+ fr.png" ]] || wget -O "$INSTALL_DIR/P+ fr.png" "$ICON_URL"

    rm -rf "$INSTALL_DIR/unzipped"
    rm -f "$ZIP_PATH"
}

# 🔹 Créer le raccourci sur le bureau
create_desktop_entry() {
    mkdir -p "$HOME/.local/share/applications"
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=P+FR
Exec=$INSTALL_DIR/$SCRIPT_NAME
Icon=$INSTALL_DIR/P+ fr.png
Terminal=false
Categories=Game;
EOF
    chmod +x "$DESKTOP_FILE"
}

# 🔹 Message de fin
end() {
    chmod +x "$DESKTOP_FILE"
    echo -e "\n✅ The 'P+FR' shortcut has been created on the Desktop."
    echo "📁 The build is installed in: $INSTALL_DIR"
    echo "⚠️ Keep this script if .deskpot is delet, launch it and a new one is creat"
    echo "🎮 Launch P+FR from the desktop shortcut. Enjoy!"
    read -p "Press any key to start P+FR..." -n1 -s
}

# 🔹 Installation complète
install_full() {
    echo "Installing P+FR..."
    mkdir -p "$INSTALL_DIR"
    wget -O "$APPIMAGE_PATH" "$APPIMAGE_URL"
    verify_appimage_hash
    download_zip
    extract_files
    cp "$0" "$INSTALL_DIR/$SCRIPT_NAME"
    create_desktop_entry
}

# 🔹 Vérification des outils
ask_install aria2c
ask_install rclone
ask_install unzip

# 🔹 Début du script — vérifier si à jour
remote_hash=$(get_remote_hash)
local_hash=$(get_local_hash)

if [[ -f "$APPIMAGE_PATH" ]]; then
    if [[ "$remote_hash" == "$local_hash" ]]; then
        echo "AppImage is up to date. Launching..."
        cd "$INSTALL_DIR"
        create_desktop_entry
        launch_app
    else
        changelog=$(get_changelog)
        version=$(get_version)
        echo -e "New update available!\nVersion: $version\nChangelog:\n$changelog"
        read -rp "Would you like to install the update? (y/n): " update_ok
        if [[ "$update_ok" != "y" ]]; then
            echo "Update cancelled. Launching existing AppImage."
            cd "$INSTALL_DIR"
            create_desktop_entry
            launch_app
        else
            echo "Installing version: $version"
            install_full
            cd "$INSTALL_DIR"
            create_desktop_entry
            launch_app
        fi
    fi
else
    version=$(get_version)
    echo "Installing version: $version"
    install_full
    cd "$INSTALL_DIR"
    create_desktop_entry
    end
    launch_app
fi
