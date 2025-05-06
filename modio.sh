#!/bin/bash

# Konfiguration
API_KEY=""
GAME_ID="" 
OUTPUT_DIR=""

# Optional: mkdir falls Zielordner nicht existiert
mkdir -p "$OUTPUT_DIR"

# Mods abrufen, die vom Nutzer abonniert wurden
echo "Abonnierte Mods abrufen..."
RESPONSE=$(curl -s -H "Authorization: Bearer $API_KEY" \
  "https://api.mod.io/v1/me/subscribed")

# Debug-Ausgabe der Antwortstruktur
# echo "$RESPONSE" | jq .

# Prüfen ob Daten vorhanden sind
if ! echo "$RESPONSE" | jq -e '.data | length > 0' >/dev/null; then
  echo "Keine abonnierten Mods gefunden oder Fehler bei API-Zugriff."
  echo "Antwort der API:"
  echo "$RESPONSE"
  exit 1
fi

# Mod-IDs extrahieren (angepasst)
MOD_IDS=$(echo "$RESPONSE" | jq -r '.data[].id')

# Jeden Mod herunterladen
for MOD_ID in $MOD_IDS; do
  echo "Lade Mod ID $MOD_ID herunter..."

  # Mod-Datei-Info abrufen
  FILE_INFO=$(curl -s \
    -H "Authorization: Bearer $API_KEY" \
    "https://api.mod.io/v1/games/$GAME_ID/mods/$MOD_ID/files")

  DOWNLOAD_URL=$(echo "$FILE_INFO" | jq -r '.data[0].download.binary_url')

  # Prüfen ob URL gültig ist
  if [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Fehler: Keine gültige Download-URL für Mod $MOD_ID"
    continue
  fi

  # Dateiname bestimmen
  FILE_NAME="mod_${MOD_ID}.zip"

  # Download durchführen
  curl -L "$DOWNLOAD_URL" -o "$OUTPUT_DIR/$FILE_NAME"

done

echo "Alle Mods wurden heruntergeladen."
