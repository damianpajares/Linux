# Laboratorio 2 — Unit File, Fallos y Hardening

> **Unidad:** U1 — Gestión de Servicios con systemd  
> **Clase de referencia:** Clase 2 — Units Avanzadas, Diagnóstico de Fallos y Timers  
> **Semana:** 2–3 · **Duración estimada:** 50–60 min  
> **Perfil:** A (Pasos 1–4) · B (Pasos 1–6)  

---

## Objetivo

Escribir, gestionar, romper y endurecer un servicio propio desde cero. Al finalizar este laboratorio el estudiante será capaz de:

- Crear un script bash que actúe como proceso de larga duración
- Escribir una unit file `.service` completa con las tres secciones
- Gestionar el ciclo de vida del servicio con `systemctl`
- Inducir un fallo controlado y diagnosticarlo con `journalctl`
- Crear un timer companion que ejecute un servicio periódicamente
- Medir y mejorar el nivel de hardening de un servicio

---

## Prerequisitos

| Requisito | Verificación |
|-----------|-------------|
| Laboratorio 1 completado | Familiaridad con `systemctl` y `journalctl` |
| Clase 2 completada | Conceptos: Restart=, dependencias, timers, cgroups |
| Editor de texto disponible | `nano`, `vim` o `micro` |
| Usuario con `sudo` | `sudo whoami` → debe retornar `root` |

---

## Entorno

```
Sistema operativo : Ubuntu 24.04 LTS (o Debian 12)
Directorio de trabajo : /opt/ctt-lab2/
Directorio de units   : /etc/systemd/system/
Usuario del servicio  : lab2-svc (creado en Paso 1)
```

---

## Paso 1 — Preparar el entorno

### 1a. Crear el usuario de sistema

El servicio **nunca** debe correr como `root`. Crear un usuario de sistema sin shell interactiva:

```bash
sudo useradd -r -s /sbin/nologin -d /opt/ctt-lab2 lab2-svc
```

Verificar:

```bash
id lab2-svc
grep lab2-svc /etc/passwd
```

**¿Qué significa `-r`? ¿Y `-s /sbin/nologin`?** (anotar en entregables)

### 1b. Crear la estructura de directorios

```bash
sudo mkdir -p /opt/ctt-lab2/{bin,logs,run}
sudo chown -R lab2-svc:lab2-svc /opt/ctt-lab2
```

Verificar permisos:

```bash
ls -la /opt/ctt-lab2/
```

---

## Paso 2 — Crear el script a ejecutar

### 2a. Script de monitoreo continuo

Crear el script principal del servicio:

```bash
sudo nano /opt/ctt-lab2/bin/mi-app.sh
```

Contenido del script:

```bash
#!/usr/bin/env bash
# mi-app.sh — Proceso de demostración para Lab 2
# Simula un servicio de monitoreo que registra estado del sistema

set -euo pipefail

LOG_FILE="/opt/ctt-lab2/logs/mi-app.log"
PID_FILE="/opt/ctt-lab2/run/mi-app.pid"

# Registrar PID propio
echo $$ > "${PID_FILE}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "INFO  mi-app iniciando — PID $$"
log "INFO  Usuario: $(whoami)"
log "INFO  Hostname: $(hostname)"

# Bucle principal — proceso de larga duración
while true; do
  LOAD=$(cut -d' ' -f1 /proc/loadavg)
  MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
  log "STAT  load=${LOAD} mem_free=${MEM_FREE}kB"
  sleep 5
done
```

### 2b. Asignar permisos de ejecución

```bash
sudo chmod +x /opt/ctt-lab2/bin/mi-app.sh
sudo chown lab2-svc:lab2-svc /opt/ctt-lab2/bin/mi-app.sh
```

### 2c. Probar el script manualmente

```bash
sudo -u lab2-svc /opt/ctt-lab2/bin/mi-app.sh &
sleep 3
kill %1
```

¿Funciona correctamente? ¿Qué muestra en la consola?

---

## Paso 3 — Escribir la unit file

```bash
sudo nano /etc/systemd/system/mi-app.service
```

Contenido de la unit file:

```ini
[Unit]
Description=CTT Lab2 — Mi Aplicación de Monitoreo
Documentation=https://github.com/ctt/linux3-labs
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=lab2-svc
Group=lab2-svc
WorkingDirectory=/opt/ctt-lab2

# Binario principal
ExecStart=/opt/ctt-lab2/bin/mi-app.sh

# Política de reinicio
Restart=on-failure
RestartSec=10
StartLimitIntervalSec=60
StartLimitBurst=3

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mi-app

# Hardening básico
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/ctt-lab2/logs /opt/ctt-lab2/run

[Install]
WantedBy=multi-user.target
```

### 3a. Verificar la sintaxis de la unit

```bash
# Verificar antes de recargar
sudo systemd-analyze verify /etc/systemd/system/mi-app.service
```

Si hay errores, corregirlos antes de continuar.

### 3b. Recargar y activar el servicio

```bash
# Paso obligatorio después de crear o modificar una unit
sudo systemctl daemon-reload

# Activar e iniciar en un solo comando
sudo systemctl enable --now mi-app.service
```

### 3c. Verificar el estado

```bash
systemctl status mi-app.service
```

**En la salida, identificar y anotar:**
- [ ] Estado `active (running)` en la línea `Active:`
- [ ] Main PID del proceso
- [ ] El árbol de cgroups
- [ ] Las últimas líneas de log

```bash
# Ver logs en tiempo real
journalctl -u mi-app -f
```

---

## Paso 4 — Simular un fallo

### 4a. Obtener el PID del proceso

```bash
systemctl show mi-app --property=MainPID --value
```

Guardar el PID en una variable:

```bash
MI_APP_PID=$(systemctl show mi-app --property=MainPID --value)
echo "PID del servicio: ${MI_APP_PID}"
```

### 4b. Matar el proceso brutalmente

```bash
# En una terminal, abrir journalctl en tiempo real
journalctl -u mi-app -f &

# En la misma terminal, matar el proceso
sudo kill -9 ${MI_APP_PID}
```

**Observar en la salida de journalctl:**
- El mensaje de fallo (`code=killed, status=9/KILL`)
- El mensaje `Scheduled restart job`
- El reinicio automático después de `RestartSec=10`

### 4c. Documentar el fallo

```bash
# Ver el historial completo del fallo
journalctl -u mi-app --since '5 minutes ago' --no-pager
```

**Preguntas de análisis:**

1. ¿Cuántos segundos tardó en reiniciarse el servicio? ¿Coincide con `RestartSec=10`?
2. ¿Qué diferencia habría si `Restart=always` en vez de `Restart=on-failure`?
3. Si matamos el proceso 4 veces en menos de 60 segundos, ¿qué sucede? (pista: `StartLimitBurst=3`)

### 4d. Inducir un fallo por configuración incorrecta

```bash
# Guardar copia de la unit file correcta
sudo cp /etc/systemd/system/mi-app.service /tmp/mi-app.service.bak

# Modificar para apuntar a un binario que no existe
sudo sed -i 's|ExecStart=.*|ExecStart=/bin/nonexistent-binary|' \
    /etc/systemd/system/mi-app.service

sudo systemctl daemon-reload
sudo systemctl restart mi-app.service
```

Observar el fallo:

```bash
journalctl -u mi-app -n 10 --no-pager
systemctl status mi-app.service
```

Restaurar la configuración correcta:

```bash
sudo cp /tmp/mi-app.service.bak /etc/systemd/system/mi-app.service
sudo systemctl daemon-reload
sudo systemctl restart mi-app.service
```

---

## Paso 5 — Crear un Timer companion

### 5a. Script oneshot para el timer

```bash
sudo nano /opt/ctt-lab2/bin/mi-reporte.sh
```

```bash
#!/usr/bin/env bash
# mi-reporte.sh — Oneshot: genera un reporte del estado del sistema

set -euo pipefail

REPORT_DIR="/opt/ctt-lab2/logs"
REPORT_FILE="${REPORT_DIR}/reporte-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "=== REPORTE CTT LAB2 ==="
  echo "Fecha    : $(date)"
  echo "Hostname : $(hostname)"
  echo "Uptime   : $(uptime -p)"
  echo ""
  echo "--- Servicios activos ---"
  systemctl list-units --type=service --state=running --no-legend | wc -l
  echo "servicios corriendo"
  echo ""
  echo "--- Top 5 procesos por CPU ---"
  ps aux --sort=-%cpu | head -6
} > "${REPORT_FILE}"

echo "Reporte generado: ${REPORT_FILE}"
```

```bash
sudo chmod +x /opt/ctt-lab2/bin/mi-reporte.sh
sudo chown lab2-svc:lab2-svc /opt/ctt-lab2/bin/mi-reporte.sh
```

### 5b. Unit file del servicio oneshot

```bash
sudo nano /etc/systemd/system/mi-reporte.service
```

```ini
[Unit]
Description=CTT Lab2 — Reporte periódico del sistema
After=mi-app.service

[Service]
Type=oneshot
User=lab2-svc
Group=lab2-svc
WorkingDirectory=/opt/ctt-lab2
ExecStart=/opt/ctt-lab2/bin/mi-reporte.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mi-reporte

# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/ctt-lab2/logs
```

> **Importante:** El servicio oneshot **no tiene** sección `[Install]` — es el timer quien lo activa.

### 5c. Timer companion

```bash
sudo nano /etc/systemd/system/mi-reporte.timer
```

```ini
[Unit]
Description=CTT Lab2 — Timer para reporte cada 2 minutos (prueba)
Requires=mi-reporte.service

[Timer]
# Para prueba: cada 2 minutos
OnCalendar=*:0/2
# Persistent=true asegura que si el sistema estuvo apagado,
# se ejecuta al volver a encender si la hora ya pasó
Persistent=true

[Install]
WantedBy=timers.target
```

### 5d. Activar el timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mi-reporte.timer
```

### 5e. Verificar el timer

```bash
# Ver todos los timers activos
systemctl list-timers --all

# Ver cuándo se ejecutará próximamente
systemctl list-timers mi-reporte.timer

# Esperar 2 minutos y verificar logs
journalctl -u mi-reporte -f
```

**Preguntas de análisis:**

1. ¿Qué muestra el campo `NEXT` en `systemctl list-timers`?
2. ¿Qué ventaja tiene `Persistent=true`?
3. ¿Cómo cambiarías el timer para que corra todos los días a las 3 AM?

---

## Paso 6 — Hardening avanzado (Perfil B)

### 6a. Medir el nivel de seguridad actual

```bash
systemd-analyze security mi-app.service
```

Anotar el **score actual** (escala 0–10, donde 0 es más seguro).

### 6b. Agregar directivas de hardening adicionales

Editar la unit file:

```bash
sudo nano /etc/systemd/system/mi-app.service
```

Agregar en la sección `[Service]`, después del hardening existente:

```ini
# Hardening adicional (Perfil B)
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

# Límites de recursos
MemoryMax=100M
CPUQuota=20%
TasksMax=50
```

### 6c. Recargar y medir de nuevo

```bash
sudo systemctl daemon-reload
sudo systemctl restart mi-app.service

# Verificar que sigue funcionando
systemctl status mi-app.service

# Medir score de seguridad
systemd-analyze security mi-app.service
```

**Preguntas de análisis:**

1. ¿Cuánto bajó el score después de agregar las directivas?
2. ¿Qué directiva tuvo mayor impacto en la reducción del score?
3. ¿Qué hace `SystemCallFilter=@system-service`? ¿Por qué es importante?

---

## Limpieza (al finalizar el laboratorio)

```bash
# Detener y deshabilitar servicios
sudo systemctl disable --now mi-app.service mi-reporte.timer

# Eliminar unit files
sudo rm /etc/systemd/system/mi-app.service
sudo rm /etc/systemd/system/mi-reporte.service
sudo rm /etc/systemd/system/mi-reporte.timer

# Recargar systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Eliminar usuario y directorio (opcional)
sudo userdel lab2-svc
sudo rm -rf /opt/ctt-lab2
```

---

## Entregables

```
labs/
├── LAB02_respuestas.md          ← Respuestas a todas las preguntas
├── mi-app.service               ← Unit file final con hardening
├── mi-reporte.service           ← Unit file del servicio oneshot
├── mi-reporte.timer             ← Timer file
└── LAB02_journal_fallo.txt      ← Output copiado de journalctl durante el fallo
```

El archivo `LAB02_respuestas.md` debe incluir:

- [ ] Respuesta a todas las preguntas de análisis de cada paso
- [ ] Score inicial de `systemd-analyze security` (antes del hardening)
- [ ] Score final de `systemd-analyze security` (después del hardening)
- [ ] Output de `systemctl list-timers` mostrando el timer activo
- [ ] Output de `journalctl` durante el ciclo fallo → reinicio automático

---

## Criterios de evaluación

| Criterio | Perfil A | Perfil B | Peso |
|----------|----------|----------|------|
| Unit file correcta con `[Unit][Service][Install]` | ✓ | ✓ | 30% |
| Servicio activo y reiniciándose ante fallos | ✓ | ✓ | 20% |
| Timer companion funcionando | ✓ | ✓ | 25% |
| Hardening básico (≥ 3 directivas) | ✓ | ✓ | 15% |
| Score `systemd-analyze security` < 4.0 | — | ✓ | 10% |

---

## Referencia rápida

```bash
# Verificar unit file antes de cargarla
systemd-analyze verify /etc/systemd/system/mi-app.service

# Recargar SIEMPRE después de modificar una unit
sudo systemctl daemon-reload

# Activar e iniciar en un paso
sudo systemctl enable --now mi-app.service

# Ver logs del fallo
journalctl -u mi-app -p err --since '10 min ago'

# Medir seguridad
systemd-analyze security mi-app.service

# Ver timers activos
systemctl list-timers --all
```

---

## Recursos

- Clase 2: _Units Avanzadas, Diagnóstico de Fallos y Timers_ — slides 3 a 11
- `man systemd.service` — todas las directivas de la sección `[Service]`
- `man systemd.timer` — directivas de timer y sintaxis `OnCalendar`
- `man systemd-analyze` — referencia de `security` y `verify`

---

*Linux III — Redes y Servicios POSIX · CTT · Año 2026*
