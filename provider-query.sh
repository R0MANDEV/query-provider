#!/bin/bash

# Cargar variables de entorno desde .env si existe
if [ -f .env ]; then
  source .env
fi

# URL base de la API (sin la plataforma)
if [[ -z "$BASE_URL" ]]; then
  echo "❌ Error: La variable de entorno BASE_URL no está definida."
  echo "Por favor, define BASE_URL en el archivo .env antes de ejecutar el script."
  exit 1
fi

# Plataformas disponibles (leer de la carpeta portals)
PORTALS_DIR="./portals"
PLATFORMS=()
for f in "$PORTALS_DIR"/*.conf; do
  name=$(basename "$f" .conf)
  PLATFORMS+=("$name")
done

# Seleccionar plataforma
echo "Selecciona la plataforma a consultar:"
select platform in "${PLATFORMS[@]}" "Salir"; do
  if [[ "$REPLY" -gt 0 && "$REPLY" -le ${#PLATFORMS[@]} ]]; then
    PLATFORM_URL="$BASE_URL/$platform"
    echo -e "\nPlataforma seleccionada: $platform"
    # Cargar configuración del portal
    source "$PORTALS_DIR/$platform.conf"
    break
  elif [[ "$REPLY" -eq $((${#PLATFORMS[@]}+1)) ]]; then
    echo "Saliendo..."
    exit 0
  else
    echo "Opción inválida. Intenta de nuevo."
  fi
done

# Login y obtención de token para cualquier plataforma
LOGIN_URL="$PLATFORM_URL/admin_login"
echo -e "\n🔐 Obteniendo token de autenticación para $platform..."
TOKEN_RESPONSE=$(curl -s -k -X POST "$LOGIN_URL" \
  -H "accept: application/json" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$USERNAME&password=$PASSWORD")
TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"token":"[^\"]*"' | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
    echo "❌ Error: No se pudo obtener el token de autenticación"
    echo "Respuesta del servidor: $TOKEN_RESPONSE"
    exit 1
fi
echo "✅ Token obtenido correctamente"

echo ""
PS3="Selecciona el endpoint a consultar: "
while true; do
  select endpoint in "${ENDPOINTS[@]}" "Salir"; do
    if [[ "$REPLY" -gt 0 && "$REPLY" -le ${#ENDPOINTS[@]} ]]; then
      SELECTED_ENDPOINT="${ENDPOINTS[$((REPLY-1))]}"
      # Si el endpoint contiene {id}, pedir el valor al usuario
      if [[ "$SELECTED_ENDPOINT" == *"{id}"* ]]; then
        read -p "Introduce el valor para 'id': " ID_VALUE
        SELECTED_ENDPOINT="${SELECTED_ENDPOINT/\{id\}/$ID_VALUE}"
      fi
      echo -e "\n🔗 Consultando: $PLATFORM_URL/$SELECTED_ENDPOINT\n"
      RESPONSE=$(curl -s -k -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" "$PLATFORM_URL/$SELECTED_ENDPOINT")
      echo -e "\n📦 Respuesta del endpoint:\n"
      if command -v jq &> /dev/null; then
        echo "$RESPONSE" | jq .
      else
        echo "$RESPONSE"
      fi
      echo -e "\n✅ Consulta completada"
      break
    elif [[ "$REPLY" -eq $((${#ENDPOINTS[@]}+1)) ]]; then
      echo "Saliendo..."
      exit 0
    else
      echo "Opción inválida. Intenta de nuevo."
    fi
  done
done