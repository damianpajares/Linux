# U1 — Complemento: Filtros Avanzados, Procesos y Diagnóstico de Red

> **Programa:** Técnico en Redes y Software · CETP-UTU · CTT
> **Módulo:** Redes POSIX — SHSCRIPT (S2)
> **Unidad:** U1 — Comandos Avanzados y Administración POSIX (Semanas 1–5)
> **Relación con el resto del material:** completa lo que `Linux2_Clase0_Nexo_CTT.pptx` y `Linux2_Clase1_Redes POSIX Bash Scripting.docx` dejan pendiente de U1 — ahí ya se vieron streams, redirecciones, pipes y una introducción a `systemctl`/`journalctl`. Este documento no repite ese contenido: arranca donde esas clases terminan.

---

## Objetivos

Al finalizar este bloque el estudiante será capaz de:

- Extraer, ordenar y deduplicar datos de texto con `cut`, `sort` y `uniq`
- Buscar archivos por criterios avanzados y procesarlos en lote con `find` + `xargs`
- Escribir expresiones regulares extendidas (ERE) para `grep -E`
- Auditar, priorizar y terminar procesos con `ps`, `top`/`htop`, `kill`, `pgrep`/`pkill`
- Gestionar jobs en primer y segundo plano (`jobs`, `bg`, `fg`, `nohup`)
- Diagnosticar qué proceso tiene abierto un archivo o puerto con `lsof`
- Diagnosticar conectividad de red básica con `ip`, `ping`, `traceroute`, `ss`
- Persistir alias y variables de entorno propias en `~/.bashrc`

---

## Prerequisitos

| Requisito | Verificación |
|-----------|-------------|
| Streams, redirecciones y pipes (Clase 1) | Sabés explicar la diferencia entre `>`, `>>` y `2>&1` |
| `grep` básico, `systemctl status` / `journalctl -u` (Clase 1) | — |
| Terminal Linux con `sudo` | `sudo whoami` → `root` |

---

## 1.1 — `cut`, `sort`, `uniq`: extraer y ordenar columnas

### Marco teórico

Estas tres herramientas se combinan casi siempre en la misma secuencia: **extraer** una columna → **ordenar** → **deduplicar/contar**. Es el patrón más común de análisis de texto en administración de sistemas.

| Comando | Ejemplo | Descripción |
|---|---|---|
| `cut -d` | `cut -d: -f1 /etc/passwd` | Extrae el campo 1 usando `:` como delimitador |
| `cut -c` | `cut -c1-10 archivo.txt` | Extrae los caracteres 1 a 10 de cada línea |
| `sort` | `sort archivo.txt` | Ordena alfabéticamente (ASCII) |
| `sort -n` | `sort -n numeros.txt` | Ordena numéricamente (sin esto, "10" va antes que "2") |
| `sort -r` | `sort -rn archivo.txt` | Orden inverso (descendente) |
| `sort -k` | `sort -k2 -n datos.txt` | Ordena por la columna 2 (campos separados por espacio) |
| `sort -u` | `sort -u archivo.txt` | Ordena y elimina duplicados en un solo paso |
| `uniq` | `sort archivo \| uniq` | Elimina líneas duplicadas **consecutivas** — por eso siempre va después de `sort` |
| `uniq -c` | `sort archivo \| uniq -c` | Cuenta cuántas veces aparece cada línea |
| `uniq -d` | `sort archivo \| uniq -d` | Muestra solo las líneas que están duplicadas |

**Por qué `uniq` necesita `sort` antes:** `uniq` solo compara líneas *adyacentes*. Si las repeticiones no están juntas, no las detecta. Por eso la secuencia `sort archivo | uniq -c | sort -rn` es un patrón fijo: ordena para agrupar, cuenta duplicados, y reordena por frecuencia.

```bash
# Top 5 shells más usadas en el sistema
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn | head -5

# Usuarios reales (UID >= 1000), ordenados por UID
awk -F: '$3>=1000 {print $3, $1}' /etc/passwd | sort -n
```

### PERFIL A — sin conocimientos previos

1. Extraer solo los nombres de usuario de `/etc/passwd`: `cut -d: -f1 /etc/passwd`
2. Ordenarlos alfabéticamente: `cut -d: -f1 /etc/passwd | sort`
3. Contar cuántos usuarios distintos hay: `cut -d: -f1 /etc/passwd | sort -u | wc -l`
4. ¿Cuál es la shell que más usuarios tienen asignada? Armar el pipe paso a paso, agregando una herramienta a la vez.

### PERFIL B — con conocimientos previos

1. IPs que más se repiten en `auth.log`, con conteo: `grep 'Failed password' /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn`
2. Listar procesos duplicados por nombre de comando y contar instancias: `ps -eo comm | sort | uniq -c | sort -rn | head -10`
3. Usar `sort -k2 -t: -n` para ordenar `/etc/passwd` por UID (campo 3, delimitador `:`)

---

## 1.2 — `find` + `xargs`: búsqueda y procesamiento en lote

### Marco teórico

`find` recorre un árbol de directorios evaluando criterios (nombre, tamaño, permisos, fecha). `xargs` toma una lista de líneas por `stdin` y las convierte en argumentos de otro comando — la combinación permite operar sobre miles de archivos sin bucles explícitos.

| Comando | Ejemplo | Descripción |
|---|---|---|
| `find -name` | `find /home -name '*.sh'` | Busca por nombre (case-sensitive) |
| `find -iname` | `find /etc -iname '*.conf'` | Busca ignorando mayúsculas/minúsculas |
| `find -type` | `find /var/log -type f` | Filtra por tipo: `f` archivo, `d` directorio, `l` symlink |
| `find -perm` | `find /home -name '*.sh' -perm /u+x` | Archivos `.sh` con permiso de ejecución para el dueño |
| `find -mtime` | `find /tmp -mtime +7` | Modificados hace más de 7 días |
| `find -size` | `find / -size +100M` | Archivos de más de 100 MB |
| `find -newer` | `find /etc -newer /etc/hostname` | Modificados después que el archivo de referencia |
| `find -exec` | `find . -name '*.tmp' -exec rm {} \;` | Ejecuta un comando por cada resultado (más lento) |
| `xargs` | `find . -name '*.log' \| xargs wc -l` | Pasa los resultados como argumentos de un solo comando (más rápido) |
| `xargs -I{}` | `find . -name '*.bak' \| xargs -I{} mv {} /backup/` | Sustituye `{}` por cada resultado individualmente |
| `xargs -P` | `find . -name '*.jpg' \| xargs -P 4 -I{} convert {} {}.png` | Procesamiento paralelo con 4 workers |

**`-exec` vs `xargs`:** `-exec comando {} \;` lanza un proceso nuevo *por cada archivo encontrado* — simple pero lento con muchos resultados. `find ... | xargs comando` agrupa varios nombres en una sola invocación del comando — mucho más eficiente. Regla práctica: usar `-exec` para pocos archivos o lógica compleja; `xargs` para lotes grandes.

**Cuidado con espacios en nombres de archivo:** si los nombres pueden tener espacios, usar `find ... -print0 | xargs -0 ...` para evitar que se corten mal.

```bash
# Eliminar archivos temporales de más de 30 días (dry-run primero: reemplazar rm por echo)
find /tmp -name '*.tmp' -mtime +30 -exec rm {} \;

# Contar líneas de todos los .log del sistema, en paralelo
find /var/log -name '*.log' -print0 | xargs -0 -P 4 wc -l

# Buscar y reparar permisos de todos los .sh sin ejecución
find /opt/scripts -name '*.sh' ! -perm /u+x -exec chmod +x {} \;
```

### PERFIL A — sin conocimientos previos

1. Buscar todos los archivos `.pdf` en tu home: `find ~ -iname '*.pdf'`
2. Buscar directorios vacíos en `/tmp`: `find /tmp -type d -empty`
3. Contar cuántos archivos `.conf` hay en `/etc`: `find /etc -name '*.conf' | wc -l`

### PERFIL B — con conocimientos previos

1. Encontrar los 10 archivos más grandes de `/var`: `find /var -type f -exec du -h {} \; | sort -rh | head -10`
2. Buscar archivos world-writable (riesgo de seguridad) en todo el sistema: `find / -xdev -type f -perm -002 2>/dev/null`
3. Comparar el tiempo de `-exec` vs `xargs` procesando 1000+ archivos con `time`

---

## 1.3 — Expresiones Regulares Extendidas (ERE)

### Marco teórico

`grep -E` (o `egrep`) habilita metacaracteres sin necesidad de escaparlos con `\`. Es el estándar recomendado sobre BRE (Basic Regular Expressions) por ser más legible.

| Metacarácter | Significado | Ejemplo |
|---|---|---|
| `.` | Cualquier carácter | `a.c` → "abc", "axc" |
| `*` | 0 o más repeticiones | `ab*c` → "ac", "abc", "abbc" |
| `+` | 1 o más repeticiones | `[0-9]+` → uno o más dígitos |
| `?` | 0 o 1 repetición | `colou?r` → "color" y "colour" |
| `^` | Inicio de línea | `^root` → líneas que empiezan con "root" |
| `$` | Fin de línea | `\.sh$` → líneas que terminan en ".sh" |
| `[...]` | Clase de caracteres | `[A-Z]` → una mayúscula |
| `[^...]` | Negación de clase | `[^0-9]` → cualquier carácter que no sea dígito |
| `\|` | Alternancia (OR) | `error\|warning` → cualquiera de las dos |
| `{n,m}` | Entre n y m repeticiones | `[0-9]{3,5}` → de 3 a 5 dígitos |
| `()` | Agrupación | `(ab)+` → "ab", "abab", "ababab" |
| `\b` | Límite de palabra | `\bLinux\b` → "Linux" pero no "GNU/Linux2" |

```bash
# Líneas que empiezan con una IP (formato aproximado)
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/nginx/access.log

# Usuarios con shell válida (no /nologin ni /false)
grep -vE '/(nologin|false)$' /etc/passwd | cut -d: -f1

# Emails únicos en un archivo de log
grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' log.txt | sort -u
```

### PERFIL A — sin conocimientos previos

1. Buscar líneas que empiecen con un número: `grep -E '^[0-9]' archivo`
2. Buscar palabras en mayúsculas de 4 letras o más: `grep -E '\b[A-Z]{4,}\b' archivo`
3. Buscar "error" o "warning" (sin importar mayúsculas): `grep -iE 'error|warning' /var/log/syslog`

### PERFIL B — con conocimientos previos

1. Validar formato de IP con regex (aproximado, sin rangos 0-255 exactos): `grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$'`
2. Extraer todos los timestamps `HH:MM:SS` de un log: `grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}'`
3. Diferencia práctica entre BRE (`grep`) y ERE (`grep -E`): probar `grep 'a\+b'` vs `grep -E 'a+b'` sobre el mismo archivo

---

## 1.4 — Gestión de Procesos

### Marco teórico — anatomía de un proceso

Todo proceso Linux tiene un **PID** (identificador único), un **PPID** (proceso padre) y un **estado**. Los estados posibles: `R` (ejecutando), `S` (durmiendo, esperando evento), `D` (esperando I/O — no se puede matar), `T` (detenido, Ctrl+Z), `Z` (zombie — terminó pero el padre no recogió su exit code).

| Comando | Ejemplo | Descripción |
|---|---|---|
| `ps aux` | `ps aux` | Todos los procesos, formato BSD (usuario, %CPU, %MEM, comando) |
| `ps -ef` | `ps -ef \| grep nginx` | Todos los procesos, formato System V (PPID visible) |
| `ps --sort` | `ps aux --sort=-%cpu \| head -6` | Top 5 procesos por uso de CPU |
| `top` | `top` | Monitor interactivo — `q` salir, `k` matar, `M` ordenar por RAM, `P` por CPU |
| `htop` | `htop` | Versión mejorada de `top` (puede requerir instalación) |
| `pgrep` | `pgrep -l bash` | Busca PID por nombre de proceso |
| `pgrep -u` | `pgrep -u alumno` | PIDs de todos los procesos de un usuario |
| `kill` | `kill -15 1234` | Envía señal `SIGTERM` (15) — pedido educado de terminar |
| `kill -9` | `kill -9 1234` | Envía `SIGKILL` (9) — terminación forzosa, sin limpieza |
| `killall` | `killall firefox` | Mata todos los procesos con ese nombre exacto |
| `pkill` | `pkill -u alumno` | Mata procesos por criterio (usuario, nombre, patrón) |
| `jobs` | `jobs` | Lista los jobs en segundo plano de la sesión actual |
| `bg` | `bg %1` | Reanuda el job 1 en segundo plano |
| `fg` | `fg %1` | Trae el job 1 al primer plano |
| `nohup` | `nohup ./script.sh &` | Ejecuta en segundo plano, sobrevive al cierre de la sesión |
| `nice` | `nice -n 10 comando` | Inicia con prioridad reducida (rango -20 a 19; mayor número = menor prioridad) |
| `renice` | `renice -n 5 -p 1234` | Cambia la prioridad de un proceso ya corriendo |

**`SIGTERM` (15) vs `SIGKILL` (9):** `SIGTERM` le pide al proceso que termine — el proceso puede capturar la señal, guardar su estado y salir limpio. `SIGKILL` lo mata de inmediato, sin darle chance de liberar recursos ni cerrar archivos correctamente. **Regla:** siempre probar `kill` (sin `-9`) primero; usar `-9` solo si el proceso no responde tras unos segundos.

```bash
# Ciclo típico de gestión de un job
sleep 300 &         # lanza en background
jobs                # [1]+ Running    sleep 300 &
kill %1              # lo termina por número de job
```

### PERFIL A — sin conocimientos previos

1. Abrir `top`, observar la primera línea (load average) y la columna `%CPU` durante 1 minuto
2. En otra terminal: `sleep 300 &` — comprobar que aparece en `jobs`
3. Traer al frente con `fg %1`, cancelar con `Ctrl+C`
4. Buscar el proceso de tu shell: `pgrep -l bash`

### PERFIL B — con conocimientos previos

1. Analizar `load average`: ¿qué significa un load de 2.5 en un sistema de 4 núcleos?
2. Identificar procesos zombie: `ps aux | awk '$8 ~ /Z/'`
3. Cambiar la prioridad de un proceso en ejecución: `sudo renice -n 5 -p $(pgrep bash | head -1)`
4. Lanzar 3 `sleep` en background y matarlos todos en un solo comando: `sleep 100 & sleep 100 & sleep 100 &` luego `kill %1 %2 %3`

---

## 1.5 — `lsof`, `/proc` y diagnóstico de red básico

### Marco teórico

`lsof` (**l**i**s**t **o**pen **f**iles) responde la pregunta "¿qué proceso tiene abierto este archivo/puerto?" — imprescindible cuando un dispositivo está "ocupado" o un puerto no libera.

| Comando | Ejemplo | Descripción |
|---|---|---|
| `lsof` | `lsof /var/log/syslog` | Qué procesos tienen abierto ese archivo |
| `lsof -i` | `lsof -i :80` | Qué proceso está escuchando/usando el puerto 80 |
| `lsof -u` | `lsof -u alumno` | Archivos abiertos por un usuario |
| `lsof -p` | `lsof -p 1234` | Archivos abiertos por un PID específico |
| `ip addr` | `ip addr show` | Interfaces de red y sus direcciones IP |
| `ping` | `ping -c 4 8.8.8.8` | Prueba de conectividad (4 paquetes) |
| `traceroute` | `traceroute google.com` | Ruta de saltos hasta el destino |
| `ss -tulnp` | `ss -tulnp` | Puertos TCP/UDP en escucha, con el proceso dueño (reemplaza a `netstat`) |
| `hostname -I` | `hostname -I` | Direcciones IP del equipo |

**`/proc` — la ventana al kernel:** es un sistema de archivos virtual, no ocupa disco real. Cada proceso tiene su carpeta `/proc/<PID>/` con información en vivo.

```bash
cat /proc/cpuinfo                    # Detalle de CPU
cat /proc/meminfo                    # Memoria detallada
cat /proc/<PID>/status               # Estado de un proceso puntual
ls -la /proc/<PID>/fd/               # Descriptores de archivo abiertos por ese proceso
```

### PERFIL A — sin conocimientos previos

1. Ver qué interfaces de red tiene el equipo: `ip addr show`
2. Verificar conectividad a internet: `ping -c 4 8.8.8.8`
3. Ver qué puertos están escuchando: `ss -tulnp`

### PERFIL B — con conocimientos previos

1. Identificar qué proceso usa el puerto 22: `sudo lsof -i :22`
2. Trazar la ruta de red hasta un destino externo: `traceroute -n 8.8.8.8`
3. Investigar `/proc/$(pgrep -o bash)/status` — identificar `VmRSS` (memoria residente)

---

## 1.6 — Alias y variables de entorno persistentes

Los alias y variables definidos en la terminal se pierden al cerrar la sesión. Para que persistan, se agregan a `~/.bashrc` (shell interactiva sin login) o `~/.bash_profile` (shell de login).

```bash
# Agregar al final de ~/.bashrc
echo "alias ll='ls -la --color=auto'" >> ~/.bashrc
echo "export EDITOR=nano" >> ~/.bashrc
source ~/.bashrc    # recargar sin cerrar sesión
```

| Variable | Uso |
|---|---|
| `PATH` | Directorios donde el shell busca ejecutables — agregar con `export PATH=$PATH:~/scripts` |
| `EDITOR` | Editor por defecto que usan `crontab -e`, `visudo`, etc. |
| `HISTSIZE` | Cantidad de comandos guardados en el historial |

---

## 🧪 Laboratorio Práctico — Auditoría avanzada del sistema (60 min)

1. Generar reporte de usuarios reales: `cut -d: -f1,3,6,7 /etc/passwd | awk -F: '$2>=1000'` — ajustar según formato
2. Top 10 procesos por RAM: `ps aux --sort=-%mem | head -10 > /tmp/mem_report.txt`
3. Buscar y limpiar archivos `.tmp` de más de 7 días en `/tmp` (usar `find` con `-mtime +7`)
4. Identificar el proceso que escucha en el puerto 22: `sudo lsof -i :22` o `sudo ss -tulnp | grep :22`
5. Extraer las 5 IPs con más intentos fallidos de SSH usando `grep -oE`, `sort`, `uniq -c`
6. Lanzar 3 jobs en background con `sleep`, listarlos con `jobs`, matarlos todos con un solo `kill`
7. Verificar conectividad de red y guardar el resultado: `ping -c 4 8.8.8.8 > /tmp/conectividad.txt`
8. Generar el informe final concatenando todo en `~/auditoria_avanzada_$(date +%Y%m%d).txt`

**Entregable:** `auditoria_avanzada_<fecha>.txt` con la salida de cada paso.

---

## 📋 Evaluación

| Instrumento Perfil A | Instrumento Perfil B |
|---|---|
| Completar un pipe de `cut/sort/uniq` dado el resultado esperado | Escribir un one-liner que resuelva un problema real de análisis de logs |
| Identificar el estado de un proceso a partir de una salida de `ps aux` dada | Diagnosticar con `lsof`/`ss` qué proceso ocupa un puerto en conflicto |
| Diferenciar `kill` de `kill -9` con sus consecuencias | Justificar el uso de `xargs -P` para procesamiento paralelo con datos reales |

**Criterios de evaluación**

| Criterio | Peso |
|---|---|
| Uso correcto de `cut/sort/uniq` en cadenas de pipes | 25% |
| `find` + `xargs` aplicado correctamente, con `-exec` cuando corresponde | 25% |
| Gestión de procesos: identificar, priorizar y terminar con la señal adecuada | 30% |
| Diagnóstico de red/puertos con `lsof`/`ss` documentado | 20% |

---

## Referencia rápida

```bash
cut -d: -f1 /etc/passwd | sort | uniq -c | sort -rn     # patrón extraer→ordenar→contar
find . -name '*.log' -mtime +7 | xargs rm                # limpieza en lote
grep -E 'error|warn' archivo                              # alternancia ERE
ps aux --sort=-%cpu | head -10                            # top procesos por CPU
kill -15 <PID>  ||  kill -9 <PID>                          # terminar: educado, luego forzado
lsof -i :<puerto>                                          # qué proceso usa un puerto
ss -tulnp                                                  # puertos en escucha
```

---

*Linux II — Redes POSIX SHSCRIPT · CTT · Año 2026. Complemento a Clase 0 (Nexo) y Clase 1.*
