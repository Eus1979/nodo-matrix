-- ============================================================================
-- NODOS — Datos semilla de la Matriz Fundacional y del RGL-NOD-001
-- ============================================================================

-- La Trinidad Conceptual (Matriz Raíz)
INSERT INTO nodos.pilar (clave, nombre, descripcion) VALUES
    ('conciencia', 'La Raíz: Conciencia',
     'Ética, valores universales, madurez emocional y propósito. El filtro innegociable de cada decisión.'),
    ('tecnologia', 'La Base: Tecnología',
     'Métodos ordenados, informática, administración eficiente y educación financiera. El puente práctico.'),
    ('comunidad',  'La Matriz: Comunidad',
     'Tejido social en movimiento, cooperación ganar-ganar, capacitación colectiva y servicio activo.')
ON CONFLICT (clave) DO NOTHING;

-- Valores fundacionales
INSERT INTO nodos.valor (nombre, pilar_id, obligatorio) VALUES
    ('Honestidad',                    (SELECT id FROM nodos.pilar WHERE clave = 'conciencia'), true),
    ('Empatía',                       (SELECT id FROM nodos.pilar WHERE clave = 'conciencia'), true),
    ('Respeto mutuo',                 (SELECT id FROM nodos.pilar WHERE clave = 'conciencia'), true),
    ('Resolución pacífica de conflictos', (SELECT id FROM nodos.pilar WHERE clave = 'conciencia'), true),
    ('Transparencia',                 (SELECT id FROM nodos.pilar WHERE clave = 'tecnologia'), true),
    ('Educación financiera',          (SELECT id FROM nodos.pilar WHERE clave = 'tecnologia'), false),
    ('Cooperación ganar-ganar',       (SELECT id FROM nodos.pilar WHERE clave = 'comunidad'), true),
    ('Vocación de servicio',          (SELECT id FROM nodos.pilar WHERE clave = 'comunidad'), true)
ON CONFLICT (nombre) DO NOTHING;

-- Tipos de nodo (estructura abierta y replicable)
INSERT INTO nodos.tipo_nodo (clave, nombre) VALUES
    ('hogar',          'Hogar'),
    ('emprendimiento', 'Emprendimiento'),
    ('grupo_local',    'Grupo local'),
    ('comunidad',      'Comunidad / sector')
ON CONFLICT (clave) DO NOTHING;

-- Roles operativos (sin monopolio de funciones: siempre con suplente)
INSERT INTO nodos.rol (clave, nombre, requiere_suplente) VALUES
    ('coordinacion_general',    'Coordinación General del NODO',       true),
    ('comite_etica_tecnologia', 'Comité de Ética y Tecnología',        true),
    ('fiscalizador',            'Núcleo Fiscalizador (finanzas)',      true),
    ('moderador_reuniones',     'Moderador Neutral de Reuniones',      true),
    ('custodio_credenciales',   'Custodio de Activos Tecnológicos',    true),
    ('responsable_proyecto',    'Responsable de Proyecto / Actividad', true)
ON CONFLICT (clave) DO NOTHING;

-- Matriz de riesgos de sabotaje y medidas correctivas (RGL-NOD-001)
INSERT INTO nodos.tipo_sabotaje (clave, tipo, indicador_alerta, protocolo_preventivo, accion_correctiva) VALUES
    ('division_rumorologia', 'División / Rumorología',
     'Comentarios destructivos fuera de los canales oficiales.',
     'Reuniones de conciliación bajo el pilar de Conciencia.',
     'Amonestación directa y aclaración pública de hechos.'),
    ('secuestro_canales', 'Secuestro de Canales',
     'Bloqueo de acceso a plataformas digitales comunitarias.',
     'Asignación de roles jerárquicos y backups periódicos.',
     'Revocación inmediata de credenciales mediante el co-administrador.'),
    ('opacidad_recursos', 'Opacidad de Recursos',
     'Resistencia a presentar cuentas o soporte de gastos.',
     'Uso de libro contable compartido e informatizado.',
     'Auditoría inmediata y suspensión del manejo de fondos al infractor.'),
    ('inaccion_deliberada', 'Inacción Deliberada',
     'Incumplimiento reiterado de tareas clave acordadas.',
     'Asignación clara de roles (responsable y suplente).',
     'Reasignación inmediata de la función al rol suplente.')
ON CONFLICT (clave) DO NOTHING;

-- Talentos de ejemplo para el mapeo local
INSERT INTO nodos.talento (nombre) VALUES
    ('Administración contable'),
    ('Herramientas digitales (hojas de cálculo)'),
    ('Producción agrícola'),
    ('Carpintería / oficios técnicos'),
    ('Comunicación organizada')
ON CONFLICT (nombre) DO NOTHING;
