-- ============================================================================
-- NODOS — Vistas de transparencia y control anti-sabotaje
-- ============================================================================

-- RED: jerarquía completa de nodos del país (recursiva)
CREATE OR REPLACE VIEW nodos.vw_red_nodos AS
WITH RECURSIVE red AS (
    SELECT n.id, n.codigo, n.nombre, n.tipo_nodo_id, n.nodo_padre_id,
           n.sector, n.pais, n.etapa, n.activo,
           0 AS profundidad,
           n.codigo::text AS ruta
    FROM nodos.nodo n
    WHERE n.nodo_padre_id IS NULL
    UNION ALL
    SELECT n.id, n.codigo, n.nombre, n.tipo_nodo_id, n.nodo_padre_id,
           n.sector, n.pais, n.etapa, n.activo,
           r.profundidad + 1,
           r.ruta || ' > ' || n.codigo
    FROM nodos.nodo n
    JOIN red r ON n.nodo_padre_id = r.id
)
SELECT * FROM red;

-- LIBRO CONTABLE COMPARTIDO (ART. 4): todo movimiento visible con su soporte
-- y sus verificaciones. Esta es la vista pública del núcleo fiscalizador.
CREATE OR REPLACE VIEW nodos.vw_libro_contable AS
SELECT m.id,
       m.nodo_id,
       n.codigo            AS nodo_codigo,
       m.tipo,
       m.monto,
       m.moneda,
       m.descripcion,
       m.fecha,
       m.soporte_referencia,
       m.estado,
       reg.nombres         AS registrado_por,
       count(v.verificador_id) FILTER (WHERE v.resultado) AS verificaciones_favorables
FROM nodos.movimiento_financiero m
JOIN nodos.nodo n          ON n.id = m.nodo_id
JOIN nodos.miembro reg     ON reg.id = m.registrado_por_id
LEFT JOIN nodos.verificacion_movimiento v ON v.movimiento_id = m.id
GROUP BY m.id, n.codigo, reg.nombres;

-- ALERTA DE OPACIDAD (MATRIZ DE SABOTAJE): erogaciones sin soporte, sin doble
-- verificación o no aprobadas; y movimientos con verificador = registrador
-- (imposible por trigger, se mantiene como control defensivo).
CREATE OR REPLACE VIEW nodos.vw_alerta_transparencia AS
SELECT m.id,
       m.nodo_id,
       n.codigo       AS nodo_codigo,
       m.descripcion,
       m.monto,
       m.moneda,
       m.fecha,
       'erogación sin soporte / sin doble verificación' AS alerta
FROM nodos.movimiento_financiero m
JOIN nodos.nodo n ON n.id = m.nodo_id
WHERE m.tipo = 'egreso'
  AND (m.soporte_referencia IS NULL
       OR m.soporte_referencia = ''
       OR (SELECT count(*) FROM nodos.verificacion_movimiento v
            WHERE v.movimiento_id = m.id AND v.resultado) < 2
       OR m.estado <> 'aprobado');

-- ALERTA DE CUSTODIA (ART. 3): activos con menos custodios de los exigidos
CREATE OR REPLACE VIEW nodos.vw_alerta_custodia AS
SELECT a.id,
       n.codigo        AS nodo_codigo,
       a.nombre,
       a.tipo,
       a.custodios_minimos,
       count(c.custodio_id) AS custodios_actuales
FROM nodos.activo_tecnologico a
JOIN nodos.nodo n ON n.id = a.nodo_id
LEFT JOIN nodos.custodia_credencial c ON c.activo_id = a.id
WHERE a.activo
GROUP BY a.id, n.codigo
HAVING count(c.custodio_id) < a.custodios_minimos;

-- ALERTA DE CONTINUIDAD (ART. 5): puestos y actividades sin suplente vigente
CREATE OR REPLACE VIEW nodos.vw_alerta_continuidad AS
SELECT n.id         AS nodo_id,
       n.codigo     AS nodo_codigo,
       'rol'        AS objeto,
       r.nombre     AS detalle,
       NULL::date   AS fecha_inicio
FROM nodos.asignacion_rol ar
JOIN nodos.rol  r ON r.id = ar.rol_id
JOIN nodos.nodo n ON n.id = ar.nodo_id
WHERE ar.activo AND ar.modalidad = 'titular' AND r.requiere_suplente
  AND NOT EXISTS (
      SELECT 1 FROM nodos.asignacion_rol s
       WHERE s.nodo_id = ar.nodo_id AND s.rol_id = ar.rol_id
         AND s.modalidad = 'suplente' AND s.activo
  )
UNION ALL
SELECT n.id, n.codigo, 'actividad',
       'Sin titular→suplente habilitado: ' || a.titulo,
       a.fecha_inicio
FROM nodos.actividad a
JOIN nodos.nodo n ON n.id = a.nodo_id
JOIN nodos.miembro s ON s.id = a.suplente_id
WHERE a.estado IN ('planificado', 'activo')
  AND s.estado IN ('expulsado', 'suspendido');

-- BACKUPS VENCIDOS (MATRIZ: secuestro de canales)
CREATE OR REPLACE VIEW nodos.vw_backup_vencidos AS
SELECT a.id            AS activo_id,
       n.codigo        AS nodo_codigo,
       a.nombre,
       a.backup_periodicidad_dias,
       max(b.fecha)    AS ultimo_backup,
       CURRENT_DATE - max(b.fecha) AS dias_desde_ultimo_backup
FROM nodos.activo_tecnologico a
JOIN nodos.nodo n ON n.id = a.nodo_id
LEFT JOIN nodos.backup_activo b ON b.activo_id = a.id AND b.verificado
WHERE a.activo
GROUP BY a.id, n.codigo
HAVING max(b.fecha) IS NULL
    OR CURRENT_DATE - max(b.fecha) > a.backup_periodicidad_dias;

-- PANEL DEL NODO: resumen integral para la Coordinación General
CREATE OR REPLACE VIEW nodos.vw_panel_nodo AS
SELECT n.id             AS nodo_id,
       n.codigo,
       n.nombre,
       n.etapa,
       count(DISTINCT mi.id) FILTER (WHERE mi.estado = 'activo')          AS miembros_activos,
       count(DISTINCT av.id)                                              AS actividades,
       count(DISTINCT at.id)                                              AS activos_tecnologicos,
       coalesce(saldo.ingresos, 0)  - coalesce(saldo.egresos, 0)          AS saldo_neto
FROM nodos.nodo n
LEFT JOIN nodos.miembro mi  ON mi.nodo_id = n.id
LEFT JOIN nodos.actividad av ON av.nodo_id = n.id
LEFT JOIN nodos.activo_tecnologico at ON at.nodo_id = n.id
LEFT JOIN (
    SELECT nodo_id,
           sum(monto) FILTER (WHERE tipo = 'ingreso') AS ingresos,
           sum(monto) FILTER (WHERE tipo = 'egreso')  AS egresos
    FROM nodos.movimiento_financiero
    GROUP BY nodo_id
) saldo ON saldo.nodo_id = n.id
GROUP BY n.id, n.codigo, n.nombre, n.etapa, saldo.ingresos, saldo.egresos;
