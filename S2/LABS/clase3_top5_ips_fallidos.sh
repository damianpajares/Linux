#!/bin/bash
###############################################################################
# Clase 3 — Pipes avanzados
# Objetivo: obtener el Top 5 de IPs con más intentos de autenticación
#           fallidos, a partir de /var/log/auth.log
#
# Uso:  ./clase3_top5_ips_fallidos.sh [ruta_al_log]
#       Si no se pasa ruta, usa /var/log/auth.log por defecto.
###############################################################################

set -euo pipefail

LOGFILE="${1:-/var/log/auth.log}"

if [[ ! -r "$LOGFILE" ]]; then
    echo "No puedo leer '$LOGFILE'. ¿Existe y tenés permisos?" >&2
    exit 1
fi

echo "Analizando: $LOGFILE"
echo "-----------------------------------------------"

# 1) grep -i "failed password"
#      -i  : ignora mayúsculas/minúsculas ("Failed password" / "failed password")
#    Filtramos solo las líneas que corresponden a intentos fallidos.
#
# 2) grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'
#      -o  : imprime SOLO la parte que matchea (no la línea completa)
#      -E  : habilita regex extendida, para poder usar {1,3} sin escapar
#      El patrón busca 4 grupos de 1 a 3 dígitos separados por puntos,
#      es decir, direcciones IPv4.
#
# 3) sort
#      Ordena las IPs alfabéticamente. Es necesario antes de uniq,
#      porque uniq solo agrupa líneas IGUALES y CONSECUTIVAS.
#
# 4) uniq -c
#      -c  : antepone a cada línea la cantidad de veces que se repite.
#      Convierte la lista de IPs repetidas en pares "cantidad IP".
#
# 5) sort -rn
#      -r  : orden descendente
#      -n  : orden numérico (para que 10 no quede antes que 2)
#      Ordena por la cantidad de intentos, de mayor a menor.
#
# 6) head -5
#      Nos quedamos solo con las 5 primeras líneas: el Top 5.

grep -i "failed password" "$LOGFILE" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -rn \
    | head -5

echo "-----------------------------------------------"
echo "Formato de salida: <cantidad_de_intentos>  <IP>"
