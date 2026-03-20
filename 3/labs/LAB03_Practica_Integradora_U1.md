# Laboratorio 3 — Práctica Integradora U1

> **Unidad:** U1 — Gestión de Servicios con systemd (CIERRE)  
> **Clase de referencia:** Clase 3 — Journald Avanzado, Diagnóstico de Fallos y Cierre U1  
> **Semana:** 4–5 · **Duración estimada:** 60 min  
> **Perfil:** A (Pasos 1–4) · B (Pasos 1–6)  

---

## Objetivo

Construir el ecosistema completo de systemd que se utilizará durante toda la cursada. Integrar todos los conceptos de U1 en un único escenario de producción simulado. Al finalizar este laboratorio el estudiante será capaz de:

- Crear servicios con `Type=`, hooks y `OnFailure=` correctamente configurados
- Implementar un sistema de alertas usando `OnFailure=`
- Aplicar la metodología de 5 pasos para diagnóstico sistemático
- Configurar `journald` para persistencia y auditoría
- Exportar logs en formato JSON para integración con herramientas externas
- Alcanzar un score de seguridad < 4.0 en `systemd-analyze security`

---

## Prerequisitos

| Requisito | Verificación |
|-----------|-------------|
| Laboratorios 1 y 2 completados | Entregables de LAB01 y LAB02 |
| Clase 3 completada | Conceptos: Type=, hooks, journald.conf, logrotate, diagnóstico |
| Laboratorio 2 limpiado | No deben quedar servicios `lab2-svc` activos |

---

## Entorno

```
Sistema operativo  : Ubuntu 24.04 LTS (o Debian 12)
Directorio base    : /opt/ctt/
Usuario del sistema: ctt-svc
Estructura esperada:
  /opt/ctt/
  ├── monitor/      ← ctt-monitor.service
  ├── backup/       ← ctt-backup.service + ctt-backup.timer
  ├── cleanup/      ← ctt-cleanup.service + ctt-cleanup.timer
  ├── alert/        ← ctt-alert.service (OnFailure)
  └── logs/         ← logs de todos los servicios
```

---

## Paso 1 — Preparar el ecosistema

### 1a. Crear usuario y estructura

```bash
# Usuario de sistema para todos los servicios CTT
sudo useradd -r -s /sbin/nologin -d /opt/ctt ctt-svc

# Estructura de directorios
sudo mkdir -p /opt/ctt/{monitor,backup,cleanup,alert,logs,run}
sudo chown -R ctt-svc:ctt-svc /opt/ctt
sudo chmod 750 /opt/ctt
```

### 1b. Crear los scripts

**Script 1 — Monitor (proceso continuo):**

```bash
sudo nano /opt/ctt/monitor/ctt-monitor.sh
```

```bash
#!/usr/bin/env bash
# ctt-monitor.sh — Servicio de monitoreo continuo del sistema CTT
# Type=simple — proceso de larga duración que NO bifurca

set -euo pipefail
readonly INTERVAL=10

log() { echo "[$(date -Iseconds)] [$1] $2"; }

validate_environment() {
  [[ -d /opt/ctt/logs ]] || { log "ERROR" "Directorio de logs no encontrado"; exit 1; }
  [[ -w /opt/ctt/logs ]] || { log "ERROR" "Sin permisos de escritura en logs"; exit 1; }
}

log "INFO" "ctt-monitor iniciando — PID $$ — Usuario: $(whoami)"
validate_environment

trap 'log "INFO" "ctt-monitor detenido (SIGTERM)"; exit 0' TERM

while true; do
  LOAD=$(cut -d' ' -f1 /proc/loadavg)
  MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  MEM_FREE=$(grep MemFree  /proc/meminfo | awk '{print $2}')
  MEM_PCT=$(( (MEM_TOTAL - MEM_FREE) * 100 / MEM_TOTAL ))
  DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')

  log "STAT" "load=${LOAD} mem_uso=${MEM_PCT}% disco_raiz=${DISK_PCT}%"

  if (( MEM_PCT > 90 )); then
    log "WARN" "Uso de memoria crítico: ${MEM_PCT}%"
  fi

  sleep "${INTERVAL}"
done
```

**Script 2 — Backup (oneshot):**

```bash
sudo nano /opt/ctt/backup/ctt-backup.sh
```

```bash
#!/usr/bin/env bash
# ctt-backup.sh — Backup oneshot de configuraciones críticas
# Type=oneshot — termina después de completarse

set -euo pipefail

BACKUP_DIR="/opt/ctt/logs/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup-${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"

echo "[$(date -Iseconds)] [INFO] Iniciando backup — ${BACKUP_FILE}"

# Backup de configuraciones systemd propias del CTT
tar -czf "${BACKUP_FILE}" \
  /opt/ctt/monitor/ctt-monitor.sh \
  /opt/ctt/backup/ctt-backup.sh \
  /opt/ctt/cleanup/ctt-cleanup.sh \
  2>/dev/null || true

BACKUP_SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
echo "[$(date -Iseconds)] [OK]   Backup completado — ${BACKUP_FILE} (${BACKUP_SIZE})"

# Mantener solo los últimos 7 backups
find "${BACKUP_DIR}" -name "backup-*.tar.gz" -mtime +7 -delete
```

**Script 3 — Cleanup (oneshot):**

```bash
sudo nano /opt/ctt/cleanup/ctt-cleanup.sh
```

```bash
#!/usr/bin/env bash
# ctt-cleanup.sh — Limpieza periódica de logs y temporales

set -euo pipefail

LOG_DIR="/opt/ctt/logs"

echo "[$(date -Iseconds)] [INFO] Iniciando limpieza"

# Rotar logs propios mayores a 7 días
DELETED=$(find "${LOG_DIR}" -name "*.log" -mtime +7 -delete -print | wc -l)
echo "[$(date -Iseconds)] [OK]   Logs eliminados: ${DELETED}"

# Estadísticas del directorio
TOTAL_SIZE=$(du -sh "${LOG_DIR}" | cut -f1)
echo "[$(date -Iseconds)] [INFO] Tamaño total de logs: ${TOTAL_SIZE}"
```

**Script 4 — Alert (OnFailure):**

```bash
sudo nano /opt/ctt/alert/ctt-alert.sh
```

```bash
#!/usr/bin/env bash
# ctt-alert.sh — Alerta disparada por OnFailure= de otros servicios
# Recibe la unidad que falló como variable de entorno

set -euo pipefail

# systemd pasa el nombre de la unit que falló mediante %i (instance)
FAILED_UNIT="${1:-desconocido}"
TIMESTAMP=$(date -Iseconds)
ALERT_LOG="/opt/ctt/logs/alertas.log"

echo "[${TIMESTAMP}] [ALERTA] Servicio en fallo: ${FAILED_UNIT}" >> "${ALERT_LOG}"
echo "[${TIMESTAMP}] [ALERTA] Ver diagnóstico: journalctl -u ${FAILED_UNIT} -n 20" >> "${ALERT_LOG}"

# En producción real: aquí va el webhook, email, o notificación
echo "[${TIMESTAMP}] [INFO]  Alerta registrada en ${ALERT_LOG}"
```

### 1c. Asignar permisos

```bash
sudo chmod +x /opt/ctt/{monitor,backup,cleanup,alert}/*.sh
sudo chown -R ctt-svc:ctt-svc /opt/ctt
```

---

## Paso 2 — Crear las unit files

### 2a. ctt-monitor.service (Type=simple con hooks)

```bash
sudo nano /etc/systemd/system/ctt-monitor.service
```

```ini
[Unit]
Description=CTT Lab3 — Monitor de Sistema
Documentation=https://github.com/ctt/linux3-labs
After=network.target
Wants=network-online.target

# Si ctt-monitor falla, lanzar el servicio de alerta
OnFailure=ctt-alert@ctt-monitor.service

[Service]
Type=simple
User=ctt-svc
Group=ctt-svc
WorkingDirectory=/opt/ctt/monitor

# Hook de pre-inicio: validar que el script existe
ExecStartPre=/usr/bin/test -x /opt/ctt/monitor/ctt-monitor.sh
ExecStartPre=/usr/bin/test -w /opt/ctt/logs

# Proceso principal
ExecStart=/opt/ctt/monitor/ctt-monitor.sh

# Hook post-inicio: registrar inicio
ExecStartPost=/bin/sh -c 'echo "[$(date -Iseconds)] [EVENT] ctt-monitor iniciado" >> /opt/ctt/logs/events.log'

# Hook de parada: registrar parada limpia
ExecStopPost=/bin/sh -c 'echo "[$(date -Iseconds)] [EVENT] ctt-monitor detenido" >> /opt/ctt/logs/events.log'

# Políticas de reinicio
Restart=on-failure
RestartSec=10
StartLimitIntervalSec=120
StartLimitBurst=3

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ctt-monitor

# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=true
LockPersonality=true
RestrictRealtime=true
ReadWritePaths=/opt/ctt/logs
RuntimeDirectory=ctt

# Límites de recursos (cgroups v2)
MemoryMax=64M
CPUQuota=10%
TasksMax=20

[Install]
WantedBy=multi-user.target
```

### 2b. ctt-backup.service (Type=oneshot)

```bash
sudo nano /etc/systemd/system/ctt-backup.service
```

```ini
[Unit]
Description=CTT Lab3 — Backup de configuraciones
OnFailure=ctt-alert@ctt-backup.service

[Service]
Type=oneshot
User=ctt-svc
Group=ctt-svc
WorkingDirectory=/opt/ctt/backup

ExecStartPre=/usr/bin/test -d /opt/ctt/logs
ExecStart=/opt/ctt/backup/ctt-backup.sh

StandardOutput=journal
StandardError=journal
SyslogIdentifier=ctt-backup

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/ctt/logs

# Sin sección [Install] — activado solo por el timer
```

### 2c. ctt-backup.timer

```bash
sudo nano /etc/systemd/system/ctt-backup.timer
```

```ini
[Unit]
Description=CTT Lab3 — Timer de backup (cada 5 min para prueba)
Requires=ctt-backup.service

[Timer]
# Para prueba: cada 5 minutos
# En producción usar: OnCalendar=*-*-* 02:00:00
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

### 2d. ctt-cleanup.service y timer

```bash
sudo nano /etc/systemd/system/ctt-cleanup.service
```

```ini
[Unit]
Description=CTT Lab3 — Limpieza de logs y temporales

[Service]
Type=oneshot
User=ctt-svc
Group=ctt-svc
WorkingDirectory=/opt/ctt/cleanup

ExecStartPre=/usr/bin/test -w /opt/ctt/logs
ExecStart=/opt/ctt/cleanup/ctt-cleanup.sh

StandardOutput=journal
StandardError=journal
SyslogIdentifier=ctt-cleanup

NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/ctt/logs
```

```bash
sudo nano /etc/systemd/system/ctt-cleanup.timer
```

```ini
[Unit]
Description=CTT Lab3 — Timer de limpieza (diario en producción)
Requires=ctt-cleanup.service

[Timer]
# Para prueba: cada 10 minutos
OnCalendar=*:0/10
Persistent=true

[Install]
WantedBy=timers.target
```

### 2e. ctt-alert@.service (servicio instanciado)

```bash
sudo nano /etc/systemd/system/ctt-alert@.service
```

```ini
[Unit]
Description=CTT Lab3 — Alerta de fallo para %i
After=network.target

[Service]
Type=oneshot
User=ctt-svc
Group=ctt-svc

# %i es la instancia: el nombre del servicio que falló
ExecStart=/opt/ctt/alert/ctt-alert.sh %i

StandardOutput=journal
StandardError=journal
SyslogIdentifier=ctt-alert

NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/ctt/logs
```

---

## Paso 3 — Activar el ecosistema

```bash
# Verificar sintaxis de todas las units antes de activar
for unit in ctt-monitor ctt-backup ctt-cleanup; do
  sudo systemd-analyze verify /etc/systemd/system/${unit}.service
  echo "✓ ${unit}.service OK"
done

# Recargar systemd
sudo systemctl daemon-reload

# Activar servicios
sudo systemctl enable --now ctt-monitor.service
sudo systemctl enable --now ctt-backup.timer
sudo systemctl enable --now ctt-cleanup.timer

# Verificar estado general
echo "=== Estado de servicios CTT ==="
systemctl status ctt-monitor.service
echo ""
echo "=== Timers activos ==="
systemctl list-timers ctt-backup.timer ctt-cleanup.timer
```

---

## Paso 4 — Diagnóstico sistemático: 2 fallos inducidos

### Fallo A — Binario inexistente (ExecStartPre falla)

```bash
# 1. Verificar estado antes del fallo
systemctl status ctt-monitor.service

# 2. Guardar copia y romper la unit
sudo cp /etc/systemd/system/ctt-monitor.service /tmp/ctt-monitor.service.bak
sudo sed -i 's|ExecStart=.*|ExecStart=/opt/ctt/monitor/INEXISTENTE.sh|' \
    /etc/systemd/system/ctt-monitor.service
sudo systemctl daemon-reload

# 3. Intentar reiniciar y observar
sudo systemctl restart ctt-monitor.service

# 4. Aplicar metodología de 5 pasos
echo "--- PASO 1: ¿El servicio existe? ---"
systemctl status ctt-monitor.service

echo "--- PASO 2: ¿Cuál es el error exacto? ---"
journalctl -u ctt-monitor -n 20 --no-pager

echo "--- PASO 3: ¿Es problema de configuración? ---"
systemd-analyze verify /etc/systemd/system/ctt-monitor.service

# 5. Guardar el diagnóstico
journalctl -u ctt-monitor --since '5 min ago' --no-pager > \
    /tmp/lab3-fallo-A.txt
echo "Diagnóstico guardado en /tmp/lab3-fallo-A.txt"

# 6. Restaurar y verificar resolución
sudo cp /tmp/ctt-monitor.service.bak /etc/systemd/system/ctt-monitor.service
sudo systemctl daemon-reload
sudo systemctl restart ctt-monitor.service
systemctl status ctt-monitor.service
```

**Preguntas Fallo A:**

1. ¿En qué paso de la metodología encontraste el error?
2. ¿Qué mensaje exacto mostró `journalctl`?
3. ¿Qué código de salida (`status=`) reportó systemd?

---

### Fallo B — Permisos insuficientes (hardening vs. necesidades del proceso)

```bash
# 1. Modificar la unit para quitar el ReadWritePaths necesario
sudo cp /etc/systemd/system/ctt-monitor.service /tmp/ctt-monitor.service.bak
sudo sed -i '/ReadWritePaths/d' /etc/systemd/system/ctt-monitor.service
sudo systemctl daemon-reload
sudo systemctl restart ctt-monitor.service

# 2. Esperar 15 segundos y ver si falla
sleep 15
systemctl status ctt-monitor.service
journalctl -u ctt-monitor -n 20 --no-pager

# 3. Aplicar metodología — Paso 5 (permisos/recursos)
echo "--- PASO 5: ¿Es problema de permisos/recursos? ---"
systemctl show ctt-monitor | grep -E '(Protect|ReadWrite|Private)'

# 4. Guardar diagnóstico
journalctl -u ctt-monitor --since '5 min ago' --no-pager > \
    /tmp/lab3-fallo-B.txt

# 5. Restaurar
sudo cp /tmp/ctt-monitor.service.bak /etc/systemd/system/ctt-monitor.service
sudo systemctl daemon-reload
sudo systemctl restart ctt-monitor.service
```

**Preguntas Fallo B:**

1. ¿Qué error de permisos reportó journalctl? ¿A qué ruta intentó acceder?
2. ¿Qué directiva `Protect*` causó el problema?
3. ¿Cómo se balancean seguridad y funcionalidad en este caso?

---

## Paso 5 — Configurar journald para persistencia

### 5a. Activar almacenamiento persistente

```bash
# Crear directorio para persistencia
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal

# Verificar que la persistencia está activa
ls -la /var/log/journal/
```

### 5b. Configurar journald.conf para producción

```bash
sudo nano /etc/systemd/journald.conf
```

Agregar/modificar:

```ini
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=500M
SystemKeepFree=200M
SystemMaxFileSize=50M
SystemMaxFiles=5
MaxRetentionSec=30d
ForwardToSyslog=no
```

```bash
# Aplicar configuración
sudo systemctl restart systemd-journald

# Verificar
journalctl --disk-usage
```

### 5c. Filtrado avanzado y exportación JSON

```bash
# Ver logs de todos los servicios CTT del último boot
journalctl -u ctt-monitor -u ctt-backup -u ctt-cleanup -b --no-pager

# Solo errores de los últimos 15 minutos
journalctl -u ctt-monitor -p err --since '15 min ago' --no-pager

# Exportar a JSON para análisis
journalctl -u ctt-monitor --since '10 min ago' -o json | \
    python3 -m json.tool | head -60

# Verificar logs del boot anterior (requiere persistencia activada)
journalctl --list-boots
journalctl -b -1 -u ctt-monitor --no-pager | tail -20
```

**Preguntas de análisis:**

1. ¿Qué diferencia observas entre `Storage=volatile` y `Storage=persistent`?
2. ¿Para qué sirve `--list-boots`? ¿Cuántos boots aparecen?
3. ¿Por qué es útil exportar logs en formato JSON?

---

## Paso 6 — Hardening avanzado y score de seguridad (Perfil B)

### 6a. Medir score inicial

```bash
systemd-analyze security ctt-monitor.service
```

Anotar el score actual.

### 6b. Objetivo: score < 4.0

Comparar la salida de `systemd-analyze security` con las directivas ya configuradas. Identificar las 3 mejoras con mayor impacto y agregarlas a la unit file.

```bash
# Ver recomendaciones específicas
systemd-analyze security ctt-monitor.service 2>&1 | grep "✗"
```

### 6c. Iteración de mejora

```bash
sudo systemctl daemon-reload
sudo systemctl restart ctt-monitor.service

# Verificar funcionamiento
systemctl status ctt-monitor.service
journalctl -u ctt-monitor -n 5 --no-pager

# Medir score de nuevo
systemd-analyze security ctt-monitor.service
```

Repetir hasta alcanzar score < 4.0 sin que el servicio falle.

**Tabla de progreso a completar:**

| Iteración | Directivas agregadas | Score |
|-----------|---------------------|-------|
| Inicial (Lab 3 Paso 2) | NoNewPrivileges, PrivateTmp... | |
| Iteración 1 | | |
| Iteración 2 | | |
| Final | | < 4.0 |

---

## Verificación final del ecosistema

```bash
echo "=============================="
echo " VERIFICACIÓN FINAL — LAB 3"
echo "=============================="

echo ""
echo "--- Servicios CTT activos ---"
systemctl status ctt-monitor.service --no-pager | head -10

echo ""
echo "--- Timers activos ---"
systemctl list-timers ctt-backup.timer ctt-cleanup.timer

echo ""
echo "--- Espacio de journal ---"
journalctl --disk-usage

echo ""
echo "--- Score de seguridad ---"
systemd-analyze security ctt-monitor.service 2>/dev/null | \
    grep -E "^(Overall|→)" | head -3

echo ""
echo "--- Archivo de alertas ---"
cat /opt/ctt/logs/alertas.log 2>/dev/null || echo "(sin alertas registradas)"

echo ""
echo "=============================="
echo " FIN DE LA VERIFICACIÓN"
echo "=============================="
```

---

## Limpieza (al finalizar el laboratorio)

```bash
# Detener todo
sudo systemctl disable --now ctt-monitor.service
sudo systemctl disable --now ctt-backup.timer
sudo systemctl disable --now ctt-cleanup.timer

# Eliminar units
sudo rm -f /etc/systemd/system/ctt-monitor.service
sudo rm -f /etc/systemd/system/ctt-backup.service
sudo rm -f /etc/systemd/system/ctt-backup.timer
sudo rm -f /etc/systemd/system/ctt-cleanup.service
sudo rm -f /etc/systemd/system/ctt-cleanup.timer
sudo rm -f /etc/systemd/system/ctt-alert@.service

sudo systemctl daemon-reload
sudo systemctl reset-failed

# Opcional: eliminar usuario y directorio
sudo userdel ctt-svc
sudo rm -rf /opt/ctt

# Restaurar journald.conf (opcional)
sudo sed -i '/^Storage\|^Compress\|^SystemMax\|^MaxRet\|^Forward/d' \
    /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

---

## Entregables

```
labs/
├── LAB03_respuestas.md              ← Respuestas a todas las preguntas
├── ctt-monitor.service              ← Unit file final con hardening completo
├── ctt-backup.service               ← Unit file oneshot
├── ctt-backup.timer                 ← Timer de backup
├── ctt-cleanup.service              ← Unit file oneshot
├── ctt-cleanup.timer                ← Timer de limpieza
├── ctt-alert@.service               ← Servicio de alerta instanciado
├── LAB03_fallo_A.txt                ← Output journalctl — fallo A
├── LAB03_fallo_B.txt                ← Output journalctl — fallo B
├── LAB03_security_score_inicial.txt ← Output systemd-analyze security inicial
└── LAB03_security_score_final.txt   ← Output systemd-analyze security final
```

El archivo `LAB03_respuestas.md` debe incluir:

- [ ] Respuesta a todas las preguntas de análisis
- [ ] Tabla de iteraciones de hardening con scores
- [ ] Output de `systemctl list-timers` mostrando ambos timers activos
- [ ] Output de `journalctl --list-boots` mostrando persistencia
- [ ] Extracto de logs en formato JSON exportado con `journalctl -o json`
- [ ] Reflexión: ¿qué fue lo más difícil de balancear entre hardening y funcionalidad?

---

## Criterios de evaluación

| Criterio | Perfil A | Perfil B | Peso |
|----------|----------|----------|------|
| Ecosistema completo de 4 services + 2 timers | ✓ | ✓ | 25% |
| Diagnóstico documentado de 2 fallos con metodología de 5 pasos | ✓ | ✓ | 25% |
| journald persistente y logs exportados en JSON | ✓ | ✓ | 20% |
| Hardening con score < 6.0 (Perfil A) | ✓ | — | 15% |
| Hardening con score < 4.0 (Perfil B) | — | ✓ | 15% |
| `OnFailure=` funcionando y alertas registradas | — | ✓ | 15% |

---

## Resumen de conceptos integrados

| Concepto | Clase | Aplicado en |
|----------|-------|------------|
| PID 1, daemons, services | Clase 1 | Toda la práctica |
| systemctl, journalctl básico | Clase 1 | Gestión del ecosistema |
| Dependencias (`After`, `Wants`) | Clase 2 | unit files |
| Política de reinicio (`Restart=`) | Clase 2 | ctt-monitor.service |
| Timer units | Clase 2 | ctt-backup.timer, ctt-cleanup.timer |
| Límites de recursos (cgroups v2) | Clase 2 | `MemoryMax=`, `CPUQuota=` |
| `Type=simple` y `Type=oneshot` | Clase 3 | monitor vs backup/cleanup |
| Hooks (`ExecStartPre`, `ExecStopPost`) | Clase 3 | ctt-monitor.service |
| `journald.conf` y persistencia | Clase 3 | Paso 5 |
| Diagnóstico sistemático 5 pasos | Clase 3 | Paso 4 (fallos A y B) |
| `systemd-analyze security` | Clase 3 | Paso 6 |
| `OnFailure=` | Clase 3 | ctt-alert@.service |

---

## Recursos

- Clase 1: _Administración de Servicios en Linux_ — slides 5 a 12
- Clase 2: _Units Avanzadas, Diagnóstico de Fallos y Timers_ — slides 3 a 11
- Clase 3: _Journald Avanzado, Diagnóstico de Fallos y Cierre U1_ — slides 3 a 11
- `man systemd.service` — todas las directivas disponibles
- `man journald.conf` — configuración del journal
- `man systemd-analyze` — referencia de `security`, `verify`, `blame`
- Repositorio del curso: `https://github.com/ctt/linux3-labs`

---

*Linux III — Redes y Servicios POSIX · CTT · Año 2026*
