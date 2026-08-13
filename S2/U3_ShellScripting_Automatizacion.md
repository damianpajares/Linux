# U3 — Shell Scripting y Automatización

> **Programa:** Técnico en Redes y Software · CETP-UTU · CTT
> **Módulo:** Redes POSIX — SHSCRIPT (S2)
> **Unidad:** U3 — Shell Scripting y Automatización (Semanas 12–16 · ~15 hs)
> **Relación con el resto del material:** `Comillas_Salida_y_Pruebas_Linux1.pptx` ya cubre en profundidad quoting, estado de salida (`$?`) y las construcciones de prueba (`[ ]`, `[[ ]]`, `(( ))`) — **no se repite acá**, se da por sabido y se referencia. `Linux2_Clase0_Nexo_CTT.pptx` solo muestra el esqueleto de un script como preview. Este documento desarrolla la unidad completa: variables/argumentos, bucles, funciones, manejo de errores, logging y `cron`.

---

## Objetivos

Al finalizar esta unidad el estudiante será capaz de:

- Escribir scripts Bash con estructura profesional (`shebang`, `set -euo pipefail`, funciones, `main`)
- Manejar argumentos posicionales, `getopts` y variables especiales
- Construir bucles `for`/`while`/`until` y procesar archivos línea por línea
- Escribir funciones con `local` y manejo de errores mediante `trap` y exit codes
- Registrar eventos con `logger` (syslog) y logging dual a archivo
- Programar tareas con `crontab` y depurar scripts con `shellcheck`

---

## Prerequisitos

| Requisito | Verificación |
|-----------|-------------|
| Quoting, `$?`, `[[ ]]`, `test` de archivos | Revisar `Comillas_Salida_y_Pruebas_Linux1.pptx` si hace falta repasar |
| U1 y U2 completas | Manejo de pipes, procesos y SSH |

---

## 3.1 — Estructura profesional de un script

### Marco teórico

Un script Bash "de producción" no es solo una lista de comandos: tiene una estructura predecible que otro administrador puede leer sin explicación.

```bash
#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# Script: monitoreo.sh
# Autor: CTT Área 3911
# Fecha: 2026-03-09
# Descripción: Monitorea espacio en disco y servicios
# ─────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE='/var/log/ctt/monitoreo.log'
readonly UMBRAL_DISCO=80

# ─── Funciones ────────────────────────────────────
log() { logger -t 'ctt-monitor' "$*"; echo "$(date '+%Y-%m-%d %T') $*" >> "${LOG_FILE}"; }

check_disco() {
    local uso
    uso=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    if [[ ${uso} -ge ${UMBRAL_DISCO} ]]; then
        log "ALERTA: Disco al ${uso}% (umbral: ${UMBRAL_DISCO}%)"
        return 1
    fi
    log "OK: Disco al ${uso}%"
}

# ─── Main ─────────────────────────────────────────
main() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    log "Iniciando monitoreo..."
    check_disco || exit 1
    log "Monitoreo completado correctamente"
}

main "$@"
```

**Por qué `set -euo pipefail`:**

| Opción | Efecto |
|---|---|
| `-e` | Sale inmediatamente si cualquier comando devuelve un exit code distinto de 0 |
| `-u` | Error si se usa una variable no definida — evita bugs silenciosos por typos |
| `-o pipefail` | El exit code de un pipe es el del primer comando que falla, no el del último (por defecto Bash solo mira el último) |

Sin `pipefail`, `comando_que_falla | grep algo` puede parecer exitoso porque `grep` devolvió 0, ocultando el fallo real.

**Pasos para ejecutar un script:**

```bash
nano mi_script.sh          # crear/editar
chmod +x mi_script.sh      # dar permiso de ejecución
./mi_script.sh              # ejecutar (el ./ indica "en el directorio actual")
```

### PERFIL A — sin conocimientos previos

1. Crear `~/check_sistema.sh` con shebang, `set -euo pipefail` y 3 líneas de `echo` con `$(whoami)`, `$(date)` y `$(uptime -p)`
2. `chmod +x` y ejecutarlo
3. Provocar un error a propósito (referenciar una variable no definida) y observar cómo `-u` lo detiene

### PERFIL B — con conocimientos previos

1. Reescribir un script existente sin `set -euo pipefail` agregándoselo, y verificar qué comportamiento cambia
2. Explicar con un ejemplo concreto por qué `comando_falla | tee log.txt` necesita `pipefail` para que el `$?` final sea confiable

---

## 3.2 — Variables, argumentos y `getopts`

### Marco teórico

| Variable | Significado |
|---|---|
| `$0` | Nombre del script en ejecución |
| `$1` ... `$9` | Argumentos posicionales |
| `$#` | Cantidad de argumentos recibidos |
| `$@` | Todos los argumentos, como lista separada (usar siempre entre comillas: `"$@"`) |
| `$?` | Exit code del último comando |
| `$$` | PID del script actual |

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Uso: $0 <nombre>" >&2
    exit 1
fi

echo "Hola, $1"
```

**`getopts` — opciones de línea de comandos con formato `-flag valor`:**

```bash
#!/usr/bin/env bash
set -euo pipefail

servicio=""
umbral=80
verbose=false

while getopts "s:u:v" opt; do
    case "${opt}" in
        s) servicio="${OPTARG}" ;;
        u) umbral="${OPTARG}" ;;
        v) verbose=true ;;
        *) echo "Uso: $0 -s servicio -u umbral [-v]" >&2; exit 1 ;;
    esac
done

echo "Servicio: ${servicio} | Umbral: ${umbral} | Verbose: ${verbose}"
# Se invoca: ./script.sh -s nginx -u 90 -v
```

`OPTARG` contiene el valor pasado después de la flag. Los `:` después de la letra (`s:`) indican que esa opción espera un argumento; sin `:` es una flag booleana (como `-v`).

### PERFIL A — sin conocimientos previos

1. Crear `saludo.sh` que reciba un nombre por `$1` y salude
2. Validar que se pasó el argumento: si `$# -eq 0`, mostrar uso y salir con `exit 1`
3. Probar: `./saludo.sh Carlos` → `Hola Carlos, hoy es <fecha>`

### PERFIL B — con conocimientos previos

1. Extender el script de monitoreo con `getopts` para aceptar `-s servicio`, `-u umbral_disco`, `-v` (verbose)
2. Manejar el caso de un flag desconocido con el `*)` del `case` y salida con código de error

---

## 3.3 — Bucles: `for`, `while`, `until` y procesamiento de archivos

### Marco teórico

```bash
# for — iterar sobre una lista
for servicio in ssh nginx mysql; do
    if systemctl is-active --quiet "${servicio}"; then
        echo "${servicio}: ACTIVO"
    else
        echo "${servicio}: CAIDO"
    fi
done

# while — repetir mientras la condición sea verdadera
contador=1
while [[ ${contador} -le 5 ]]; do
    echo "Iteración número: ${contador}"
    contador=$((contador + 1))
done

# until — repetir HASTA que la condición sea verdadera (inverso de while)
until ping -c1 servidor.local &>/dev/null; do
    echo "Esperando que el servidor responda..."
    sleep 5
done

# while read — procesar un archivo línea por línea (patrón más seguro que 'for linea in $(cat archivo)')
while IFS=: read -r usuario uid gid desc home shell; do
    echo "Usuario: ${usuario} | Home: ${home}"
done < /etc/passwd
```

**Por qué `while IFS= read -r` y no `for linea in $(cat archivo)`:** el segundo hace word-splitting por espacios y expande comodines — rompe con nombres de archivo o líneas que contienen espacios. `while read` procesa línea por línea de forma segura y predecible.

### PERFIL A — sin conocimientos previos

1. Bucle `for` que recorra 5 números e imprima si son pares o impares
2. Bucle `while` que cuente de 1 a 10
3. Recorrer `/etc/passwd` con `while IFS=: read` e imprimir solo el nombre de usuario

### PERFIL B — con conocimientos previos

1. Script que recorra todos los `.sh` de un directorio con `for archivo in *.sh` y les corra `shellcheck`
2. Bucle `until` que reintente una conexión SSH hasta que el servidor esté disponible (con límite máximo de intentos, para no quedar en loop infinito)

---

## 3.4 — Funciones y manejo de errores

### Marco teórico

```bash
usuario_existe() {
    local usuario="$1"     # local: evita colisión con variables globales
    if id "${usuario}" &>/dev/null; then
        return 0             # éxito
    else
        return 1             # falla
    fi
}

if usuario_existe 'alumno'; then
    echo 'El usuario alumno existe'
fi
```

**Reglas de las funciones:** declarar variables internas con `local`, retornar `0` para éxito y otro número para error (convención Unix), definir antes de llamar (Bash ejecuta de arriba a abajo), documentar con un comentario qué hace, qué argumentos espera y qué retorna.

**`trap` — capturar señales y limpiar al salir:**

```bash
#!/usr/bin/env bash
set -euo pipefail

TMP_FILE=$(mktemp)

limpiar() {
    echo "Limpiando archivos temporales..."
    rm -f "${TMP_FILE}"
}
trap limpiar EXIT              # se ejecuta SIEMPRE al salir, con éxito o error
trap 'echo "Interrumpido por el usuario"; exit 130' INT   # Ctrl+C

echo "Trabajando con ${TMP_FILE}..."
sleep 5
echo "Terminado"
```

`trap ... EXIT` es la forma correcta de garantizar limpieza (borrar temporales, liberar locks) sin importar cómo termine el script — incluso si falla a mitad de camino por `set -e`.

### PERFIL A — sin conocimientos previos

1. Escribir una función `es_directorio()` que reciba una ruta por `$1` y retorne 0 si es directorio, 1 si no
2. Usarla en un `if` para decidir si crear el directorio con `mkdir -p`

### PERFIL B — con conocimientos previos

1. Script que cree un archivo temporal con `mktemp`, y use `trap ... EXIT` para borrarlo siempre, incluso si el script falla antes
2. Agregar un `trap` para `SIGINT` que imprima un mensaje de cancelación antes de salir

---

## 3.5 — Logging: `logger` y logging dual

### Marco teórico

`logger` envía mensajes al syslog del sistema — visible con `journalctl` o en `/var/log/syslog`, según la distro.

```bash
logger -t 'ctt-monitor' 'Servicio nginx reiniciado por script de monitoreo'
journalctl -t ctt-monitor -n 20    # ver los últimos mensajes de ese tag
```

**Patrón de logging dual** (syslog + archivo propio con fecha, usado en scripts de administración):

```bash
readonly LOG_FILE="/var/log/ctt/monitor_$(date +%Y%m%d).log"

log() {
    local msg="$1"
    logger -t 'ctt-monitor' "${msg}"
    echo "$(date '+%Y-%m-%d %T') ${msg}" >> "${LOG_FILE}"
}
```

**Heredoc — generar reportes de varias líneas sin encadenar `echo`:**

```bash
cat <<EOF > reporte.txt
=== Reporte del sistema ===
Fecha: $(date)
Usuario: $(whoami)
Disco: $(df -h / | awk 'NR==2{print $5}')
EOF
```

### PERFIL A — sin conocimientos previos

1. Agregar `logger -t mi_script 'mensaje de prueba'` a un script y verificarlo con `journalctl -t mi_script`
2. Generar un reporte simple con heredoc (`cat <<EOF ... EOF`)

### PERFIL B — con conocimientos previos

1. Implementar logging dual (syslog + archivo con fecha en el nombre) en el script de monitoreo del laboratorio final
2. Comparar `journalctl -t <tag>` contra `grep <tag> /var/log/syslog` — ¿en qué distros cambia esto?

---

## 3.6 — `crontab`: automatización programada

### Marco teórico

`cron` ejecuta comandos en horarios definidos. El crontab tiene 5 campos de tiempo:

```
#  min  hora  dia_mes  mes  dia_sem   comando
#  (0-59)(0-23)(1-31) (1-12)(0-6, 0=domingo)
```

| Expresión | Cuándo se ejecuta |
|---|---|
| `* * * * * cmd` | Cada minuto |
| `0 * * * * cmd` | Al comienzo de cada hora |
| `0 2 * * * cmd` | Todos los días a las 2:00 AM |
| `0 2 * * 0 cmd` | Cada domingo a las 2:00 AM |
| `*/15 * * * * cmd` | Cada 15 minutos |
| `0 0 1 * * cmd` | El primer día de cada mes a medianoche |
| `@reboot cmd` | Al iniciar el sistema (una sola vez) |
| `@daily cmd` | Una vez al día — equivale a `0 0 * * *` |

**Gestión del crontab:**

```bash
crontab -e        # editar (usa $EDITOR)
crontab -l        # listar tareas programadas
crontab -r        # eliminar TODAS las tareas (¡peligroso, no tiene confirmación!)
```

**Buenas prácticas obligatorias con cron:**

- Usar siempre **rutas absolutas** — el `PATH` de cron es mínimo, no el de tu shell interactiva
- Redirigir la salida (`>> log 2>&1`) para no llenar el correo local del usuario con la salida de cada ejecución
- Probar el comando manualmente con el mismo entorno reducido antes de confiar en que cron lo va a ejecutar igual

```bash
# Ejemplo de línea de crontab
0 2 * * * /usr/local/bin/backup.sh >> /var/log/ctt/backup.log 2>&1
```

### PERFIL A — sin conocimientos previos

Script de respaldo guiado:

```bash
#!/usr/bin/env bash
set -euo pipefail
ORIGEN='/home/alumno/proyectos'
DESTINO='/backup'
FECHA=$(date +%Y%m%d_%H%M)
mkdir -p "${DESTINO}"
tar -czf "${DESTINO}/backup_${FECHA}.tar.gz" "${ORIGEN}"
echo "Backup completado: backup_${FECHA}.tar.gz"
```

1. Ejecutar y verificar que el `.tar.gz` se creó
2. Agregar al crontab: todos los días a las 23:00
3. Agregar `logger` para registrar el resultado en syslog

### PERFIL B — con conocimientos previos

1. Script de monitoreo avanzado: CPU, RAM, disco y 3 servicios críticos; si un servicio está caído, intentar reiniciarlo con `systemctl start` y loguear el resultado
2. `getopts` para `-s servicio -u umbral -v`
3. `shellcheck` del script: cero warnings antes de entregar
4. Programarlo cada 5 minutos, con log en `/var/log/ctt/monitor.log`

---

## 3.7 — `shellcheck`: análisis estático

`shellcheck` detecta errores comunes de Bash antes de ejecutarlos: variables sin comillas, comparaciones mal formadas, uso incorrecto de `[ ]`, código inalcanzable.

```bash
sudo apt install shellcheck
shellcheck mi_script.sh
```

Un script que pasa `shellcheck` sin warnings es un requisito mínimo de entrega en los laboratorios de esta unidad — no reemplaza probar el script, pero atrapa errores antes de que se vuelvan bugs en producción.

---

## 🧪 Laboratorio Práctico Final — Sistema de monitoreo automático (90 min)

1. Crear `/usr/local/bin/ctt_monitor.sh` con permisos `755`
2. Funciones: `check_disco`, `check_ram`, `check_servicio(nombre)`, `log_resultado`
3. `check_disco`: alerta si uso > 80%, info si > 60%
4. `check_ram`: alerta si memoria libre < 200MB
5. `check_servicio`: verificar `ssh`, `cron` y un servicio web
6. Logging dual: `logger` (syslog) + archivo `/var/log/ctt/monitor_FECHA.log`
7. Programar en `crontab`: cada 5 minutos — evidencia con `crontab -l`
8. `shellcheck /usr/local/bin/ctt_monitor.sh` — 0 errores
9. Simular una falla: detener `ssh`, ejecutar el script, verificar que la detecta
10. Documentar: comentarios en el código + informe de una página con capturas

---

## 📋 Evaluación

| Instrumento Perfil A | Instrumento Perfil B |
|---|---|
| Completar un script con la función faltante, dado el comportamiento esperado | Sistema de monitoreo completo con `getopts`, funciones, logging dual y `crontab` |
| Identificar 3 bugs comunes de Bash en un script dado | Revisión de código de un compañero: `shellcheck` + checklist de buenas prácticas |
| Explicar qué hace `set -euo pipefail` con un ejemplo propio | Justificar el uso de `trap ... EXIT` en un script que crea archivos temporales |

**Criterios de evaluación**

| Criterio | Peso |
|---|---|
| Estructura correcta del script: shebang, `set`, funciones, `main` | 25% |
| Lógica de monitoreo correcta — condiciones y comparaciones | 30% |
| Logging dual: syslog + archivo con fechas | 20% |
| `crontab` configurado y funcionando, `shellcheck` limpio | 25% |

---

## Referencia rápida

```bash
set -euo pipefail                                # cabecera de seguridad obligatoria
[[ $# -eq 0 ]] && { echo "Uso: $0 arg"; exit 1; } # validar argumentos
while getopts "s:u:v" opt; do ... done            # opciones de línea de comandos
for x in lista; do ...; done                      # bucle sobre lista
while IFS= read -r linea; do ...; done < archivo  # procesar archivo línea por línea
trap 'limpiar' EXIT                               # limpieza garantizada al salir
logger -t tag 'mensaje'                           # log a syslog
0 2 * * * /ruta/absoluta/script.sh >> log 2>&1    # línea de crontab
shellcheck script.sh                              # análisis estático antes de entregar
```

---

*Linux II — Redes POSIX SHSCRIPT · CTT · Año 2026.*
