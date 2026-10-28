#!/bin/bash
###############################################################################
# Clase 5 — find avanzado y xargs
# Objetivo: 1) buscar archivos .sh ejecutables en /home
#           2) contar líneas de todos los logs del sistema, en paralelo,
#              usando xargs -P
#
# Uso:  ./clase5_find_xargs.sh
###############################################################################

set -uo pipefail   # sin -e: algunos find/xargs pueden devolver !=0 si faltan permisos

HOME_DIR="/home"
LOG_DIR="/var/log"

###############################################################################
# PARTE 1 — Archivos .sh ejecutables en /home
###############################################################################
echo ">>> Buscando archivos .sh ejecutables en $HOME_DIR"
echo "-----------------------------------------------------"

# find /home ...
#   -type f        : solo archivos regulares (no directorios, no links)
#   -name '*.sh'    : que el nombre termine en .sh
#   -perm -u+x      : que tenga el bit de ejecución para el DUEÑO del archivo
#                     (el signo "-" antes de u+x significa "al menos estos
#                     permisos", no exactamente estos)
#
# 2>/dev/null descarta errores de "permiso denegado" en directorios
# a los que no tenemos acceso, para no ensuciar la salida.
find "$HOME_DIR" -type f -name "*.sh" -perm -u+x 2>/dev/null

echo
echo ">>> Cantidad de scripts .sh ejecutables encontrados:"
find "$HOME_DIR" -type f -name "*.sh" -perm -u+x 2>/dev/null | wc -l

###############################################################################
# PARTE 2 — Contar líneas de todos los logs, en paralelo con xargs -P
###############################################################################
echo
echo ">>> Contando líneas de todos los logs en $LOG_DIR (en paralelo)"
echo "-----------------------------------------------------"

# find /var/log -type f
#   Lista todos los archivos regulares dentro de /var/log (incluye
#   subdirectorios, porque find es recursivo por defecto).
#
# xargs -P 4 -n 1 wc -l
#   xargs toma la lista de archivos que le llega por stdin y arma,
#   con cada uno (o varios), una llamada al comando indicado (wc -l).
#     -P 4   : ejecuta hasta 4 procesos wc -l EN PARALELO
#              (en vez de uno por vez, como haría -exec de find)
#     -n 1   : cada llamada a wc -l recibe 1 solo archivo como argumento
#              (así el conteo queda separado por archivo, no todo junto)
#
# find imprime rutas separadas por salto de línea; si algún archivo
# tuviera espacios en el nombre, lo correcto sería -print0 / xargs -0.
# Para simplificar, en este ejercicio asumimos nombres sin espacios.
find "$LOG_DIR" -type f 2>/dev/null | xargs -P 4 -n 1 wc -l 2>/dev/null

echo
echo ">>> Total de líneas sumando todos los logs:"
find "$LOG_DIR" -type f 2>/dev/null | xargs -P 4 -n 1 wc -l 2>/dev/null \
    | awk '{sum += $1} END {print sum}'
