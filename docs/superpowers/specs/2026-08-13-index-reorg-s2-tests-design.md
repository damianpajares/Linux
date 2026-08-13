# Reorganización del index y pruebas interactivas de S2

**Fecha:** 2026-08-13
**Estado:** Aprobado

## Contexto

El repo es un sitio híbrido de materiales de clase (CTT · Técnico en Redes y Software) con tres módulos en carpetas `S1/`, `S2/` y `S3/`. `index.html` quedó desactualizado: asume una estructura de carpeta plana con archivos que ya no existen (la reorganización en subcarpetas se hizo en el working tree pero `index.html` nunca se actualizó).

Se relevaron las tres guías teórico-prácticas (`.docx`, extraídas a texto vía `zipfile`+regex sobre `word/document.xml` ya que no hay `python-docx` ni `pandoc` instalados) para inventariar contenido existente vs. planificado:

- **S1** (Principios GNU/Linux, línea de comandos POSIX, bash scripting básico): slides completas + `Practica_Redes_POSIX_BashScript.html` en la raíz (mal ubicado — su contenido de 5 módulos es 100% S1) + guía docx. Falta evaluación formal.
- **S2** (Comandos avanzados POSIX, SSH remoto, shell scripting/cron): solo slides + guía docx. Sin ninguna prueba interactiva.
- **S3** (systemd, servicios de red, Docker): slides completas + labs `.md` y evaluación (práctica + formal) solo para U1 (systemd). U2 (Apache/Samba/UFW) y U3 (Docker) sin labs ni evaluación.

El repo ya tiene dos patrones de prueba HTML autocontenida (CSS+JS inline, sin dependencias externas): una "práctica" autodiagnóstica sin datos personales, reintentable, con explicación al toque; y una "evaluación formal" que pide Nombre/Apellido/CI, penaliza errores, permite navegación libre y da un resumen final. Ambas comparten el mismo motor: array `PARTS[]` de bloques, cada uno con `questions[]` de objetos `{cat, q, type: "single"|"multi", pts, opts, correct, exp}`.

## Decisiones

1. **Mover** `Practica_Redes_POSIX_BashScript.html` → `S1/Practica_S1_Comandos_BashScripting.html` (coincide con el contenido real y la convención de nombres `S1_/S2_/S3_` del resto del repo).
2. **Reescribir `index.html`** agrupado por módulo (S1/S2/S3), y dentro de cada uno por tipo de recurso: diapositivas, guía teórico-práctica, práctica autodiagnóstica, evaluación formal, laboratorios. Se corrigen todas las rutas a la estructura real. El contenido que aún no existe (S1 eval. formal, S2 completo, S3 U2/U3) se muestra igual, como tarjeta atenuada con badge "próximamente" — el index documenta el roadmap de un vistazo.
3. **Roadmap de contenido** en un archivo nuevo `ROADMAP.md` en la raíz, con checkboxes markdown por módulo/unidad, para trackear qué falta a medida que se construye.
4. **Construir S2** reutilizando el motor de `S3/Evaluacion_Formal_Linux3_U1 (1).html`:
   - `S2/Practica_S2_RedesPOSIX_SSH_Scripting.html` — autodiagnóstica, bloques seleccionables U1 (comandos avanzados/procesos/systemctl/journalctl), U2 (SSH: claves, scp/sftp, hardening sshd_config), U3 (scripting: estructura, funciones, manejo de errores, crontab, logging).
   - `S2/Evaluacion_Formal_S2_RedesPOSIX.html` — Nombre/Apellido/CI, preguntas mezcladas de las 3 unidades, penalización, navegación libre, resumen final.
   - Escala: ~35-40 preguntas por unidad (~110 total), en línea con S1 (~35/módulo) y S3 (~100 en solo U1). Cada pregunta con `cat` (subtema) y `exp` (justificación técnica).
   - **Fuera de alcance en esta iteración:** labs `.md` para S2 (S3 sí los tiene para U1) — queda anotado en `ROADMAP.md` como pendiente futuro.

## Parte 4 — Contenido teórico faltante de S2 (agregado 2026-08-13)

Se cruzó el contenido de la guía contra lo que realmente cubren las clases existentes de S2 (`Linux2_Clase0_Nexo_CTT.pptx`, `Linux2_Clase1_...docx`, `Comillas_Salida_y_Pruebas_Linux1.pptx`, extraídos a texto con el mismo método zipfile+regex). Hallazgo: Clase0 es un resumen de las 16 semanas a nivel índice; Clase1 solo profundiza streams/redirecciones/pipes + intro de systemctl/journalctl; Comillas_Salida_y_Pruebas cubre bien quoting/tests pero es material previo, no una clase oficial de la secuencia. **No existe ninguna clase dedicada a U2 (SSH) ni a la parte central de U3 (scripting/cron)**, y U1 le falta cut/sort/uniq/find+xargs, gestión de procesos, diagnóstico de red y regex ERE.

Se agregan tres documentos Markdown en `S2/`, con el mismo formato de apunte que los `LAB0x.md` de S3 (teoría + tablas de comandos + ejercicios Perfil A/B + evaluación), nombrados por unidad:

- `S2/U1_Complemento_Filtros_Procesos.md`
- `S2/U2_SSH_Administracion_Remota.md`
- `S2/U3_ShellScripting_Automatizacion.md`

No duplican lo ya cubierto por Clase1 y Comillas_Salida_y_Pruebas, lo complementan. La conversión a `.pptx` con el estilo visual de las clases existentes queda para una iteración futura (anotada en `ROADMAP.md`).

## Fuera de alcance

- Construir el contenido faltante de S1 (evaluación formal) y S3 (U2/U3) — queda documentado en `ROADMAP.md` para una iteración futura, no se construye ahora.
- No se commitea nada automáticamente; los cambios quedan en el working tree para revisión del usuario, igual que el resto de la reorganización en curso (`git status` ya mostraba movimientos S1/S2/S3 sin commitear antes de empezar).
