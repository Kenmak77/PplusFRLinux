#!/bin/bash
# ======================================================
# 🚀 P+FR Ishiiruka Smart Launcher
# ======================================================

INSTALL_DIR="$HOME/.local/share/P+FR"
MAIN_APPIMAGE="$INSTALL_DIR/P+FR.AppImage"
ISHII_APPIMAGE="$INSTALL_DIR/Ishiiruka/IshiirukaP+FR.Appimage"
SCRIPT_PATH="$INSTALL_DIR/P+FR_AutoUpdate.sh"
UPDATE2_JSON="https://update.pplusfr.org/update2.json"

# --- RÉCUPÉRATION DES DONNÉES ---
get_json_value() {
    curl -s "$1" | grep -oP "\"$2\"\s*:\s*\"\K[^\"]+"
}

get_local_hash() {
    [[ -f "$1" ]] && sha1sum "$1" 2>/dev/null | awk '{print $1}'
}

# --- ÉCRAN DE VÉRIFICATION ---
clear
echo "------------------------------------------"
echo "   🔍 P+FR : Vérification de version...   "
echo "------------------------------------------"

REMOTE_HASH=$(get_json_value "$UPDATE2_JSON" "hash-linux")
LOCAL_HASH=$(get_local_hash "$MAIN_APPIMAGE")

echo "Distant : [${REMOTE_HASH:0:10}...]"
echo "Local   : [${LOCAL_HASH:0:10}...]"

if [[ -z "$REMOTE_HASH" ]]; then
    echo "⚠️ Serveur injoignable. Lancement hors-ligne..."
    sleep 2
elif [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
    echo "🆕 Mise à jour détectée ! Lancement de l'installeur..."
    sleep 1
    bash "$SCRIPT_PATH"
    exit 0
fi

# --- LANCEMENT DÉTACHÉ ---
if [[ -f "$ISHII_APPIMAGE" ]]; then
    echo "✅ À jour. Lancement d'Ishiiruka..."
    cd $HOME/.local/share/P+FR/Ishiiruka
    chmod +x "$ISHII_APPIMAGE"
    
    # Utiliser setsid pour détacher totalement le processus du terminal
    setsid "$ISHII_APPIMAGE" -u "$INSTALL_DIR/Ishiiruka" >/dev/null 2>&1 &
    
    sleep 1
    exit 0
else
    echo "❌ Erreur : AppImage Ishiiruka introuvable !"
    read -p "Appuyez sur Entrée pour lancer la réparation..."
    bash "$SCRIPT_PATH"
fi
