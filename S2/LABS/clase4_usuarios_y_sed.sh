#!/bin/bash
###############################################################################
# Clase 4 — sed
# Objetivo: 1) generar un informe de los usuarios "reales" del sistema
#           2) modificar un archivo de configuración con sed -i,
#              usando un rango de líneas y conservando un respaldo
#
# Uso:  ./clase4_usuarios_y_sed.sh
###############################################################################

set -euo pipefail

REPORTE="informe_usuarios.txt"
CONFIG_FILE="./sshd_config_ejemplo"   # archivo de práctica, no el real del sistema

###############################################################################
# PARTE 1 — Informe de usuarios del sistema
###############################################################################
echo ">>> Generando informe de usuarios en: $REPORTE"

# /etc/passwd tiene 7 campos separados por ":"
#   usuario : password(x) : UID : GID : comentario : home : shell
#
# sed -n '...p'
#   -n      : no imprime nada por defecto (silencia la salida automática)
#   '...p'  : el comando p imprime SOLO las líneas donde matchea el patrón
#
# Filtramos usuarios "reales" (UID >= 1000), que en /etc/passwd son las
# líneas donde el 3er campo (delimitado por ":") es >= 1000.
# Como sed no compara números de campo fácilmente, combinamos con awk
# para el filtro numérico y usamos sed solo para dar formato al informe.

{
    echo "Informe de usuarios del sistema — $(date '+%Y-%m-%d %H:%M')"
    echo "======================================================="
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1, $3, $6, $7}' /etc/passwd \
        | sed 's/^/Usuario: /' \
        | sed -E 's/([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)/\1 (UID \2) — home: \3 — shell: \4/'
} > "$REPORTE"

echo "Informe generado. Primeras líneas:"
sed -n '1,5p' "$REPORTE"   # rango de líneas: imprime solo de la 1 a la 5

###############################################################################
# PARTE 2 — Edición in-place con sed -i
###############################################################################
echo
echo ">>> Preparando archivo de configuración de ejemplo: $CONFIG_FILE"

# Creamos un archivo de práctica para no tocar configuración real del sistema
cat > "$CONFIG_FILE" <<'EOF'
# Ejemplo de configuración SSH (archivo de práctica)
Port 22
PermitRootLogin yes
PasswordAuthentication yes
X11Forwarding no
EOF

echo "Contenido original:"
cat "$CONFIG_FILE"

# sed -i.bak 's/patrón/reemplazo/'
#   -i.bak      : edita el archivo IN-PLACE, pero antes guarda una copia
#                 de respaldo con extensión .bak (nunca perdemos el original)
#   s/.../.../  : comando de sustitución (substitute)
#
# Reemplazamos "PermitRootLogin yes" por "PermitRootLogin no"
sed -i.bak 's/PermitRootLogin yes/PermitRootLogin no/' "$CONFIG_FILE"

echo
echo "Contenido después del cambio:"
cat "$CONFIG_FILE"

echo
echo "Respaldo conservado en: ${CONFIG_FILE}.bak"
