#!/bin/bash
#
# ======================================================
#  Project+ FR Auto Installer & Updater (Linux v2)
# ======================================================
# Compatible : Ubuntu, Linux Mint, Arch, Manjaro, Fedora
# Author : Kenmak77
# Version : 2.3.1
#
# CHANGELOG
# v2.3.1
# - Lancement AppImage corrigé (plus de fermeture immédiate)
# - Hash SD pris depuis update2.json
# - Vérification propre SD + AppImage
# - Téléchargement stable et multi-distro
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
SCRIPT_VERSION="2.3.1"

INSTALL_DIR="$HOME/.local/share/P+FR"
APPIMAGE_PATH="$INSTALL_DIR/P+FR.AppImage"
ZIP_PATH="$INSTALL_DIR/P+FR_Netplay2.zip"
SD_PATH="$INSTALL_DIR/Wii/sd.raw"
UPDATE_JSON="https://update.pplusfr.org/update.json"
UPDATE2_JSON="https://update.pplusfr.org/update2.json"
SCRIPT_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P+FR_AutoUpdate.sh"
SCRIPT_NAME="P+FR_AutoUpdate.sh"
ICON_URL="https://raw.githubusercontent.com/Kenmak77/PplusFRLinux/main/P%2B%20fr.png"

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
# 🧩 CRÉATION DU FICHIER GFX.INI SI ABSENT
# ---------------------------
fix_gfx_ini() {
    local gfx_ini="$INSTALL_DIR/Config/GFX.ini"

    mkdir -p "$INSTALL_DIR/Config"

    if [[ ! -f "$gfx_ini" ]]; then
        echo "🆕 Création de GFX.ini avec les paramètres par défaut..."
        {
            echo "[Settings]"
            echo "InternalResolution = 3"
            echo "MSAA = 0x00000002"
            echo "SSAA = True"
            echo "ShaderCompilationMode = 1"
            echo "WaitForShadersBeforeStarting = True"
        } > "$gfx_ini"
    else
        echo "ℹ️ GFX.ini déjà présent — aucune modification."
    fi
}


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

# Récupération des URLs depuis update.json et update2.json
APPIMAGE_URL=$(get_json_value "$UPDATE_JSON" "download-linux-appimage")
SD_URL=$(get_json_value "$UPDATE_JSON" "download-sd")
SD_HASH=$(get_json_value "$UPDATE2_JSON" "sd-hash-partial")
ZIP_URL=$(curl -s "$UPDATE2_JSON" | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' | head -1)
REMOTE_HASH=$(get_json_value "$UPDATE2_JSON" "hash-linux")


# ---------------------------
# 🔐 CALCUL DU HASH LOCAL
# ---------------------------
get_local_hash() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *".AppImage")
                # 🧩 AppImage → hash SHA-1 complet (comme "hash-linux")
                sha1sum "$1" 2>/dev/null | awk '{print $1}'
                ;;
            *"sd.raw")
                # 💾 SD → hash SHA-256 sur 256 MB du début + 256 MB de la fin
                (
                    head -c $((256*1024*1024)) "$1"
                    tail -c $((256*1024*1024)) "$1"
                ) | sha256sum | awk '{print $1}'
                ;;
            *)
                # 🔹 Tout autre fichier → hash SHA-256 complet
                sha256sum "$1" 2>/dev/null | awk '{print $1}'
                ;;
        esac
    fi
}


# ---------------------------
# 📦 TÉLÉCHARGEMENTS
# ---------------------------

download_appimage() {
    echo "⬇️ Download AppImage..."
    wget -O "$APPIMAGE_PATH" "$APPIMAGE_URL"
}

download_zip() {
    echo "⬇️ Download (P+FR_Netplay2.zip)..."
    mkdir -p "$INSTALL_DIR"
    wget -O "$ZIP_PATH" "$ZIP_URL"
}


download_sd() {
    echo "⬇️ Download SD Card.."
    mkdir -p "$INSTALL_DIR/Wii"

    if [[ -f "$SD_PATH" ]]; then
        echo "🧹 Suppression de l'ancienne SD..."
        rm -f "$SD_PATH"
    fi

    if command -v aria2c &>/dev/null; then
        aria2c -x 16 -s 16 -d "$INSTALL_DIR/Wii" -o "sd.raw" "$SD_URL" && return
        echo "⚠️ aria2 a échoué, tentative avec rclone..."
    fi
    if command -v rclone &>/dev/null; then
        rclone copyurl "$SD_URL" "$SD_PATH" --multi-thread-streams=8 && return
        echo "⚠️ rclone a échoué, tentative avec wget..."
    fi

    wget -O "$SD_PATH" "$SD_URL"
}


# ---------------------------
# 🧰 EXTRACTION DU BUILD
# ---------------------------
extract_zip() {
    echo "📦 Extraction du build..."
    unzip -o "$ZIP_PATH" -d "$INSTALL_DIR/unzipped"

    mkdir -p "$INSTALL_DIR"/{Load,Launcher,Config}

    # Déplacement des dossiers Load & Launcher
    mkdir -p "$INSTALL_DIR/Launcher"
    mv "$INSTALL_DIR/unzipped/user/Launcher/"* "$INSTALL_DIR/Launcher/" 2>/dev/null || true

     echo "📁 Mise à jour du dossier Load..."
    rm -rf "$INSTALL_DIR/Load"
    mkdir -p "$INSTALL_DIR/Load"
    mv "$INSTALL_DIR/unzipped/user/Load/"* "$INSTALL_DIR/Load/" 2>/dev/null || true

    # Déplacement du dossier Wii uniquement s'il n'existe pas déjà
    if [[ ! -d "$INSTALL_DIR/Wii" ]]; then
        echo "📁 Déplacement du dossier Wii..."
        mv "$INSTALL_DIR/unzipped/user/Wii" "$INSTALL_DIR/" 2>/dev/null || true
    else
        echo "ℹ️ Dossier Wii déjà présent — conservé tel quel."
    fi

    rm -rf "$INSTALL_DIR/unzipped"
    rm -f "$ZIP_PATH"
}   # 👈 ici on referme bien extract_zip()


# ---------------------------
# 🧩 CRÉATION DU FICHIER DOLPHIN.INI SI ABSENT
# ---------------------------
fix_dolphin_ini() {
    local dolphin_ini="$INSTALL_DIR/Config/Dolphin.ini"

    mkdir -p "$INSTALL_DIR/Config"

    # Crée Dolphin.ini uniquement s'il n'existe pas
    if [[ ! -f "$dolphin_ini" ]]; then
        echo "🆕 Création de Dolphin.ini avec le thème par défaut..."
        {
            echo "[Interface]"
            echo "ThemeName = Clean Blue"
        } > "$dolphin_ini"
    else
        echo "ℹ️ Dolphin.ini déjà présent — aucune modification."
    fi
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
    echo "➡️  AppImage : $APPIMAGE_PATH"
    echo "➡️  Userdir : $INSTALL_DIR"

    # ✅ Se placer dans le dossier d’installation
    cd "$INSTALL_DIR" || {
        echo "❌ Impossible d’accéder à $INSTALL_DIR"
        exit 1
    }

    # 🏁 Lancer Dolphin en arrière-plan
    nohup "$APPIMAGE_PATH" -u "$INSTALL_DIR" >/dev/null 2>&1 &

    # ⏳ Attendre un peu pour laisser Dolphin se lancer
    sleep 3

    # 🧹 Fermer proprement le terminal
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

    local updated=false

    # — Si nouvelle AppImage, tout retélécharger (AppImage + SD + ZIP)
    if [[ "$local_app_hash" != "$REMOTE_HASH" ]]; then
        echo "🆕 Update detected."
        download_appimage
        echo "⬇️ Download SD Card..."
        download_sd
        echo "⬇️ Download .zip..."
        download_zip
        extract_zip
        updated=true
    else
        echo "✅ AppImage Update."
    fi

    # Création fichiers + raccourcis
    cp "$0" "$INSTALL_DIR/$SCRIPT_NAME"
    create_desktop_entry
    fix_dolphin_ini
    fix_gfx_ini

    echo -e "\n✅ Installation complete !"

    # Lancer le jeu dans une fenêtre terminal (pas silencieux)
    if [[ "$updated" == true ]]; then
        echo "🚀 Lancement de P+FR..."
        sleep 2
    fi

    # Lancement direct
    cd "$INSTALL_DIR" || exit 1
    "$APPIMAGE_PATH" -u "$INSTALL_DIR"
}



# ---------------------------
# 🏁 LANCEMENT DU SCRIPT
# ---------------------------
main
