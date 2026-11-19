-- ============================================================================
-- NODOS — Desperter rápido: primer NODO real de arranque
-- Ejemplo de datos para arrancar un nodo de barrio con 5 personas y probar
-- todas las funciones de transparencia. Reemplaza nombres, sectores y C.I.
-- por los reales de tu comunidad.
--
-- País del ejemplo: 'Venezuela' — cambia el literal si aplica otro país.
-- Advertencia: no introduzcas documentos reales en bases de datos sin
-- protección de datos.
-- ============================================================================

-- ------------------------------------------------------------------
-- 1) NODO RAÍZ (coordinación país) + 2 nodos hijos de sectores
-- ------------------------------------------------------------------
INSERT INTO nodos.nodo (codigo, nombre, tipo_nodo_id, nodo_padre_id, sector, pais, etapa)
VALUES
    ('NODO-RAIZ-001', 'NODO Raíz Nacional',
     (SELECT id FROM nodos.tipo_nodo WHERE clave = 'comunidad'),
     NULL, 'Nacional', 'Venezuela', 'activo'),
    ('NODO-OESTE-100', 'NODO Barrio Oeste',
     (SELECT id FROM nodos.tipo_nodo WHERE clave = 'grupo_local'),
     (SELECT id FROM nodos.nodo WHERE codigo = 'NODO-RAIZ-001'),
     'Barrio Oeste', 'Venezuela', 'organizar'),
    ('NODO-SUR-100', 'NODO Emprendedores del Sur',
     (SELECT id FROM nodos.tipo_nodo WHERE clave = 'emprendimiento'),
     (SELECT id FROM nodos.nodo WHERE codigo = 'NODO-RAIZ-001'),
     'Zona Sur', 'Venezuela', 'reunir')
ON CONFLICT (codigo) DO NOTHING;

-- ------------------------------------------------------------------
-- 2) MIEMBROS (estados activos) del nodo Barrio Oeste
-- ------------------------------------------------------------------
WITH n AS (SELECT id FROM nodos.nodo WHERE codigo = 'NODO-OESTE-100')
INSERT INTO nodos.miembro (nodo_id, nombres, documento_ci, contacto, estado, antecedentes_verificados)
SELECT n.id, v.nombres, v.ci, v.contacto, 'activo', true
FROM (VALUES
    ('María Rondón',   'V-00000001', 'maria@ejemplo.ve',  'Coordinadora'),
    ('José Pérez',     'V-00000002', 'jose@ejemplo.ve',   'Tesorero'),
    ('Ana Guevara',    'V-00000003', 'ana@ejemplo.ve',    'Fiscalizadora'),
    ('Luis Márquez',   'V-00000004', 'luis@ejemplo.ve',   'Moderador'),
    ('Carmen Díaz',    'V-00000005', 'carmen@ejemplo.ve', 'Suplente general')
) AS v(nombres, ci, contacto, nota)
JOIN n ON true
WHERE NOT EXISTS (
    SELECT 1 FROM nodos.miembro m
    WHERE m.nodo_id = n.id AND m.documento_ci = v.ci
);

-- ------------------------------------------------------------------
-- 3) ADHESIÓN A VALORES (filtro ético, ART. 1) + declaración de conducta
-- ------------------------------------------------------------------
INSERT INTO nodos.miembro_valor (miembro_id, valor_id)
SELECT m.id, va.id
FROM nodos.miembro m
CROSS JOIN nodos.valor va          -- adhesión plena de todos al catálogo fundacional
WHERE m.documento_ci BETWEEN 'V-00000001' AND 'V-00000005'
ON CONFLICT DO NOTHING;

INSERT INTO nodos.declaracion_conducta (miembro_id, compromiso)
SELECT id, 'Me comprometo a Actuar bajo la trinidad de NODOS: Conciencia, Tecnología y Comunidad, sin proselitismo político y sin usar la estructura para beneficio propio.'
FROM nodos.miembro
WHERE documento_ci BETWEEN 'V-00000001' AND 'V-00000005'
ON CONFLICT (miembro_id) DO NOTHING;

-- ------------------------------------------------------------------
-- 4) ROLES con redundancia titular/suplente (ART. 5) del nodo Oeste
-- ------------------------------------------------------------------
WITH par AS (
    SELECT (SELECT id FROM nodos.nodo  WHERE codigo = 'NODO-OESTE-100')  AS nodo_id,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000001') AS m1,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000002') AS m2,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000003') AS m3,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000005') AS m5
)
INSERT INTO nodos.asignacion_rol (nodo_id, miembro_id, rol_id, modalidad)
SELECT p.nodo_id,
       CASE r.clave WHEN 'coordinacion_general' THEN p.m1 WHEN 'comite_etica_tecnologia' THEN p.m1 ELSE p.m2 END,
       r.id,
       'titular'
FROM nodos.rol r CROSS JOIN par p
WHERE r.clave IN ('coordinacion_general', 'comite_etica_tecnologia', 'fiscalizador');

WITH par AS (
    SELECT (SELECT id FROM nodos.nodo  WHERE codigo = 'NODO-OESTE-100')  AS nodo_id,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000005') AS m5,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000003') AS m3,
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000004') AS m4
)
INSERT INTO nodos.asignacion_rol (nodo_id, miembro_id, rol_id, modalidad)
SELECT p.nodo_id,
       CASE r.clave WHEN 'coordinacion_general' THEN p.m5 WHEN 'comite_etica_tecnologia' THEN p.m3 ELSE p.m4 END,
       r.id,
       'suplente'
FROM nodos.rol r CROSS JOIN par p
WHERE r.clave IN ('coordinacion_general', 'comite_etica_tecnologia', 'fiscalizador');

-- ------------------------------------------------------------------
-- 5) ACTIVO TECNOLÓGICO con custodia compartida, mínimo 2 custodios (ART. 3)
-- ------------------------------------------------------------------
INSERT INTO nodos.activo_tecnologico (nodo_id, nombre, tipo, referencia_boveda, custodios_minimos, backup_periodicidad_dias)
SELECT n.id, 'Base de datos NODOS del Barrio Oeste', 'base_datos', 'boveda://nodo-oeste/bd-nodos (contraseñas SOLO en la bóveda, nunca en la base)', 2, 7
FROM nodos.nodo n WHERE n.codigo = 'NODO-OESTE-100'
ON CONFLICT DO NOTHING;

INSERT INTO nodos.custodia_credencial (activo_id, custodio_id)
SELECT a.id, m.id
FROM nodos.activo_tecnologico a
JOIN nodos.nodo n        ON n.id = a.nodo_id
JOIN nodos.miembro m     ON m.nodo_id = n.id
WHERE n.codigo = 'NODO-OESTE-100' AND m.documento_ci IN ('V-00000001', 'V-00000002', 'V-00000003')
ON CONFLICT DO NOTHING;

INSERT INTO nodos.backup_activo (activo_id, encargado_id, verificado)
SELECT a.id, (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000002'), true
FROM nodos.activo_tecnologico a
JOIN nodos.nodo n ON n.id = a.nodo_id
WHERE n.codigo = 'NODO-OESTE-100';

-- ------------------------------------------------------------------
-- 6) REUNIÓN con agenda publicada previamente (ART. 2)
-- ------------------------------------------------------------------
WITH r AS (
    INSERT INTO nodos.reunion (nodo_id, titulo, fecha, agenda_publicada, publicada_en, moderador_id, minutos_por_persona)
    SELECT n.id, 'Asamblea de activación del NODO Oeste', now() + interval '7 days', true,
           now() - interval '2 days',
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000004'), 3
    FROM nodos.nodo n WHERE n.codigo = 'NODO-OESTE-100'
        AND NOT EXISTS (SELECT 1 FROM nodos.reunion x WHERE x.titulo = 'Asamblea de activación del NODO Oeste')
    RETURNING id
)
INSERT INTO nodos.punto_agenda (reunion_id, orden, tema)
SELECT r.id, ag.orden, ag.tema FROM r,
 (VALUES (1, 'Bienvenida y valores del NODO'), (2, 'Lectura del reglamento RGL-NOD-001'),
         (3, 'Mapeo de talentos del sector'), (4, 'Plan de primer proyecto productivo')) AS ag(orden, tema);

-- ------------------------------------------------------------------
-- 7) FINANZAS: aporte inicial y erogación con doble verificación (ART. 4)
-- ------------------------------------------------------------------
INSERT INTO nodos.movimiento_financiero (nodo_id, tipo, monto, moneda, descripcion, registrado_por_id, fecha, estado)
SELECT n.id, 'ingreso', 500.00, 'USD', 'Aporte inicial de fondo común del NODO',
       (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000002'), CURRENT_DATE, 'aprobado'
FROM nodos.nodo n
WHERE n.codigo = 'NODO-OESTE-100'
  AND NOT EXISTS (SELECT 1 FROM nodos.movimiento_financiero f WHERE f.descripcion LIKE 'Aporte inicial de fondo común%');

INSERT INTO nodos.verificacion_movimiento (movimiento_id, verificador_id, resultado)
SELECT f.id, m.id, true
FROM nodos.movimiento_financiero f
JOIN nodos.nodo n  ON n.id = f.nodo_id
JOIN nodos.miembro m ON m.nodo_id = n.id AND m.documento_ci IN ('V-00000001', 'V-00000003')
WHERE f.descripcion LIKE 'Aporte inicial de fondo común%'
ON CONFLICT DO NOTHING;

WITH e AS (
    INSERT INTO nodos.movimiento_financiero (nodo_id, tipo, monto, moneda, descripcion, registrado_por_id, soporte_referencia, fecha, estado)
    SELECT n.id, 'egreso', 120.00, 'USD', 'Compra de material para el taller de hojas de cálculo',
           (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000002'),
           'FACT-2026-0007 (cargar a la bóveda comunitaria)', CURRENT_DATE, 'registrado'
    FROM nodos.nodo n
    WHERE n.codigo = 'NODO-OESTE-100'
      AND NOT EXISTS (SELECT 1 FROM nodos.movimiento_financiero f WHERE f.descripcion LIKE 'Compra de material para el taller%')
    RETURNING id
)
INSERT INTO nodos.verificacion_movimiento (movimiento_id, verificador_id, resultado)
SELECT e.id, m.id, true FROM e
JOIN nodos.nodo n    ON n.codigo = 'NODO-OESTE-100'
JOIN nodos.miembro m ON m.nodo_id = n.id AND m.documento_ci IN ('V-00000001', 'V-00000003')
ON CONFLICT DO NOTHING;

UPDATE nodos.movimiento_financiero f
SET estado = 'aprobado'
FROM nodos.nodo n
WHERE f.nodo_id = n.id AND n.codigo = 'NODO-OESTE-100'
  AND f.tipo = 'egreso' AND f.estado <> 'aprobado'
  AND 2 <= (SELECT count(*) FROM nodos.verificacion_movimiento v
             WHERE v.movimiento_id = f.id AND v.resultado);

-- ------------------------------------------------------------------
-- 8) TALENTOS del sector, CAPACITACIÓN y primer PROYECTO comunitario
-- ------------------------------------------------------------------
INSERT INTO nodos.miembro_talento (miembro_id, talento_id, puede_ensenar)
SELECT m.id, t.id, m.documento_ci IN ('V-00000003', 'V-00000001')
FROM nodos.miembro m
JOIN nodos.talento t ON t.nombre IN ('Administración contable', 'Herramientas digitales (hojas de cálculo)')
WHERE m.documento_ci BETWEEN 'V-00000001' AND 'V-00000005'
ON CONFLICT DO NOTHING;

INSERT INTO nodos.actividad (nodo_id, tipo, titulo, descripcion, titular_id, suplente_id, estado)
SELECT n.id, 'capacitacion', 'Taller: hojas de cálculo para emprendedores',
       'Primera capacitación del NODO: registro impecable de datos para decisiones (pilar Tecnología).',
       (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000003'),
       (SELECT id FROM nodos.miembro WHERE documento_ci = 'V-00000005'),
       'planificado'
FROM nodos.nodo n
WHERE n.codigo = 'NODO-OESTE-100'
  AND NOT EXISTS (SELECT 1 FROM nodos.actividad a WHERE a.titulo LIKE 'Taller: hojas de cálculo%');

-- ------------------------------------------------------------------
-- 9) VERIFICACIÓN FINAL: el panel del nodo debe mostrar saldo 380 (500-120)
-- ------------------------------------------------------------------
-- SELECT * FROM nodos.vw_panel_nodo;
-- SELECT * FROM nodos.vw_libro_contable;
-- SELECT * FROM nodos.vw_red_nodos;
