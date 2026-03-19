# Laboratorio 1 — Exploración del Ecosistema systemd

> **Unidad:** U1 — Gestión de Servicios con systemd  
> **Clase de referencia:** Clase 1 — Administración de Servicios en Linux  
> **Semana:** 1–2 · **Duración estimada:** 40–50 min  
> **Perfil:** A y B  

---

## Objetivo

Transicionar de la teoría del PID 1 a la práctica en una terminal real. Al finalizar este laboratorio el estudiante será capaz de:

- Identificar y listar servicios activos en el sistema
- Analizar el ciclo de vida de un servicio con `systemctl status`
- Leer e interpretar un unit file con `systemctl cat`
- Filtrar logs centralizados con `journalctl`
- Medir el tiempo de arranque del sistema con `systemd-analyze`

---

## Prerequisitos

| Requisito | Verificación |
|-----------|-------------|
| Sistema Linux con systemd | `systemctl --version` |
| Usuario con `sudo` | `sudo whoami` → debe retornar `root` |
| Clase 1 completada | Conceptos: PID 1, daemon, servicio, unit file |

---

## Entorno

```
Sistema operativo : Ubuntu 24.04 LTS (o Debian 12)
Shell             : bash
Usuario de trabajo: alumno con sudo
Directorio        : /home/<usuario>
```

---

## Paso 1 — Verificar el PID 1

**Concepto:** systemd es el primer proceso del espacio de usuario. Su PID es siempre 1.

```bash
ps -p 1
```

**Salida esperada:**

```
  PID TTY      CMD
    1 ?        /lib/systemd/systemd
```

**Preguntas de análisis:**

1. ¿Qué proceso ocupa el PID 1 en tu sistema?
2. ¿Por qué el campo `TTY` muestra `?` en lugar de un terminal?
3. Si el PID 1 muere, ¿qué le sucede al sistema? (responder con justificación técnica)

---

## Paso 2 — Auditoría de servicios activos

**Concepto:** `systemctl list-units` muestra el estado de todas las units cargadas por systemd.

```bash
systemctl list-units --type=service --state=running
```

**Variantes a ejecutar:**

```bash
# Ver todos los servicios (activos, inactivos, fallidos)
systemctl list-units --type=service --all

# Ver solo los servicios que fallaron
systemctl list-units --type=service --state=failed

# Contar servicios activos
systemctl list-units --type=service --state=running | grep -c "running"
```

**Preguntas de análisis:**

1. ¿Cuántos servicios están corriendo activamente?
2. Identifica 3 servicios que sean parte del sistema base (no aplicaciones instaladas por el usuario). ¿Cómo los reconociste?
3. ¿Hay algún servicio en estado `failed`? Si es así, ¿cuál y por qué?

---

## Paso 3 — Análisis del ciclo de vida de un servicio

**Concepto:** `systemctl status` muestra el estado completo de un servicio: PID, cgroups, logs recientes y dependencias.

```bash
systemctl status ssh
```

> **Nota:** En algunos sistemas el servicio se llama `sshd`. Probar ambos si el primero falla.

```bash
# Alternativa
systemctl status sshd
```

**Identificar en la salida:**

| Campo a buscar | ¿Qué indica? |
|----------------|-------------|
| `Loaded:` | Si la unit file existe y está habilitada |
| `Active:` | Estado actual y tiempo en ese estado |
| `Main PID:` | PID del proceso principal |
| `CGroup:` | Árbol de cgroups y procesos hijos |
| `Tasks:` | Cantidad de hilos/procesos del servicio |

**Preguntas de análisis:**

1. ¿Cuánto tiempo lleva activo el servicio SSH?
2. ¿El servicio tiene procesos hijos? ¿Cuántos?
3. ¿Qué significa `enabled` en la línea `Loaded:`?

---

## Paso 4 — Ingeniería inversa del unit file

**Concepto:** `systemctl cat` muestra el unit file tal como systemd lo carga, incluyendo fragmentos de override.

```bash
systemctl cat ssh
```

**Analizar las secciones:**

```bash
# Extraer solo las dependencias
systemctl cat ssh | grep -E "^(After|Requires|Wants|Before)"

# Ver con qué usuario corre el servicio
systemctl cat ssh | grep -E "^User"
```

**Preguntas de análisis:**

1. ¿Qué directiva define el comando de inicio? ¿Cuál es el valor?
2. ¿Qué targets o servicios debe iniciar ANTES que SSH? (`After=`)
3. ¿Tiene política de reinicio configurada (`Restart=`)? ¿Cuál?
4. ¿Tiene alguna directiva de hardening? ¿Cuál?

---

## Paso 5 — Auditoría de logs centralizados

**Concepto:** `journalctl` es la interfaz para el journal de systemd. Todos los logs de servicios pasan por journald.

```bash
# Últimas 20 líneas del servicio SSH
journalctl -u ssh -n 20 --no-pager
```

**Variantes a ejecutar:**

```bash
# Solo errores de SSH
journalctl -u ssh -p err --no-pager

# Logs del boot actual
journalctl -u ssh -b --no-pager

# Logs en tiempo real (Ctrl+C para salir)
journalctl -u ssh -f
```

**Preguntas de análisis:**

1. ¿Cuántas conexiones SSH se registraron en los últimos logs?
2. ¿Hay intentos fallidos de autenticación? ¿Cómo los identificaste?
3. ¿Qué diferencia hay entre los logs con prioridad `info` y los de prioridad `err`?

---

## Paso 6 — Profiling del arranque

**Concepto:** `systemd-analyze` mide el tiempo de cada fase del arranque y permite identificar cuellos de botella.

```bash
# Tiempo total de arranque
systemd-analyze

# Ranking de servicios por tiempo de inicio
systemd-analyze blame
```

**Variantes a ejecutar:**

```bash
# Cadena crítica (ruta más larga del grafo de dependencias)
systemd-analyze critical-chain

# Ver los 5 servicios más lentos
systemd-analyze blame | head -5
```

**Preguntas de análisis:**

1. ¿Cuánto tiempo tardó el sistema en arrancar en total? (kernel + initrd + userspace)
2. ¿Cuál es el servicio que más tiempo consume al iniciar? ¿Tiene sentido que tarde ese tiempo?
3. ¿Qué servicio aparece en la cadena crítica (`critical-chain`)? ¿Por qué es "crítico"?

---

## Actividad de Cierre — Mapa de Servicios

Completar la siguiente tabla con los servicios observados en el sistema:

| Nombre del servicio | Función | Estado | Tiempo de arranque |
|--------------------|---------|--------|-------------------|
| `ssh.service` | Acceso remoto SSH | | |
| | | | |
| | | | |
| | | | |
| | | | |

**Instrucciones:**
1. Identificar al menos 5 servicios activos en el sistema
2. Clasificarlos por función: red, seguridad, logging, base del sistema, aplicación
3. Indicar cuál podría deshabilitarse en un servidor de producción (sin romper el sistema)

---

## Entregables

```
labs/
└── LAB01_respuestas.md   ← Archivo con respuestas a todas las preguntas
```

El archivo de respuestas debe incluir:

- [ ] Respuestas a las preguntas de cada paso (justificadas)
- [ ] Tabla de mapa de servicios completada
- [ ] Captura de texto (copy/paste) de la salida de `systemd-analyze blame`
- [ ] Captura de texto de `systemctl status ssh`

---

## Criterios de evaluación

| Criterio | Peso |
|----------|------|
| Identificación correcta de servicios y sus funciones | 25% |
| Análisis del unit file con al menos 3 directivas explicadas | 25% |
| Lectura e interpretación de logs con journalctl | 25% |
| Análisis de tiempos de arranque con argumento técnico | 25% |

---

## Referencia rápida — Comandos del laboratorio

```bash
# Listar servicios activos
systemctl list-units --type=service --state=running

# Estado detallado de un servicio
systemctl status <nombre>.service

# Ver el unit file completo
systemctl cat <nombre>.service

# Logs de un servicio
journalctl -u <nombre> -n 20 --no-pager

# Tiempo de arranque
systemd-analyze blame
```

---

## Recursos

- Clase 1: _Administración de Servicios en Linux_ — slides 3 a 10
- `man systemctl` — documentación completa de systemctl
- `man journalctl` — documentación completa de journalctl
- `man systemd.service` — referencia de directivas del unit file

---

*Linux III — Redes y Servicios POSIX · CTT · Año 2026*
