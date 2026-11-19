# NODOS — App de Registro (Web + Android)

Captura de datos de la red con formularios simples: nodos, miembros,
movimientos financieros, proyectos, asambleas y talentos.

- **Modo real:** escribe con parámetros seguros directamente en la base
  `nodos` de PostgreSQL; el reglamento RGL-NOD-001 valida cada operación
  (filtro ético, doble verificación, agenda previa, titular/suplente).
- **Modo demo:** `NODOS_DEMO=1` prueba toda la interfaz sin base de datos.
- **Modo app:** instalable en Android como PWA ("Añadir a pantalla de
  inicio"), con caché offline de la interfaz.

## Arranque

```bash
cd app

# toda la app sin BD (para probar los formularios)
NODOS_DEMO=1 python3 registro_nodos.py

# modo real (primero fijar contraseña de la base, solo una vez)
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'TU_CLAVE';"
python3 registro_nodos.py --password TU_CLAVE

# para usarla desde el celular (misma red Wi-Fi)
python3 registro_nodos.py --password TU_CLAVE --host 0.0.0.0 --puerto 8081
```

En el celular: `http://IP-de-esta-PC:8081` → menú Chrome (⋮) →
**Añadir a pantalla de inicio** → queda como app "NODOS".

## Qué permite registrar

| Pestaña | Operación | Regla codificada |
| --- | --- | --- |
| ⬡ Nodo | abrir sub-nodos jerárquicos | etapa Reunir→Organizar→Actuar |
| 👤 Miembro | admisión con valores declarados | filtro ético + declaración de conducta (Art. 1) |
| 💰 Movimiento | ingresos/egresos al libro contable | nada se aprueba sin 2 verificaciones de terceros (Art. 4) |
| ✅ Verificación | segunda firma de un movimiento | verificador ≠ registrador |
| 🛠️ Proyecto | talleres/proyectos con equipo | titular ≠ suplente (Art. 5) |
| 🤝 Asamblea | convocatoria con agenda | agenda obligatoria y publicada antes (Art. 2) |
| 🧠 Talento | mapeo de habilidades | "quién sabe, enseña" |

La app muestra `Alertas` en vivo (transparencia, custodia, continuidad,
backups) mediante las vistas del esquema.

## Seguridad

- Consultas **parametrizadas** (sin concatenación de SQL).
- El acceso a la base es por el driver local de la máquina del nodo; la
  app never expone la base directamente al navegador.
- Puerto local por defecto (`127.0.0.1`); usa `--host 0.0.0.0` solo en tu
  red de confianza.
