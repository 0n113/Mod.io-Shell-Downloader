#!/bin/bash

# Konfiguration
API_KEY=""
GAME_ID="" 
OUTPUT_DIR=""


mkdir -p "$OUTPUT_DIR"
touch "$LOG_FILE"
touch "$HASH_DB"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

log "Abonnierte Mods abrufen..."
RESPONSE=$(curl -s -H "Authorization: Bearer $API_KEY" \
  "https://api.mod.io/v1/me/subscribed")

if ! echo "$RESPONSE" | jq -e '.data | length > 0' >/dev/null; then
  log "Keine abonnierten Mods gefunden oder Fehler bei API-Zugriff."
  log "Antwort der API: $RESPONSE"
  exit 1
fi

MOD_IDS=$(echo "$RESPONSE" | jq -r '.data[].id')

for MOD_ID in $MOD_IDS; do
  log "Verarbeite Mod ID $MOD_ID..."

  MOD_DIR="$OUTPUT_DIR/mod_$MOD_ID"

  FILE_INFO=$(curl -s \
    -H "Authorization: Bearer $API_KEY" \
    "https://api.mod.io/v1/games/$GAME_ID/mods/$MOD_ID/files")

  DOWNLOAD_URL=$(echo "$FILE_INFO" | jq -r '.data[0].download.binary_url')

  if [ "$DOWNLOAD_URL" = "null" ]; then
    log "Fehler: Keine gültige Download-URL für Mod $MOD_ID"
    continue
  fi

  FILE_NAME="mod_${MOD_ID}.zip"
  FILE_PATH="$OUTPUT_DIR/$FILE_NAME"

  # Hash der URL (als einfache Versionsprüfung)
  FILE_HASH=$(echo "$DOWNLOAD_URL" | sha256sum | cut -d' ' -f1)
  SAVED_HASH=$(grep "^$MOD_ID=" "$HASH_DB" | cut -d'=' -f2)

  if [ "$FILE_HASH" = "$SAVED_HASH" ] && [ -d "$MOD_DIR" ]; then
    log "Mod $MOD_ID ist aktuell. Überspringe."
    continue
  fi

  log "Lade $FILE_NAME herunter..."
  curl -L "$DOWNLOAD_URL" -o "$FILE_PATH"

  log "Entpacke $FILE_NAME..."
  mkdir -p "$MOD_DIR"
  unzip -q "$FILE_PATH" -d "$MOD_DIR"
  rm "$FILE_PATH"

  # Hash aktualisieren
  sed -i "/^$MOD_ID=/d" "$HASH_DB"
  echo "$MOD_ID=$FILE_HASH" >> "$HASH_DB"

done

log "Alle Mods wurden verarbeitet."
