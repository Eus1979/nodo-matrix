# NODOS — Interfaz de Monitoreo (Web + Android)

Panel en tiempo real de la red de nodos: KPIs, libro contable compartido,
alertas anti-sabotaje, red jerárquica y actividades.

**Sin dependencias nuevas:** usa Python 3 (ya incluido en CachyOS) y
`psql` con la base `nodos` ya cargada. Nada de Node, npm ni frameworks.

## Ejecutar en tu PC

```bash
cd monitor
python3 monitor_nodos.py
```

Abre **http://localhost:8080** en el navegador. El panel se actualiza solo
cada 30 segundos y lee directamente de tu base de datos PostgreSQL.

## Verlo en Android (misma red Wi-Fi)

```bash
python3 monitor_nodos.py --host 0.0.0.0 --puerto 8080
ip addr show | grep "inet "        # mira tu IP, p. ej. 192.168.1.20
```

En el celular abre **http://192.168.1.20:8080** → menú de Chrome
(⋮) → **Añadir a pantalla de inicio**. Queda instalado como app "NODOS"
(usa el manifest incluido: pantalla completa, tema verde).

> Nota: el monitor es de solo-lectura y por defecto solo responde en tu
> propia PC (`127.0.0.1`). Con `--host 0.0.0.0` queda visible en la red
> doméstica; úsalo en tu red de confianza y persétalo con `--host` al terminar.

## Qué muestra

| Sección | Fuente |
| --- | --- |
| KPIs de la red | totales de nodos, miembros, proyectos, activos, asambleas y saldo |
| Alertas del sistema | `vw_alerta_transparencia`, `vw_alerta_custodia`, `vw_alerta_continuidad`, `vw_backup_vencidos` |
| Red de nodos | árbol recursivo con saldo y barras comparativas |
| Actividades | titular → suplente (continuidad operativa, Art. 5) |
| Libro contable | últimos 50 movimientos con soporte y doble verificación (Art. 4) |

Si algo falta (p. ej. no cargaste `04_vistas.sql`), el panel lo indica
con una guía para ejecutar los archivos en orden.

## ¿Y una app nativa de Android?

El panel es una **PWA**: instala como app nativa (ícono en el celular,
pantalla completa, sin tienda de aplicaciones). Compilar un APK con
Android Studio requeriría mantener un proyecto extra; si tu red crece y
quieres notificaciones push o modo-offline real, es el siguiente paso
(gray "build" con la misma API `/api/all`).
