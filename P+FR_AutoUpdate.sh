#!/bin/bash
#
# ======================================================
#  Project+ FR Auto Installer & Updater (Linux v2)
# ======================================================
# Compatible : Ubuntu, Linux Mint, Arch, Manjaro, Fedora
# Author : Kenmak77
# Version : 2.0.2
#
# CHANGELOG
# v2.0.2
# - Suppression du téléchargement des fichiers GFX / Dolphin / Wiimote
# - Nettoyage et simplification du code
# - Multi-distribution (apt, pacman, dnf)
# - Vérifie AppImage et SD séparément
# - Télécharge le build (.zip) depuis update2.json
# - Création automatique du raccourci .desktop
# - Ecrase l'ancien SD.raw
# ======================================================


# -----------------------
# 🔧 CONFIGURATION DE BASE
# -----------------------
SCRIPT_VERSION="2.0.2"

INSTALL_DIR="$HOME/.local/share/P+FR"
APPIMAGE_PATH="$INSTALL_DIR/P+FR.AppImage"
ZIP_PATH="$INSTALL_DIR/P+FR_Build.zip"
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
    curl -s "$json_url" | grep -oP "\"$key\"\\s*:\\s*\"\\K[^\"]+"
}

# Récupération des URLs depuis update.json et update2.json
APPIMAGE_URL=$(get_json_value "$UPDATE_JSON" "download-linux-appimage")
SD_URL=$(get_json_value "$UPDATE_JSON" "download-sd")
SD_HASH=$(get_json_value "$UPDATE_JSON" "sd-hash-partial")
ZIP_URL=$(curl -s "$UPDATE2_JSON" | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' | head -1)
REMOTE_HASH=$(get_json_value "$UPDATE2_JSON" "hash-linux")


# ---------------------------
# 🔐 CALCUL DU HASH LOCAL
# ---------------------------
get_local_hash() {
    if [[ -f "$1" ]]; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    fi
}


# ---------------------------
# 📦 TÉLÉCHARGEMENTS
# ---------------------------

# Télécharge AppImage (wget uniquement)
download_appimage() {
    echo "⬇️ Téléchargement du AppImage..."
    wget -O "$APPIMAGE_PATH" "$APPIMAGE_URL"
}

# Télécharge le zip principal (wget)
download_zip() {
    echo "⬇️ Téléchargement du build..."
    wget -O "$ZIP_PATH" "$ZIP_URL"
}

# Télécharge la SD avec fallback aria2 → rclone → wget
# Télécharge la SD avec fallback aria2 → rclone → wget
download_sd() {
    echo "⬇️ Téléchargement de la SD..."
    mkdir -p "$INSTALL_DIR/Wii"

    # Supprime l'ancien fichier avant téléchargement
    if [[ -f "$SD_PATH" ]]; then
        echo "🧹 Suppression de l'ancienne SD..."
        rm -f "$SD_PATH"
    fi

    # Tentatives de téléchargement avec fallback
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
# 🧰 EXTRACTION ET INSTALLATION DU BUILD
# ---------------------------
extract_zip() {
    echo "📦 Extraction du build..."
    unzip -o "$ZIP_PATH" -d "$INSTALL_DIR/unzipped"
    mkdir -p "$INSTALL_DIR"/{Load,Launcher,Config}

    mv "$INSTALL_DIR/unzipped/P+FR_Netplay/P+FR Netplay/Launcher/"* "$INSTALL_DIR/Launcher/" 2>/dev/null || true
    mv "$INSTALL_DIR/unzipped/P+FR_Netplay/P+FR Netplay/User/Load/"* "$INSTALL_DIR/Load/" 2>/dev/null || true

    rm -rf "$INSTALL_DIR/unzipped"
    rm -f "$ZIP_PATH"
}


# ---------------------------
# 🖥️ RACCOURCI .DESKTOP
# ---------------------------
create_desktop_entry() {
    wget -nc -q -O "$INSTALL_DIR/P+ fr.png" "$ICON_URL"
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=P+FR
Exec=sh -c '$INSTALL_DIR/$SCRIPT_NAME'
Icon=$INSTALL_DIR/P+ fr.png
Terminal=true
Categories=Game;
EOF
    chmod +x "$DESKTOP_FILE"
    echo "✅ Raccourci créé : $DESKTOP_FILE"
}


# ---------------------------
# 🎮 LANCEMENT DU JEU
# ---------------------------
launch_app() {
    chmod +x "$APPIMAGE_PATH"
    setsid "$APPIMAGE_PATH" -u "$INSTALL_DIR" >/dev/null 2>&1 < /dev/null &
    exit 0
}


# ---------------------------
# 🚀 FLUX PRINCIPAL DU SCRIPT
# ---------------------------
main() {
    verify_script_update

    # Vérifie dépendances minimales
    install_if_missing wget
    install_if_missing unzip
    install_if_missing curl

    local local_app_hash local_sd_hash

    local_app_hash=$(get_local_hash "$APPIMAGE_PATH")
    local_sd_hash=$(get_local_hash "$SD_PATH")

    mkdir -p "$INSTALL_DIR"

    # Vérifie si AppImage ou SD ont changé
    if [[ "$local_app_hash" != "$REMOTE_HASH" ]]; then
        echo "🆕 Nouvelle version AppImage détectée."
        download_appimage
    fi

    if [[ "$local_sd_hash" != "$SD_HASH" ]]; then
        echo "🆕 Nouvelle version de la SD détectée."
        download_sd
    fi

    if [[ ! -d "$INSTALL_DIR/Load" ]]; then
        download_zip
        extract_zip
    fi

    cp "$0" "$INSTALL_DIR/$SCRIPT_NAME"
    create_desktop_entry

    echo -e "\n✅ Installation complète ! Lancement du jeu..."
    launch_app
}


# ---------------------------
# 🏁 LANCEMENT DU SCRIPT
# ---------------------------
main
