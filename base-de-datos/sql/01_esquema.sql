-- ============================================================================
-- PROYECTO NODOS: Conciencia, Tecnología y Comunidad
-- Red de base de datos "NODOS" — estructura organizativa principal
-- Propósito: fomentar valores, transparencia de los recursos a invertir
--            y desarrollo humano nacional, nodo por nodo.
-- Motor: PostgreSQL 14+
-- Referencias: Matriz Fundacional + Reglamento RGL-NOD-001
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS nodos;

-- ----------------------------------------------------------------------------
-- 1. PILARES Y VALORES (LA RAÍZ: CONCIENCIA)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.pilar (
    id          smallserial PRIMARY KEY,
    clave       text NOT NULL UNIQUE,             -- 'conciencia' | 'tecnologia' | 'comunidad'
    nombre      text NOT NULL,
    descripcion text NOT NULL
);

CREATE TABLE IF NOT EXISTS nodos.valor (
    id          smallserial PRIMARY KEY,
    nombre      text NOT NULL UNIQUE,
    pilar_id    smallint NOT NULL REFERENCES nodos.pilar,
    obligatorio boolean NOT NULL DEFAULT true
);

-- ----------------------------------------------------------------------------
-- 2. LA RED: NODOS (HOGAR, EMPRENDIMIENTO, GRUPO LOCAL, COMUNIDAD)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.tipo_nodo (
    id     smallserial PRIMARY KEY,
    clave  text NOT NULL UNIQUE,                  -- 'hogar' | 'emprendimiento' | 'grupo_local' | 'comunidad'
    nombre text NOT NULL
);

CREATE TABLE IF NOT EXISTS nodos.nodo (
    id               integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo           text NOT NULL UNIQUE,        -- p. ej. 'NODO-NORTE-001'
    nombre           text NOT NULL,
    tipo_nodo_id     smallint NOT NULL REFERENCES nodos.tipo_nodo,
    nodo_padre_id    integer REFERENCES nodos.nodo ON DELETE RESTRICT,
    sector           text NOT NULL,
    pais             text NOT NULL,
    etapa            text NOT NULL DEFAULT 'reunir'
                     CHECK (etapa IN ('reunir', 'organizar', 'actuar', 'activo')),
    fecha_activacion date NOT NULL DEFAULT CURRENT_DATE,
    activo           boolean NOT NULL DEFAULT true,
    CONSTRAINT nodo_auto_ref CHECK (nodo_padre_id IS NULL OR nodo_padre_id <> id)
);

-- ----------------------------------------------------------------------------
-- 3. MIEMBROS Y FILTRO ÉTICO DE ADMISIÓN (RGL-NOD-001, ART. 1)
-- ----------------------------------------------------------------------------

CREATE TYPE nodos.estado_miembro AS ENUM
    ('aspirante', 'activo', 'amonestado', 'suspendido', 'expulsado');

CREATE TABLE IF NOT EXISTS nodos.miembro (
    id                       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id                  integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    nombres                  text NOT NULL,
    documento_ci             text NOT NULL,
    contacto                 text,
    estado                   nodos.estado_miembro NOT NULL DEFAULT 'aspirante',
    fecha_admision           date NOT NULL DEFAULT CURRENT_DATE,
    antecedentes_verificados boolean NOT NULL DEFAULT false,
    UNIQUE (nodo_id, documento_ci)
);

-- Adhesión demostrada a los valores (filtro ético de la convocatoria)
CREATE TABLE IF NOT EXISTS nodos.miembro_valor (
    miembro_id   integer NOT NULL REFERENCES nodos.miembro ON DELETE CASCADE,
    valor_id     smallint NOT NULL REFERENCES nodos.valor,
    declarado_en date NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (miembro_id, valor_id)
);

-- ----------------------------------------------------------------------------
-- 4. ROLES, REDUNDANCIA Y CUSTODIA COMPARTIDA (ART. 3 Y ART. 5)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.rol (
    id                smallserial PRIMARY KEY,
    clave             text NOT NULL UNIQUE,       -- 'coordinacion_general' | 'comite_etica_tecnologia' | ...
    nombre            text NOT NULL,
    requiere_suplente boolean NOT NULL DEFAULT true
);

CREATE TYPE nodos.modalidad_rol AS ENUM ('titular', 'suplente');

CREATE TABLE IF NOT EXISTS nodos.asignacion_rol (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id    integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    miembro_id integer NOT NULL REFERENCES nodos.miembro ON DELETE RESTRICT,
    rol_id     smallint NOT NULL REFERENCES nodos.rol,
    modalidad  nodos.modalidad_rol NOT NULL,
    desde      date NOT NULL DEFAULT CURRENT_DATE,
    hasta      date,
    activo     boolean NOT NULL DEFAULT true
);

-- Canales/bases de datos/cuentas: activos comunitarios, nunca propiedad
-- individual (ART. 3). La credencial nunca se guarda en claro: solo la
-- referencia a la bóveda de credenciales del nodo.
CREATE TABLE IF NOT EXISTS nodos.activo_tecnologico (
    id                       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id                  integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    nombre                   text NOT NULL,
    tipo                     text NOT NULL CHECK (tipo IN
                             ('base_datos', 'canal_comunicacion', 'cuenta_admin', 'registro_sistema')),
    referencia_boveda        text NOT NULL,
    custodios_minimos        smallint NOT NULL DEFAULT 2 CHECK (custodios_minimos >= 2),
    backup_periodicidad_dias smallint NOT NULL DEFAULT 7 CHECK (backup_periodicidad_dias > 0),
    activo                   boolean NOT NULL DEFAULT true,
    creado_en                timestamptz NOT NULL DEFAULT now()
);

-- Custodia tripartita: mínimo dos custodios distintos por activo (ART. 3)
CREATE TABLE IF NOT EXISTS nodos.custodia_credencial (
    activo_id    integer NOT NULL REFERENCES nodos.activo_tecnologico ON DELETE CASCADE,
    custodio_id  integer NOT NULL REFERENCES nodos.miembro ON DELETE RESTRICT,
    asignado_en  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (activo_id, custodio_id)
);

-- Backups periódicos (acción correctiva ante secuestro de canales)
CREATE TABLE IF NOT EXISTS nodos.backup_activo (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    activo_id    integer NOT NULL REFERENCES nodos.activo_tecnologico ON DELETE CASCADE,
    encargado_id integer NOT NULL REFERENCES nodos.miembro,
    fecha        date NOT NULL DEFAULT CURRENT_DATE,
    verificado   boolean NOT NULL DEFAULT false
);

-- ----------------------------------------------------------------------------
-- 5. REUNIONES Y BLINDAJE DE ASAMBLEAS (ART. 2)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.reunion (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id             integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    titulo              text NOT NULL,
    fecha               timestamptz NOT NULL,
    agenda_publicada    boolean NOT NULL DEFAULT false,
    publicada_en        timestamptz,
    moderador_id        integer NOT NULL REFERENCES nodos.miembro,
    minutos_por_persona numeric NOT NULL DEFAULT 3 CHECK (minutos_por_persona <= 3)
);

CREATE TABLE IF NOT EXISTS nodos.punto_agenda (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reunion_id integer NOT NULL REFERENCES nodos.reunion ON DELETE CASCADE,
    orden      smallint NOT NULL,
    tema       text NOT NULL,
    UNIQUE (reunion_id, orden)
);

CREATE TYPE nodos.tipo_incidente AS ENUM
    ('insulto', 'difamacion', 'provocacion_violenta', 'desviacion_agenda', 'desviacion_extraperiferica');

-- Primera falta: amonestación; reincidencia: retiro del espacio (ART. 2)
CREATE TABLE IF NOT EXISTS nodos.apercibimiento (
    id                   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reunion_id           integer NOT NULL REFERENCES nodos.reunion ON DELETE CASCADE,
    miembro_id           integer NOT NULL REFERENCES nodos.miembro ON DELETE RESTRICT,
    tipo_incidente       nodos.tipo_incidente NOT NULL,
    descripcion          text,
    primera_amonestacion boolean NOT NULL DEFAULT true,
    retirado_del_espacio boolean NOT NULL DEFAULT false,
    registrado_en        timestamptz NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 6. TRANSPARENCIA FINANCIERA Y DOBLE VERIFICACIÓN (ART. 4)
-- ----------------------------------------------------------------------------

CREATE TYPE nodos.tipo_movimiento AS ENUM ('ingreso', 'egreso');
CREATE TYPE nodos.estado_movimiento AS ENUM ('registrado', 'verificado', 'aprobado', 'rechazado');

CREATE TABLE IF NOT EXISTS nodos.movimiento_financiero (
    id                 integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id            integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    tipo               nodos.tipo_movimiento NOT NULL,
    monto              numeric(14, 2) NOT NULL CHECK (monto > 0),
    moneda             text NOT NULL DEFAULT 'USD',
    descripcion        text NOT NULL,
    registrado_por_id  integer NOT NULL REFERENCES nodos.miembro,
    soporte_referencia text,                      -- factura/recibo (obligatorio en erogaciones: trigger)
    fecha              date NOT NULL DEFAULT CURRENT_DATE,
    estado             nodos.estado_movimiento NOT NULL DEFAULT 'registrado',
    registrado_en      timestamptz NOT NULL DEFAULT now()
);

-- Doble verificación tecnológica: dos revisores distintos del registrador
CREATE TABLE IF NOT EXISTS nodos.verificacion_movimiento (
    movimiento_id  integer NOT NULL REFERENCES nodos.movimiento_financiero ON DELETE CASCADE,
    verificador_id integer NOT NULL REFERENCES nodos.miembro ON DELETE RESTRICT,
    resultado      boolean NOT NULL,
    observaciones  text,
    verificada_en  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (movimiento_id, verificador_id)
);

-- Auditorías ante indicios de opacidad (libro contable compartido)
CREATE TABLE IF NOT EXISTS nodos.auditoria_financiera (
    id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id         integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    auditor_id      integer NOT NULL REFERENCES nodos.miembro,
    alcance         text NOT NULL,
    hallazgos       text,
    medidas_tomadas text,
    fecha_auditoria date NOT NULL DEFAULT CURRENT_DATE
);

-- ----------------------------------------------------------------------------
-- 7. PROYECTOS Y ACCIÓN COMUNITARIA (FASE 3: ACTUAR)
-- ----------------------------------------------------------------------------

CREATE TYPE nodos.tipo_actividad AS ENUM
    ('taller', 'proyecto_productivo', 'apoyo_social', 'capacitacion');

CREATE TABLE IF NOT EXISTS nodos.actividad (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id      integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    tipo         nodos.tipo_actividad NOT NULL,
    titulo       text NOT NULL,
    descripcion  text,
    titular_id   integer NOT NULL REFERENCES nodos.miembro,
    suplente_id  integer NOT NULL REFERENCES nodos.miembro,
    fecha_inicio date NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin    date,
    estado       text NOT NULL DEFAULT 'planificado'
                 CHECK (estado IN ('planificado', 'activo', 'pausado', 'completado', 'cancelado')),
    CONSTRAINT titulares_distintos CHECK (titular_id <> suplente_id)
);

-- ----------------------------------------------------------------------------
-- 8. TALENTOS Y CAPACITACIÓN MUTUA ("QUIEN SABE, ENSEÑA; QUIEN TIENE, COMPARTE")
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.talento (
    id     smallserial PRIMARY KEY,
    nombre text NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS nodos.miembro_talento (
    miembro_id    integer NOT NULL REFERENCES nodos.miembro ON DELETE CASCADE,
    talento_id    smallint NOT NULL REFERENCES nodos.talento,
    puede_ensenar boolean NOT NULL DEFAULT false,
    PRIMARY KEY (miembro_id, talento_id)
);

CREATE TABLE IF NOT EXISTS nodos.capacitacion (
    id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id        integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    talento_id     smallint REFERENCES nodos.talento,
    actividad_id   integer REFERENCES nodos.actividad ON DELETE SET NULL,
    tema           text NOT NULL,
    facilitador_id integer NOT NULL REFERENCES nodos.miembro,
    fecha          date NOT NULL DEFAULT CURRENT_DATE,
    asistentes     smallint NOT NULL DEFAULT 0 CHECK (asistentes >= 0)
);

-- ----------------------------------------------------------------------------
-- 9. MATRIZ DE SABOTAJE, INCIDENCIAS Y MEDIACIÓN (ART. 6)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.tipo_sabotaje (
    id                   smallserial PRIMARY KEY,
    clave                text NOT NULL UNIQUE,
    tipo                 text NOT NULL,
    indicador_alerta     text NOT NULL,
    protocolo_preventivo text NOT NULL,
    accion_correctiva    text NOT NULL
);

CREATE TABLE IF NOT EXISTS nodos.incidencia_sabotaje (
    id                     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id                integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    tipo_sabotaje_id       smallint NOT NULL REFERENCES nodos.tipo_sabotaje,
    descripcion            text NOT NULL,
    miembro_involucrado_id integer REFERENCES nodos.miembro,
    reportado_por_id       integer NOT NULL REFERENCES nodos.miembro,
    resuelta               boolean NOT NULL DEFAULT false,
    medida_aplicada        text,
    reportada_en           timestamptz NOT NULL DEFAULT now()
);

CREATE TYPE nodos.fase_mediacion AS ENUM
    ('dialogo_privado', 'acuerdo_escrito', 'expulsion_operativa');

-- Comité de Mediación: 3 fases (RGL-NOD-001, ART. 6)
CREATE TABLE IF NOT EXISTS nodos.caso_mediacion (
    id                 integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nodo_id            integer NOT NULL REFERENCES nodos.nodo ON DELETE RESTRICT,
    miembro_acusado_id integer NOT NULL REFERENCES nodos.miembro,
    incidencia_id      integer REFERENCES nodos.incidencia_sabotaje,
    fase               nodos.fase_mediacion NOT NULL DEFAULT 'dialogo_privado',
    confidencial       boolean NOT NULL DEFAULT true,
    compromisos        text,
    plazo_cumplimiento date,
    resuelto_en        date,
    resultado          text
);

CREATE TYPE nodos.tipo_sancion AS ENUM
    ('amonestacion', 'suspension', 'revocacion_credenciales', 'retiro_manejo_fondos', 'expulsion_operativa');

CREATE TABLE IF NOT EXISTS nodos.sancion (
    id                integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    caso_mediacion_id integer REFERENCES nodos.caso_mediacion ON DELETE SET NULL,
    miembro_id        integer NOT NULL REFERENCES nodos.miembro ON DELETE RESTRICT,
    tipo_sancion      nodos.tipo_sancion NOT NULL,
    motivo            text NOT NULL,
    aplicada_en       date NOT NULL DEFAULT CURRENT_DATE
);

-- ----------------------------------------------------------------------------
-- 10. PROHIBICIÓN DE PROSELITISMO Y USO INDEBIDO (ALERTA DE CONVOCATORIA)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodos.declaracion_conducta (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    miembro_id    integer NOT NULL REFERENCES nodos.miembro ON DELETE CASCADE,
    compromiso    text NOT NULL,                  -- texto del compromiso firmado
    sin_proselitismo boolean NOT NULL DEFAULT true, -- sin proselitismo político-partidista
    sin_interes_propio boolean NOT NULL DEFAULT true,
    firmada_en    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (miembro_id)
);
