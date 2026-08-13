# U2 — SSH y Administración Remota

> **Programa:** Técnico en Redes y Software · CETP-UTU · CTT
> **Módulo:** Redes POSIX — SHSCRIPT (S2)
> **Unidad:** U2 — SSH y Administración Remota (Semanas 6–11 · ~18 hs)
> **Relación con el resto del material:** `Linux2_Clase0_Nexo_CTT.pptx` solo trae una diapositiva de resumen con la lista de comandos y directivas de hardening. Este documento es la clase completa de U2: no existía ningún material que desarrollara la teoría, así que arranca de cero.

---

## Objetivos

Al finalizar esta unidad el estudiante será capaz de:

- Explicar cómo funciona la autenticación por clave pública/privada en SSH
- Generar pares de claves, instalarlas en un servidor remoto y conectarse sin contraseña
- Transferir archivos de forma segura con `scp` y `sftp`
- Aplicar hardening a `sshd_config` con criterio técnico (no solo copiar valores)
- Configurar túneles SSH (port forwarding) y saltos a través de un bastion host (`ProxyJump`)
- Diagnosticar y monitorear conexiones SSH activas y fallidas

---

## Prerequisitos

| Requisito | Verificación |
|-----------|-------------|
| U1 completa: procesos, systemctl, journalctl | `systemctl status ssh` te resulta familiar |
| Dos máquinas (VMs o contenedores) en la misma red | `ping` entre ambas funciona |
| Acceso `sudo` en ambas | `sudo whoami` → `root` |

---

## 2.1 — Cómo funciona SSH

### Marco teórico — criptografía asimétrica aplicada

SSH (Secure Shell) reemplaza a Telnet/rlogin cifrando todo el tráfico entre cliente y servidor. Su autenticación más segura no usa contraseñas: usa un **par de claves asimétricas**.

- **Clave privada** (`id_ed25519`): se queda en tu máquina, nunca se comparte, se protege con una passphrase opcional.
- **Clave pública** (`id_ed25519.pub`): se copia al servidor. No sirve para descifrar nada — solo para verificar que quien responde tiene la privada correspondiente.

**Flujo de autenticación por clave (simplificado):**

1. El cliente le dice al servidor: "quiero entrar como `alumno`, esta es mi clave pública"
2. El servidor busca esa clave pública en `~/.ssh/authorized_keys` del usuario `alumno`
3. Si la encuentra, genera un **desafío** (un valor aleatorio cifrado con esa clave pública)
4. Solo quien tiene la clave **privada** correspondiente puede descifrar el desafío y responder correctamente
5. El cliente responde → el servidor verifica → acceso concedido, **sin que la contraseña viaje jamás por la red**

Esto es fundamentalmente distinto de la autenticación por contraseña: en un login por clave, la clave privada nunca sale de tu máquina. Un atacante que intercepte el tráfico no obtiene nada reutilizable.

```
┌─────────┐   1. "soy alumno, esta es mi pública"   ┌──────────┐
│ Cliente │ ───────────────────────────────────────▶│ Servidor │
│(privada)│                                          │(pública) │
│         │◀─────────────────────────────────────── │          │
└─────────┘   2. desafío cifrado con la pública      └──────────┘
     │
     │ 3. descifra con la privada, responde
     ▼
  acceso concedido
```

---

## 2.2 — Generar y desplegar claves

### Marco teórico

| Comando | Ejemplo | Descripción |
|---|---|---|
| `ssh-keygen` | `ssh-keygen -t ed25519 -C 'ctt@alumno'` | Genera el par de claves. `-t ed25519` es el algoritmo recomendado (más rápido y seguro que RSA para uso moderno). `-C` es un comentario identificador |
| `ssh-copy-id` | `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@servidor` | Copia la clave pública al servidor, agregándola a `~/.ssh/authorized_keys` (pide contraseña la última vez) |
| `ssh` | `ssh usuario@192.168.1.10` | Conecta al servidor |
| `ssh -p` | `ssh -p 2222 admin@servidor` | Conecta usando un puerto no estándar |
| `ssh -i` | `ssh -i ~/.ssh/id_ctt user@servidor` | Usa una clave específica en vez de la default |
| `ssh -v` | `ssh -v user@servidor` | Modo verboso — imprime cada paso de la negociación, clave para diagnosticar fallos |

**Por qué Ed25519 y no RSA:** Ed25519 genera claves más cortas con el mismo (o mayor) nivel de seguridad, es más rápido de calcular y no depende de un buen generador de números aleatorios tanto como RSA. RSA sigue siendo válido (usar mínimo 3072 bits si se elige), pero Ed25519 es el estándar recomendado hoy.

**Permisos obligatorios** (SSH rechaza la clave si son laxos):

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519          # privada: solo el dueño lee/escribe
chmod 644 ~/.ssh/id_ed25519.pub      # pública: puede ser legible por todos
chmod 600 ~/.ssh/authorized_keys     # en el servidor
```

```bash
# Flujo completo, de punta a punta
ssh-keygen -t ed25519 -C 'ctt@alumno'                    # genera el par (Enter para ubicación/passphrase default)
ssh-copy-id alumno@192.168.1.20                            # copia la pública (pide contraseña, última vez)
ssh alumno@192.168.1.20                                    # ¿entró sin pedir contraseña?
```

### PERFIL A — sin conocimientos previos

Laboratorio guiado VM a VM:

1. VM1 (cliente) y VM2 (servidor) en la misma red Host-Only
2. En VM1: `ssh-keygen -t ed25519` — aceptar la ubicación y nombre por defecto
3. `ssh-copy-id alumno@IP_VM2` (con contraseña, por última vez)
4. Verificar: `ssh alumno@IP_VM2` — ¿entró sin pedir contraseña?
5. Si falla, diagnosticar con `ssh -v alumno@IP_VM2` y leer los mensajes

### PERFIL B — con conocimientos previos

1. Generar un par de claves específico para este curso (no el default): `ssh-keygen -t ed25519 -f ~/.ssh/id_ctt -C 'ctt@lab'`
2. Configurar un alias de conexión en `~/.ssh/config`:
   ```
   Host ctt
       HostName 192.168.1.20
       User alumno
       Port 2222
       IdentityFile ~/.ssh/id_ctt
   ```
3. Conectar simplemente con `ssh ctt` — explicar qué resuelve tener este archivo
4. Investigar: ¿qué pasa si `authorized_keys` tiene permisos `644` en vez de `600`? Probar y explicar el mensaje de error

---

## 2.3 — Transferencia de archivos: `scp` y `sftp`

| Comando | Ejemplo | Descripción |
|---|---|---|
| `scp` | `scp archivo.txt user@srv:/tmp/` | Copia un archivo local al servidor |
| `scp` (bajar) | `scp user@srv:/etc/hostname .` | Copia un archivo del servidor al directorio actual |
| `scp -r` | `scp -r /proyectos/ user@srv:/backup/` | Copia un directorio completo, recursivo |
| `scp -P` | `scp -P 2222 archivo.txt user@srv:/tmp/` | Puerto no estándar (ojo: `-P` mayúscula en `scp`, `-p` minúscula en `ssh`) |
| `sftp` | `sftp user@servidor` | Abre sesión interactiva |
| *(dentro de sftp)* | `ls`, `cd`, `pwd`, `get archivo`, `put archivo`, `mget *.txt`, `exit` | Navegación y transferencia interactiva |

`scp` es rápido para transferencias puntuales desde la línea de comandos. `sftp` es mejor cuando hay que explorar el sistema de archivos remoto antes de decidir qué transferir, o mover varios archivos con patrones.

```bash
scp /home/alumno/reporte.txt alumno@192.168.1.20:/tmp/
scp -r ./proyecto/ alumno@192.168.1.20:/home/alumno/backup/

sftp alumno@192.168.1.20
sftp> ls
sftp> get /etc/os-release
sftp> put script.sh /home/alumno/
sftp> exit
```

### PERFIL A — sin conocimientos previos

1. Copiar `/etc/hostname` de VM2 a `/tmp/` de VM1: `scp alumno@IP_VM2:/etc/hostname /tmp/`
2. Abrir `sftp alumno@IP_VM2` → `ls`, `get /etc/os-release`, `exit`

### PERFIL B — con conocimientos previos

1. Copiar un directorio completo recursivamente y medir el tiempo con `time scp -r ...`
2. Investigar `rsync -avz -e ssh` como alternativa a `scp` para sincronización incremental — ¿qué ventaja tiene sobre copiar todo de nuevo?

---

## 2.4 — Hardening de `sshd_config`

### Marco teórico

Cada directiva de `/etc/ssh/sshd_config` controla un aspecto de seguridad del servidor. La configuración por defecto es funcional pero no está optimizada para producción.

| Directiva | Valor recomendado | Por qué |
|---|---|---|
| `Port` | `2222` (no `22`) | Evita el 99% de los bots que escanean solo el puerto 22 — no es seguridad real, es reducción de ruido |
| `PermitRootLogin` | `no` | Nunca exponer root directo — se administra con `sudo` desde un usuario normal |
| `PasswordAuthentication` | `no` | Solo claves — las contraseñas son vulnerables a fuerza bruta y phishing |
| `PubkeyAuthentication` | `yes` | Confirmar explícitamente que la autenticación por clave está activa |
| `MaxAuthTries` | `3` | Limita intentos de autenticación por conexión |
| `AllowUsers` | `admin alumno1` | Whitelist explícita — solo estos usuarios pueden conectar, aunque tengan cuenta en el sistema |
| `LoginGraceTime` | `30` | Segundos para completar el login antes de desconectar la sesión |
| `Banner` | `/etc/ssh/banner.txt` | Muestra un aviso legal antes del login |
| `ClientAliveInterval` | `300` | Detecta y desconecta clientes inactivos (300s = 5 min) |
| `X11Forwarding` | `no` | Deshabilitar si no se usa GUI remota — reduce superficie de ataque |

**Procedimiento obligatorio después de cualquier cambio:**

```bash
sudo sshd -t                     # Test de sintaxis — SIEMPRE antes de reiniciar
sudo systemctl restart ssh       # Aplica los cambios
```

> ⚠️ **Crítico:** mantené una sesión SSH abierta mientras reiniciás el servicio. Si la nueva configuración tiene un error que te bloquea, esa sesión sigue viva y podés revertir el cambio. Cerrar la única sesión antes de confirmar que el acceso sigue funcionando puede dejarte fuera del servidor.

### PERFIL A — sin conocimientos previos

1. Abrir `/etc/ssh/sshd_config` con `sudo nano` y ubicar cada una de las 10 directivas de la tabla
2. Cambiar `PermitRootLogin` a `no` y `PasswordAuthentication` a `no`
3. `sudo sshd -t` antes de reiniciar — ¿qué pasa si hay un error de sintaxis?
4. `sudo systemctl restart ssh` — verificar que la conexión por clave sigue funcionando **antes de cerrar la sesión actual**

### PERFIL B — con conocimientos previos

Laboratorio completo — servidor SSH securizado desde cero (90 min):

1. Instalar Ubuntu Server (sin GUI) en una VM nueva — tomar snapshot `base-install`
2. Configurar IP estática (`ip addr`, editar `/etc/netplan/00-installer-config.yaml`)
3. Crear usuario `admin` con `sudo`, sin contraseña habilitada para login remoto
4. Desde el cliente: generar par de claves ed25519 y copiarlas con `ssh-copy-id`
5. Editar `sshd_config` con **todas** las directivas de hardening de la tabla
6. `sudo sshd -t` para verificar sintaxis antes de aplicar
7. Reiniciar SSH — verificar que la conexión por clave funciona
8. Intentar conectar como `root` — verificar que está bloqueado
9. Instalar `fail2ban` (ver 2.6) y verificar que está activo
10. Documentar la configuración final y tomar snapshot `ssh-securizado`

---

## 2.5 — Túneles SSH y `ProxyJump`

### Marco teórico

SSH no solo sirve para abrir una terminal remota: puede reenviar tráfico de red arbitrario a través del canal cifrado.

| Comando | Ejemplo | Descripción |
|---|---|---|
| `ssh -L` (local forward) | `ssh -L 8080:localhost:80 user@srv` | El puerto 8080 de tu máquina reenvía al puerto 80 del servidor remoto |
| `ssh -R` (remote forward) | `ssh -R 9000:localhost:3000 user@srv` | El puerto 9000 del servidor reenvía a tu máquina local |
| `ssh -D` (dynamic/SOCKS) | `ssh -D 1080 user@srv` | Crea un proxy SOCKS — todo el tráfico configurado sale cifrado a través del servidor |
| `ssh -J` (`ProxyJump`) | `ssh -J bastion user@servidor_interno` | Salta a través de un bastion host para llegar a un servidor sin IP pública |

`ProxyJump` es el reemplazo moderno de `ProxyCommand` con `netcat`. Se usa mucho en redes corporativas donde solo un "bastion host" tiene acceso directo desde internet, y desde ahí se salta a los servidores internos.

```bash
# Acceder al puerto 80 de un servidor remoto vía localhost:8080
ssh -L 8080:localhost:80 alumno@192.168.1.20
# En el navegador local: http://localhost:8080

# Saltar a través de un bastion para llegar a un servidor sin IP pública
ssh -J admin@bastion.ctt.edu.uy alumno@10.0.0.5
```

### PERFIL A — sin conocimientos previos

1. Levantar un servidor web simple en VM2: `python3 -m http.server 80` (o usar Apache/Nginx si ya está instalado)
2. Desde VM1: `ssh -L 8080:localhost:80 alumno@IP_VM2`
3. Abrir `http://localhost:8080` en el navegador de VM1 — ¿qué se ve?

### PERFIL B — con conocimientos previos

1. Configurar `ProxyJump` en `~/.ssh/config` para no tener que escribir `-J` cada vez:
   ```
   Host interno
       HostName 10.0.0.5
       User alumno
       ProxyJump admin@bastion.ctt.edu.uy
   ```
2. Explicar la diferencia entre `-L`, `-R` y `-D` con un caso de uso real para cada uno

---

## 2.6 — `ssh-agent`, monitoreo y `fail2ban`

### Marco teórico

`ssh-agent` mantiene tu clave privada descifrada en memoria durante la sesión, para no tener que escribir la passphrase en cada conexión.

```bash
eval "$(ssh-agent -s)"        # inicia el agente
ssh-add ~/.ssh/id_ed25519     # carga la clave (pide la passphrase una sola vez)
ssh-add -l                    # lista las claves cargadas
```

**Monitoreo de conexiones SSH activas y fallidas:**

```bash
who                                          # sesiones activas en el sistema
ss -tnp | grep :22                           # conexiones TCP activas al puerto SSH
journalctl -f -u ssh | grep -E 'Failed|Accepted'   # log en tiempo real de intentos
```

**`fail2ban`** monitorea los logs de autenticación y banea temporalmente (con reglas de firewall) las IPs que superan un número de intentos fallidos — mitiga ataques de fuerza bruta sin depender solo de `MaxAuthTries`.

```bash
sudo apt install fail2ban
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
sudo fail2ban-client status sshd            # ver IPs baneadas actualmente
```

### PERFIL A — sin conocimientos previos

1. `who` — ver quién está conectado ahora mismo
2. Monitorear en vivo: `sudo journalctl -f -u ssh` mientras alguien intenta conectarse desde otra terminal

### PERFIL B — con conocimientos previos

1. Instalar y activar `fail2ban`, verificar `fail2ban-client status sshd`
2. Provocar 4 intentos fallidos desde otra máquina (contraseña incorrecta) y verificar que la IP queda baneada
3. Configurar `ssh-agent` para que se inicie automáticamente en cada sesión de shell (agregar a `~/.bashrc`)

---

## 🧪 Laboratorio Práctico Final — Servidor SSH securizado (90 min)

1. VM1 (cliente) y VM2 (servidor) en red Host-Only, IP estática configurada en VM2
2. Generar claves ed25519 en VM1, copiarlas a VM2 con `ssh-copy-id`
3. Verificar login sin contraseña
4. Aplicar **todas** las directivas de hardening de la sección 2.4 a `sshd_config`
5. `sshd -t` → `systemctl restart ssh` → verificar acceso sin cerrar la sesión activa
6. Confirmar que el login como `root` está bloqueado y que el puerto cambió
7. Instalar y activar `fail2ban`
8. Transferir un archivo con `scp` y explorar el filesystem remoto con `sftp`
9. Configurar un túnel local (`-L`) hacia un servicio corriendo en VM2
10. Documentar todo en `~/ssh_hardening_informe.md` y tomar snapshot final `ssh-securizado`

---

## 📋 Evaluación

| Instrumento Perfil A | Instrumento Perfil B |
|---|---|
| Identificar las 5 configuraciones incorrectas en un `sshd_config` dado | Implementar el escenario completo: servidor SSH securizado con `fail2ban` y monitoreo |
| Describir paso a paso cómo configurar acceso por clave SSH | Análisis de logs: identificar un ataque de diccionario SSH y proponer mitigación adicional a `fail2ban` |
| Explicar la diferencia entre clave pública y privada sin tecnicismos | Configurar `ProxyJump` funcional entre 3 máquinas (cliente → bastion → servidor interno) |

**Criterios de evaluación**

| Criterio | Peso |
|---|---|
| Configuración correcta de claves SSH (generación, copia, permisos) | 30% |
| Hardening de `sshd_config` con justificación técnica de cada directiva | 30% |
| SCP/SFTP funcional entre VMs | 20% |
| Documentación técnica y snapshot del servidor | 20% |

---

## Referencia rápida

```bash
ssh-keygen -t ed25519 -C 'comentario'                 # genera el par de claves
ssh-copy-id user@host                                  # instala la pública en el servidor
ssh -i ~/.ssh/id_ctt -p 2222 user@host                 # conecta con clave y puerto específicos
scp archivo.txt user@host:/ruta/                        # copia archivo al servidor
sftp user@host                                          # sesión interactiva de transferencia
sudo sshd -t && sudo systemctl restart ssh              # validar y aplicar cambios de config
ssh -L 8080:localhost:80 user@host                      # túnel local
ssh -J bastion user@servidor_interno                     # salto vía bastion host
sudo fail2ban-client status sshd                         # IPs baneadas por fuerza bruta
```

---

*Linux II — Redes POSIX SHSCRIPT · CTT · Año 2026.*
