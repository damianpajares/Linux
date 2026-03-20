# Linux III — Laboratorios U1: Gestión de Servicios con systemd

> **Programa:** Técnico en Redes y Software · CETP-UTU · CTT  
> **Módulo:** Redes POSIX — Servicios · Año 2026  
> **Unidad:** U1 — Gestión de Servicios con systemd (Semanas 1–5)  

---

## Estructura del repositorio

```
linux3-labs/
└── u1-systemd/
    ├── README.md                          ← Este archivo
    ├── LAB01_Exploracion_systemd.md       ← Laboratorio 1 (Clase 1)
    ├── LAB02_Unit_Fallos_Hardening.md     ← Laboratorio 2 (Clase 2)
    └── LAB03_Practica_Integradora_U1.md   ← Laboratorio 3 (Clase 3)
```

---

## Descripción de los laboratorios

| Lab | Clase | Tema principal | Duración | Perfil |
|-----|-------|----------------|----------|--------|
| [LAB01](./LAB01_Exploracion_systemd.md) | Clase 1 | Exploración del ecosistema systemd | 40–50 min | A y B |
| [LAB02](./LAB02_Unit_Fallos_Hardening.md) | Clase 2 | Unit file, fallos y hardening | 50–60 min | A (p.1–4) · B (p.1–6) |
| [LAB03](./LAB03_Practica_Integradora_U1.md) | Clase 3 | Práctica integradora U1 | 60 min | A (p.1–4) · B (p.1–6) |

---

## Prerequisitos del entorno

```bash
# Sistema operativo recomendado
Ubuntu 24.04 LTS  o  Debian 12 (Bookworm)

# Verificar systemd
systemctl --version   # >= 252

# Verificar acceso sudo
sudo whoami           # debe retornar: root
```

---

## Progresión de competencias

```
LAB01                    LAB02                    LAB03
  │                        │                        │
  ├─ Ver servicios          ├─ Crear unit file        ├─ Ecosistema completo
  ├─ systemctl status       ├─ Simular fallos          ├─ OnFailure= y alertas
  ├─ systemctl cat          ├─ Timer companion         ├─ Diagnóstico 5 pasos
  ├─ journalctl básico      ├─ Hardening básico        ├─ journald persistente
  └─ systemd-analyze        └─ security score          └─ Score < 4.0
```

---

## Entregables por laboratorio

Cada estudiante debe subir al repositorio:

**LAB01:**
- `LAB01_respuestas.md` — respuestas a las preguntas de análisis

**LAB02:**
- `LAB02_respuestas.md`
- `mi-app.service` — unit file final con hardening
- `mi-reporte.service` — servicio oneshot
- `mi-reporte.timer` — timer companion
- `LAB02_journal_fallo.txt` — logs del fallo inducido

**LAB03:**
- `LAB03_respuestas.md`
- Todos los archivos `.service` y `.timer` del ecosistema CTT
- `LAB03_fallo_A.txt` y `LAB03_fallo_B.txt`
- `LAB03_security_score_final.txt`

---

## Criterios de evaluación U1

| Instrumento | Peso |
|-------------|------|
| Unit file correcta con `[Unit][Service][Install]` | 30% |
| Hardening configurado (mínimo 3 directivas activas) | 25% |
| Timer unit funcionando (`systemctl list-timers`) | 25% |
| Diagnóstico con `journalctl` documentado | 20% |

---

*Linux III · CTT · 2026 — Contacto: docente@ctt.edu.uy*
