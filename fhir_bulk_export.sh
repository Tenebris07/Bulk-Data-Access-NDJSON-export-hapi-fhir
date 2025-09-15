#!/bin/bash

FHIR_BASE="http://localhost:8080/fhir"
OUTPUT_DIR="./fhir_export"
mkdir -p "$OUTPUT_DIR"
INTERVAL=10

echo "Iniciando Bulk Export..."

# Lanzar la petición $export
EXPORT_RESPONSE=$(curl -s -X GET \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async" \
  "$FHIR_BASE/\$export")

# Extraer la URL de poll-status
POLL_URL=$(echo "$EXPORT_RESPONSE" | jq -r '.["Content-Location"] // empty')

# Si Content-Location no se encuentra, buscar en headers
if [ -z "$POLL_URL" ]; then
    POLL_URL=$(curl -s -i -X GET \
        -H "Accept: application/fhir+json" \
        -H "Prefer: respond-async" \
        "$FHIR_BASE/\$export" | grep -i 'Content-Location:' | awk '{print $2}' | tr -d '\r')
fi

if [ -z "$POLL_URL" ]; then
    echo "No se pudo obtener la URL de poll-status. Abortando."
    exit 1
fi

echo "Polling URL detectada: $POLL_URL"

# Polling hasta que los archivos estén listos
while true; do
    RESPONSE=$(curl -s -X GET -H "Accept: application/fhir+json" "$POLL_URL")
    
    # Extraer URLs y tipos
    OUTPUT_TYPES=$(echo "$RESPONSE" | jq -r '.output[]?.type // empty')
    OUTPUT_URLS=$(echo "$RESPONSE" | jq -r '.output[]?.url // empty')
    
    if [ -n "$OUTPUT_URLS" ]; then
        echo "Job completado. Descargando archivos..."
        
        i=0
        for URL in $OUTPUT_URLS; do
            TYPE=$(echo "$OUTPUT_TYPES" | sed -n "$((i+1))p")
            FILE_NAME="$OUTPUT_DIR/$TYPE.ndjson"
            
            echo "Descargando $TYPE desde $URL..."
            curl -s -o "$FILE_NAME" "$URL"
            
            ((i++))
        done
        
        echo "Todos los archivos han sido descargados en $OUTPUT_DIR"
        break
    else
        RETRY_AFTER=$(echo "$RESPONSE" | jq -r '.["retryAfter"] // empty')
        SLEEP_TIME=${RETRY_AFTER:-$INTERVAL}
        echo "Job aún en progreso. Esperando $SLEEP_TIME segundos..."
        sleep $SLEEP_TIME
    fi
done
