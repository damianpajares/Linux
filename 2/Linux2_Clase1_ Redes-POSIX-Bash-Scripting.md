# [cite_start]Documento Técnico: Clase Introductoria - Redes POSIX & Shell Scripting [cite: 1]
## [cite_start]Módulo II - Técnico en Redes y Software (CETP-UTU · CTT) [cite: 2]
### [cite_start]Unidad 1: Comandos Avanzados y Administración POSIX [cite: 3]

---

## [cite_start]1. Introducción al Curso [cite: 4]
[cite_start]El objetivo fundamental de este módulo es realizar la transición de "usuario de Linux" a "Administrador de Sistemas (Sysadmin)"[cite: 5]. 

* [cite_start]La filosofía de los sistemas POSIX (como GNU/Linux) se basa en herramientas pequeñas que hacen una sola cosa muy bien[cite: 6]. 
* [cite_start]El verdadero poder surge cuando aprendemos a encadenar estas herramientas para automatizar tareas[cite: 7]. 
* [cite_start]Como reza el lema del curso: *"Un sysadmin que no sabe scripting pierde horas haciendo a mano lo que un script hace en segundos."* [cite: 8]

---

## [cite_start]2. Los Tres Flujos Estándar (Standard Streams) [cite: 9]
[cite_start]En la arquitectura POSIX, **todo es un archivo**, incluyendo los dispositivos de entrada y salida[cite: 10]. [cite_start]Cuando un proceso se ejecuta en la terminal, el sistema operativo le asigna automáticamente tres flujos de datos básicos, identificados por un número llamado "Descriptor de Archivo" (File Descriptor o FD)[cite: 11].



### [cite_start]Tabla de Descriptores [cite: 12]
| Descriptor | Nombre Técnico | Abreviatura | Propósito | Dispositivo por Defecto |
| :--- | :--- | :--- | :--- | :--- |
| **0** | Standard Input | `stdin` | Por donde el comando recibe datos. | Teclado |
| **1** | Standard Output | `stdout` | Por donde el comando envía su resultado exitoso. | Pantalla (Terminal) |
| **2** | Standard Error | `stderr` | Por donde el comando envía los mensajes de error. | Pantalla (Terminal) |

---

## [cite_start]3. Redirecciones: Controlando el Flujo [cite: 13]
[cite_start]Las redirecciones nos permiten cambiar el origen (`stdin`) o el destino (`stdout`/`stderr`) de los flujos de un comando usando operadores específicos en la shell (Bash)[cite: 14].

### [cite_start]3.1 Redirección de Salida (`stdout`) [cite: 15]
* [cite_start]**`>` (Sobrescribir):** Redirige la salida estándar a un archivo[cite: 16]. [cite_start]Si el archivo no existe, lo crea[cite: 16]. [cite_start]Si existe, borra su contenido previo[cite: 17].
  * [cite_start]*Ejemplo 1:* `echo "Reporte del sistema" > reporte.txt` [cite: 17]
  * [cite_start]*Ejemplo 2:* `ls -l /etc > lista_etc.txt` [cite: 17]
* [cite_start]**`>>` (Añadir / Append):** Redirige la salida estándar a un archivo, pero añade el texto al final del mismo sin borrar el contenido anterior[cite: 18].
  * [cite_start]*Ejemplo:* `echo "Nueva línea de log" >> /var/log/mis_logs.txt` [cite: 19]

### [cite_start]3.2 Redirección de Entrada (`stdin`) [cite: 20]
* [cite_start]**`<` (Entrada desde archivo):** Pasa el contenido de un archivo como entrada estándar a un comando[cite: 21].
  * [cite_start]*Ejemplo:* `wc -l < lista.txt` *(Cuenta las líneas del archivo directamente)* [cite: 22]

### [cite_start]3.3 Redirección de Errores (`stderr`) [cite: 23]
[cite_start]A menudo, al ejecutar comandos como administrador o realizar búsquedas globales, obtendremos errores de "Permiso denegado"[cite: 24]. [cite_start]Podemos separar estos errores del resultado útil[cite: 25].
* [cite_start]**`2>` (Redirigir solo errores):** * *Ejemplo:* `find / -name "passwd" 2> errores.log` [cite: 26]
* [cite_start]**El "Agujero Negro" (`/dev/null`):** Es un dispositivo virtual que descarta instantáneamente todo lo que se le envía[cite: 27]. [cite_start]Ideal para ocultar errores molestos[cite: 28].
  * [cite_start]*Ejemplo:* `find / -name "archivo_secreto" 2> /dev/null` [cite: 28]

### [cite_start]3.4 Redirecciones Combinadas [cite: 29]
* [cite_start]**`&>` (Redirigir TODO):** Envía tanto `stdout` como `stderr` al mismo archivo[cite: 30].
  * [cite_start]*Ejemplo:* `ping -c 4 8.8.8.8 &> resultado_ping.txt` [cite: 30]
* [cite_start]**`2>&1` (Anidación clásica):** Redirige el flujo 2 (errores) hacia donde esté apuntando actualmente el flujo 1 (salida)[cite: 31].
  * [cite_start]*Ejemplo:* `comando_respaldo > backup.log 2>&1` [cite: 32]

---

## [cite_start]4. Tuberías (Pipes `|`): La Navaja Suiza [cite: 33]
[cite_start]El operador pipe `|` toma la salida estándar (`stdout`) del comando a su izquierda y la inyecta directamente como entrada estándar (`stdin`) del comando a su derecha[cite: 34]. [cite_start]Esto permite construir "tuberías de procesamiento de datos"[cite: 35].



* [cite_start]**Ejemplo 1: Paginación simple** [cite: 36]
  * [cite_start]`ls -la /etc | less` [cite: 37]
* [cite_start]**Ejemplo 2: Extracción y conteo** [cite: 38]
  * [cite_start]*¿Cuántos procesos hay corriendo actualmente en el sistema?* [cite: 39]
  * [cite_start]`ps aux | wc -l` [cite: 40]
* [cite_start]**Ejemplo 3: Cadena de procesamiento avanzada (Filtros)** [cite: 41]
  * [cite_start]*Listar las 5 direcciones IP únicas que más veces han intentado conectarse por SSH:* [cite: 42]
  * [cite_start]`tail -1000 /var/log/auth.log | grep 'Accepted' | awk '{print $11}' | sort | uniq -c | sort -rn | head -5` [cite: 43, 44]
  * [cite_start]*(Esta es la base de la Unidad 3: automatizar este tipo de análisis)*[cite: 45].

---

## [cite_start]5. Gestión Moderna de Servicios (Systemd) [cite: 46]
[cite_start]En distribuciones GNU/Linux modernas (Ubuntu, Debian, RHEL), el sistema de inicio y gestión de servicios se llama `systemd`[cite: 47]. [cite_start]Su comando principal es `systemctl`[cite: 48].

### [cite_start]5.1 Comandos Fundamentales de systemctl [cite: 49]
* [cite_start]`systemctl status <servicio>`: Muestra el estado actual, PID y últimos logs del servicio[cite: 50].
* [cite_start]`systemctl start <servicio>`: Inicia el servicio[cite: 51].
* [cite_start]`systemctl stop <servicio>`: Detiene el servicio[cite: 52].
* [cite_start]`systemctl restart <servicio>`: Reinicia el servicio (corta conexiones activas)[cite: 53].
* [cite_start]`systemctl reload <servicio>`: Recarga la configuración sin detener el servicio (ideal para servidores web o SSH)[cite: 54].
* [cite_start]`systemctl enable <servicio>`: Configura el servicio para que inicie automáticamente al arrancar el sistema operativo[cite: 55].

### [cite_start]5.2 Lectura de Logs con journalctl [cite: 56]
[cite_start]Systemd centraliza los registros del sistema en el "Journal"[cite: 57].
* [cite_start]`journalctl -u ssh`: Muestra solo los logs del servicio SSH[cite: 58].
* [cite_start]`journalctl -f`: Modo *follow*, muestra los logs en tiempo real (similar a `tail -f`)[cite: 59].
* [cite_start]`journalctl --since "1 hour ago"`: Muestra los eventos de la última hora[cite: 60].

---

## [cite_start]6. Glosario Técnico [cite: 61]
* [cite_start]**Bash (Bourne Again SHell):** El intérprete de comandos por defecto en la mayoría de las distribuciones Linux[cite: 62]. [cite_start]Es el programa que lee los comandos que escribes y los ejecuta[cite: 63].
* [cite_start]**Daemon (Demonio):** Un programa de computadora que se ejecuta en segundo plano (background) en lugar de estar bajo el control directo de un usuario[cite: 64]. [cite_start]En Linux, sus nombres suelen terminar en 'd' (ej. sshd, systemd)[cite: 65].
* [cite_start]**Descriptor de Archivo (FD):** Un número entero abstracto que el sistema operativo utiliza para identificar de forma unívoca un archivo abierto o un flujo de datos (como la pantalla o el teclado)[cite: 66].
* [cite_start]**Hardening (Securización):** El proceso de asegurar un sistema reduciendo sus vulnerabilidades[cite: 67]. [cite_start]En este curso, se aplicará fuertemente en las configuraciones de SSH[cite: 68].
* [cite_start]**PID (Process ID):** Un número de identificación único asignado por el sistema operativo a cada proceso en ejecución[cite: 69].
* [cite_start]**Pipe (Tubería):** Mecanismo de comunicación entre procesos (IPC) que permite que la salida de un programa se convierta directamente en la entrada de otro, usando el carácter `|`[cite: 70].
* [cite_start]**POSIX (Portable Operating System Interface):** Una familia de estándares especificados por la IEEE para mantener la compatibilidad entre sistemas operativos (como Unix, Linux, macOS)[cite: 71]. [cite_start]Define cómo deben comportarse las shells, utilidades y APIs[cite: 72].
* [cite_start]**Shebang (`#!/usr/bin/env bash`):** La primera línea de un script que le indica al sistema operativo qué intérprete debe usar para ejecutar el resto del archivo[cite: 73].
* [cite_start]**Shell:** Interfaz de usuario que permite el acceso a los servicios del sistema operativo[cite: 74]. [cite_start]Puede ser gráfica (GUI) o de línea de comandos (CLI), como Bash[cite: 75].
* [cite_start]**Sysadmin (System Administrator):** Profesional responsable de la configuración, mantenimiento y operación confiable de sistemas informáticos, especialmente servidores[cite: 76].

---

## Laboratorio Práctico (Ejercicios Pedagógicos)

**Laboratorio 1: Comprendiendo las redirecciones**
1. Ejecuta el comando `echo "Hola Mundo"` y observa cómo la salida estándar (`stdout`) va por defecto a tu pantalla.
2. Ahora, redirige esa salida hacia un archivo: `echo "Iniciando mi bitácora" > bitacora.txt`.
3. Agrega una nueva línea sin borrar la anterior usando el operador de "append": `echo "Revisando el sistema" >> bitacora.txt`.
4. Verifica el contenido final del archivo usando el comando `cat bitacora.txt`.

**Laboratorio 2: Limpieza de Errores (`stderr`)**
1. Ejecuta el comando `find / -name "syslog"`. Notarás muchos mensajes de error que ensucian tu pantalla.
2. Modifica el comando enviando el flujo de error (FD 2) al agujero negro de Linux: `find / -name "syslog" 2> /dev/null`. Analiza cómo ahora solo visualizas los resultados exitosos.

**Laboratorio 3: Tuberías en Acción**
1. Imprime todos los procesos de tu sistema ejecutando `ps aux`. La pantalla se llenará de texto rápidamente.
2. Utiliza un *pipe* para controlar la salida: `ps aux | less`. Usa las flechas para navegar y la letra `q` para salir.
3. Ahora, filtra esa salida para ver solo los procesos relacionados con el usuario 'root': `ps aux | grep root`.

**Laboratorio 4: Administración de Servicios**
1. Verifica si el servicio de red está activo en tu sistema: `systemctl status NetworkManager` (o `networking` dependiendo de tu distribución).
2. Lee los últimos eventos de dicho servicio utilizando `journalctl -u NetworkManager --since "10 minutes ago"`.