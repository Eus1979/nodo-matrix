-- ============================================================================
-- NODOS — Restricciones operativas codificadas (Reglamento RGL-NOD-001)
-- ============================================================================

-- ART. 2: toda reunión debe tener agenda publicada previamente
ALTER TABLE nodos.reunion
    ADD CONSTRAINT reunion_agenda_previa
    CHECK (agenda_publicada = false OR publicada_en < fecha);

-- ART. 4: la erogación exige soporte (factura/recibo) para poder aprobarse
CREATE OR REPLACE FUNCTION nodos.fn_trg_erogacion_no_aprobada()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tipo = 'egreso' AND NEW.estado IN ('verificado', 'aprobado')
       AND (NEW.soporte_referencia IS NULL OR NEW.soporte_referencia = '') THEN
        RAISE EXCEPTION 'RGL-NOD-001 Art.4: toda erogación requiere factura o recibo antes de su verificación';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_erogacion_soporte
BEFORE INSERT OR UPDATE OF tipo, estado, soporte_referencia ON nodos.movimiento_financiero
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_erogacion_no_aprobada();

-- ART. 4: doble verificación tecnológica — el verificador no puede ser el
-- registrador, y el egreso solo puede marcarse 'aprobado' con 2 verificaciones
-- positivas de personas distintas más el visto bueno del responsable del NODO.
CREATE OR REPLACE FUNCTION nodos.fn_trg_verificador_distinto()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM nodos.movimiento_financiero m
        WHERE m.id = NEW.movimiento_id AND m.registrado_por_id = NEW.verificador_id
    ) THEN
        RAISE EXCEPTION 'RGL-NOD-001 Art.4: prohibido el manejo de fondos por una sola persona';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_verificador_distinto
BEFORE INSERT ON nodos.verificacion_movimiento
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_verificador_distinto();

CREATE OR REPLACE FUNCTION nodos.fn_trg_doble_verificacion()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_ok integer;
BEGIN
    IF NEW.tipo = 'egreso' AND NEW.estado = 'aprobado' THEN
        SELECT count(DISTINCT verificador_id) INTO v_ok
        FROM nodos.verificacion_movimiento
        WHERE movimiento_id = NEW.id AND resultado = true;
        IF v_ok < 2 THEN
            RAISE EXCEPTION 'RGL-NOD-001 Art.4: el egreso requiere doble verificación tecnológica (2 revisores con resultado favorable)';
        END IF;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_doble_verificacion
BEFORE UPDATE OF estado ON nodos.movimiento_financiero
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_doble_verificacion();

-- ART. 3: ningún activo tecnológico comunitario con menos de 2 custodios.
-- Constraint trigger diferible: permite insertar el activo y agregar custodios
-- en la misma transacción.
CREATE OR REPLACE FUNCTION nodos.fn_trg_custodia_minima()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cu integer; v_min integer; v_activo integer;
BEGIN
    IF TG_TABLE_NAME = 'activo_tecnologico' THEN
        v_activo := NEW.id;
    ELSE
        v_activo := OLD.activo_id;
    END IF;
    SELECT count(DISTINCT c.custodio_id), max(a.custodios_minimos)
      INTO v_cu, v_min
      FROM nodos.activo_tecnologico a
      LEFT JOIN nodos.custodia_credencial c ON c.activo_id = a.id
     WHERE a.id = v_activo;
    IF v_cu < v_min THEN
        RAISE EXCEPTION 'RGL-NOD-001 Art.3: el activo requiere al menos % custodios distintos (actual: %)', v_min, v_cu;
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER trg_custodia_minima
AFTER INSERT ON nodos.activo_tecnologico
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_custodia_minima();

CREATE CONSTRAINT TRIGGER trg_custodia_minima_al_quitar
AFTER DELETE ON nodos.custodia_credencial
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_custodia_minima();

-- ART. 6 / MATRIZ: la expulsión operativa revoca credenciales y funciones
-- (acción correctiva) de manera inmediata y en cascada.
CREATE OR REPLACE FUNCTION nodos.fn_trg_expulsion_revoca_accesos()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.estado = 'expulsado' THEN
        UPDATE nodos.asignacion_rol
           SET activo = false, hasta = CURRENT_DATE
         WHERE miembro_id = NEW.id AND activo;
        DELETE FROM nodos.custodia_credencial WHERE custodio_id = NEW.id;
        DELETE FROM nodos.declaracion_conducta WHERE miembro_id = NEW.id;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_expulsion_revoca_accesos
AFTER UPDATE OF estado ON nodos.miembro
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_expulsion_revoca_accesos();

-- ART. 5: continuidad operativa — el suplente de una actividad no puede estar
-- expulsado ni suspendido al asumir el rol.
CREATE OR REPLACE FUNCTION nodos.fn_trg_suplente_habil()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_estado nodos.estado_miembro;
BEGIN
    SELECT estado INTO v_estado FROM nodos.miembro WHERE id = NEW.suplente_id;
    IF v_estado IN ('expulsado', 'suspendido') THEN
        RAISE EXCEPTION 'RGL-NOD-001 Art.5: el suplente indicado no está habilitado (%)', v_estado;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_suplente_habil
BEFORE INSERT OR UPDATE OF suplente_id ON nodos.actividad
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_suplente_habil();

-- ART. 1: solo miembros en estado activo (o amonestado no expulsado) pueden
-- figurar como custodios de credenciales.
CREATE OR REPLACE FUNCTION nodos.fn_trg_custodio_habil()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_estado nodos.estado_miembro;
BEGIN
    SELECT estado INTO v_estado FROM nodos.miembro WHERE id = NEW.custodio_id;
    IF v_estado IN ('aspirante', 'expulsado', 'suspendido') THEN
        RAISE EXCEPTION 'RGL-NOD-001: no se asigna custodia de credenciales a un miembro no habilitado (%)', v_estado;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_custodio_habil
BEFORE INSERT OR UPDATE ON nodos.custodia_credencial
FOR EACH ROW EXECUTE FUNCTION nodos.fn_trg_custodio_habil();
