

-- EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- para gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- alternativa de UUID


-- TIPOS ENUMERADOS

CREATE TYPE rol_empleado       AS ENUM ('ADMINISTRADOR', 'DTI');
CREATE TYPE estado_general     AS ENUM ('ACTIVO', 'INACTIVO');
CREATE TYPE estado_sala        AS ENUM ('DISPONIBLE', 'MANTENIMIENTO', 'INACTIVO');
CREATE TYPE estado_computadora AS ENUM ('DISPONIBLE', 'EN_PRESTAMO', 'MANTENIMIENTO', 'INACTIVO');
CREATE TYPE estado_reserva     AS ENUM ('ACTIVA', 'CANCELADA', 'COMPLETADA', 'CONVERTIDA_A_PRESTAMO');
CREATE TYPE estado_prestamo    AS ENUM ('ACTIVO', 'DEVUELTO', 'VENCIDO');
CREATE TYPE estado_multa       AS ENUM ('PENDIENTE', 'PAGADA');
CREATE TYPE tipo_equipamiento  AS ENUM ('PROYECTOR', 'TABLERO', 'COMPUTADORES', 'AIRE_ACONDICIONADO', 'VIDEOBEAM', 'TELEVISOR', 'OTRO');
CREATE TYPE accion_auditoria   AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'DEACTIVATE', 'LOGIN', 'LOGOUT');
CREATE TYPE tipo_recurso       AS ENUM ('SALA', 'COMPUTADORA');


-- TABLA: empleado
-- Almacena el personal del DTI y administradores del sistema
CREATE TABLE empleado (
    id_empleado             SERIAL          PRIMARY KEY,
    numero_identificacion   VARCHAR(20)     NOT NULL UNIQUE,
    nombre_completo         VARCHAR(150)    NOT NULL,
    correo_institucional    VARCHAR(100)    NOT NULL UNIQUE
                                CHECK (correo_institucional LIKE '%@ucc.edu.co'),
    contrasena_hash         VARCHAR(255)    NOT NULL,
    rol                     rol_empleado    NOT NULL DEFAULT 'DTI',
    departamento            VARCHAR(100)    NOT NULL,
    telefono                VARCHAR(20),
    estado                  estado_general  NOT NULL DEFAULT 'ACTIVO',
    fecha_ingreso           DATE            NOT NULL DEFAULT CURRENT_DATE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE empleado IS 'Personal del DTI y administradores con acceso al sistema CampusLend';
COMMENT ON COLUMN empleado.contrasena_hash IS 'Contraseña cifrada con BCrypt (Spring Security)';
COMMENT ON COLUMN empleado.rol IS 'ADMINISTRADOR: acceso total | DTI: gestión operativa';


-- TABLA: estudiante
-- Almacena los estudiantes que pueden realizar reservas y préstamos
CREATE TABLE estudiante (
    id_estudiante           SERIAL          PRIMARY KEY,
    numero_identificacion   VARCHAR(20)     NOT NULL UNIQUE,
    nombre_completo         VARCHAR(150)    NOT NULL,
    correo_institucional    VARCHAR(100)    NOT NULL UNIQUE
                                CHECK (correo_institucional LIKE '%@campusucc.edu.co'),
    contrasena_hash         VARCHAR(255)    NOT NULL,
    programa_academico      VARCHAR(150)    NOT NULL,
    semestre                SMALLINT        NOT NULL CHECK (semestre BETWEEN 1 AND 12),
    estado_academico        estado_general  NOT NULL DEFAULT 'ACTIVO',
    multas_pendientes       NUMERIC(10,2)   NOT NULL DEFAULT 0.00
                                CHECK (multas_pendientes >= 0),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE estudiante IS 'Estudiantes registrados que pueden reservar salas o solicitar préstamos de equipos';
COMMENT ON COLUMN estudiante.multas_pendientes IS 'Monto total acumulado de multas sin pagar (calculado)';


-- TABLA: sala
-- Salas de estudio y trabajo disponibles para reserva
CREATE TABLE sala (
    id_sala             SERIAL          PRIMARY KEY,
    nombre              VARCHAR(100)    NOT NULL,
    torre               VARCHAR(50)     NOT NULL,
    piso                SMALLINT        NOT NULL CHECK (piso >= 0),
    numero_sala         VARCHAR(20)     NOT NULL,
    capacidad_maxima    SMALLINT        NOT NULL CHECK (capacidad_maxima > 0),
    horario_inicio      TIME            NOT NULL,
    horario_fin         TIME            NOT NULL CHECK (horario_fin > horario_inicio),
    estado              estado_sala     NOT NULL DEFAULT 'DISPONIBLE',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    UNIQUE (torre, piso, numero_sala)   -- Ubicación única
);

COMMENT ON TABLE sala IS 'Salas de estudio y trabajo disponibles para reserva por estudiantes';
COMMENT ON COLUMN sala.horario_inicio IS 'Hora de apertura de la sala (ej: 07:00)';
COMMENT ON COLUMN sala.horario_fin    IS 'Hora de cierre de la sala (ej: 22:00)';


-- TABLA: sala_equipamiento
-- Equipamiento disponible por sala (relación N:M descompuesta)
CREATE TABLE sala_equipamiento (
    id_equipamiento     SERIAL              PRIMARY KEY,
    id_sala             INTEGER             NOT NULL REFERENCES sala(id_sala) ON DELETE CASCADE,
    tipo                tipo_equipamiento   NOT NULL,
    cantidad            SMALLINT            NOT NULL DEFAULT 1 CHECK (cantidad > 0),
    observaciones       TEXT,

    UNIQUE (id_sala, tipo)
);

COMMENT ON TABLE sala_equipamiento IS 'Inventario de equipamiento disponible en cada sala';


-- TABLA: computadora
-- Equipos portátiles disponibles para préstamo y reserva
CREATE TABLE computadora (
    id_computadora      SERIAL              PRIMARY KEY,
    codigo_inventario   VARCHAR(50)         NOT NULL UNIQUE,
    modelo              VARCHAR(100)        NOT NULL,
    marca               VARCHAR(100)        NOT NULL,
    procesador          VARCHAR(100)        NOT NULL,
    ram_gb              SMALLINT            NOT NULL CHECK (ram_gb > 0),
    almacenamiento_gb   INTEGER             NOT NULL CHECK (almacenamiento_gb > 0),
    codigo_qr           VARCHAR(255)        UNIQUE,
    estado              estado_computadora  NOT NULL DEFAULT 'DISPONIBLE',
    fecha_adquisicion   DATE                NOT NULL,
    observaciones       TEXT,
    created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE computadora IS 'Portátiles del DTI disponibles para préstamo directo o reserva previa';
COMMENT ON COLUMN computadora.codigo_inventario IS 'Código único de inventario físico (etiqueta en el equipo)';
COMMENT ON COLUMN computadora.codigo_qr IS 'Código QR o de barras generado para identificación rápida';


-- TABLA: reserva
-- Reservas de salas o computadoras realizadas por estudiantes
-- Una reserva puede ser de sala O de computadora (nunca ambos)
CREATE TABLE reserva (
    id_reserva          SERIAL          PRIMARY KEY,
    id_estudiante       INTEGER         NOT NULL REFERENCES estudiante(id_estudiante),
    tipo_recurso        tipo_recurso    NOT NULL,
    id_sala             INTEGER         REFERENCES sala(id_sala),
    id_computadora      INTEGER         REFERENCES computadora(id_computadora),
    fecha_reserva       DATE            NOT NULL,
    hora_inicio         TIME            NOT NULL,
    hora_fin            TIME            NOT NULL CHECK (hora_fin > hora_inicio),
    estado              estado_reserva  NOT NULL DEFAULT 'ACTIVA',
    motivo_cancelacion  TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Solo uno de los dos FK puede tener valor según tipo_recurso
    CONSTRAINT chk_recurso_exclusivo CHECK (
        (tipo_recurso = 'SALA'        AND id_sala IS NOT NULL         AND id_computadora IS NULL) OR
        (tipo_recurso = 'COMPUTADORA' AND id_computadora IS NOT NULL  AND id_sala IS NULL)
    )
);

COMMENT ON TABLE reserva IS 'Reservas de salas o computadoras. El tipo_recurso determina cuál FK aplica';
COMMENT ON COLUMN reserva.tipo_recurso IS 'SALA: reserva de espacio físico | COMPUTADORA: reserva de equipo';
COMMENT ON COLUMN reserva.estado IS 'ACTIVA | CANCELADA | COMPLETADA | CONVERTIDA_A_PRESTAMO (solo para computadoras)';


-- Índice para evitar reservas solapadas en la misma sala
CREATE UNIQUE INDEX idx_reserva_sala_sin_solapamiento
    ON reserva (id_sala, fecha_reserva, hora_inicio, hora_fin)
    WHERE estado = 'ACTIVA' AND id_sala IS NOT NULL;

-- Índice para evitar reservas solapadas en la misma computadora
CREATE UNIQUE INDEX idx_reserva_computadora_sin_solapamiento
    ON reserva (id_computadora, fecha_reserva, hora_inicio, hora_fin)
    WHERE estado = 'ACTIVA' AND id_computadora IS NOT NULL;


-- TABLA: prestamo
-- Préstamos de computadoras. Puede originarse de una reserva previa
-- o ser un préstamo directo sin reserva.
CREATE TABLE prestamo (
    id_prestamo             SERIAL          PRIMARY KEY,
    id_estudiante           INTEGER         NOT NULL REFERENCES estudiante(id_estudiante),
    id_computadora          INTEGER         NOT NULL REFERENCES computadora(id_computadora),
    id_empleado_registra    INTEGER         NOT NULL REFERENCES empleado(id_empleado),
    id_reserva              INTEGER         UNIQUE REFERENCES reserva(id_reserva),   -- nullable: préstamo directo
    fecha_solicitud         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    fecha_entrega_esperada  TIMESTAMPTZ     NOT NULL,
    fecha_devolucion_real   TIMESTAMPTZ,
    estado                  estado_prestamo NOT NULL DEFAULT 'ACTIVO',
    observaciones           TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CHECK (fecha_entrega_esperada > fecha_solicitud),
    CHECK (fecha_devolucion_real IS NULL OR fecha_devolucion_real >= fecha_solicitud)
);

COMMENT ON TABLE prestamo IS 'Préstamos de computadoras. id_reserva es NULL si fue un préstamo directo sin reserva previa';
COMMENT ON COLUMN prestamo.id_reserva IS 'FK opcional: si viene de reserva previa, la reserva cambia a CONVERTIDA_A_PRESTAMO';
COMMENT ON COLUMN prestamo.id_empleado_registra IS 'Empleado DTI que entregó físicamente el equipo';


-- TABLA: multa
-- Multas generadas por devolución tardía u otro incumplimiento
CREATE TABLE multa (
    id_multa            SERIAL          PRIMARY KEY,
    id_estudiante       INTEGER         NOT NULL REFERENCES estudiante(id_estudiante),
    id_prestamo         INTEGER         REFERENCES prestamo(id_prestamo),
    monto               NUMERIC(10,2)   NOT NULL CHECK (monto > 0),
    motivo              TEXT            NOT NULL,
    estado              estado_multa    NOT NULL DEFAULT 'PENDIENTE',
    fecha_generacion    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    fecha_pago          TIMESTAMPTZ,

    CHECK (fecha_pago IS NULL OR fecha_pago >= fecha_generacion)
);

COMMENT ON TABLE multa IS 'Multas económicas por incumplimiento en préstamos. Actualiza multas_pendientes en estudiante';


-- TABLA: auditoria
-- Registro inmutable de todas las operaciones críticas del sistema
CREATE TABLE auditoria (
    id_auditoria        BIGSERIAL       PRIMARY KEY,
    tabla_afectada      VARCHAR(100)    NOT NULL,
    id_registro         INTEGER,
    accion              accion_auditoria NOT NULL,
    id_empleado         INTEGER         REFERENCES empleado(id_empleado),   -- nullable si es acción de estudiante
    id_estudiante       INTEGER         REFERENCES estudiante(id_estudiante),
    rol_usuario         VARCHAR(50),
    datos_anteriores    JSONB,
    datos_nuevos        JSONB,
    ip_origen           INET,
    fecha_hora          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE auditoria IS 'Log inmutable de todas las operaciones críticas. Nunca se elimina ni actualiza';
COMMENT ON COLUMN auditoria.datos_anteriores IS 'Estado del registro antes del cambio (JSON)';
COMMENT ON COLUMN auditoria.datos_nuevos     IS 'Estado del registro después del cambio (JSON)';


-- ÍNDICES DE RENDIMIENTO

-- Empleado
CREATE INDEX idx_empleado_correo  ON empleado (correo_institucional);
CREATE INDEX idx_empleado_estado  ON empleado (estado);
CREATE INDEX idx_empleado_rol     ON empleado (rol);

-- Estudiante
CREATE INDEX idx_estudiante_correo        ON estudiante (correo_institucional);
CREATE INDEX idx_estudiante_estado        ON estudiante (estado_academico);
CREATE INDEX idx_estudiante_identificacion ON estudiante (numero_identificacion);

-- Sala
CREATE INDEX idx_sala_estado    ON sala (estado);
CREATE INDEX idx_sala_ubicacion ON sala (torre, piso);

-- Computadora
CREATE INDEX idx_computadora_estado    ON computadora (estado);
CREATE INDEX idx_computadora_codigo    ON computadora (codigo_inventario);

-- Reserva
CREATE INDEX idx_reserva_estudiante     ON reserva (id_estudiante);
CREATE INDEX idx_reserva_sala           ON reserva (id_sala);
CREATE INDEX idx_reserva_computadora    ON reserva (id_computadora);
CREATE INDEX idx_reserva_fecha_estado   ON reserva (fecha_reserva, estado);

-- Prestamo
CREATE INDEX idx_prestamo_estudiante    ON prestamo (id_estudiante);
CREATE INDEX idx_prestamo_computadora   ON prestamo (id_computadora);
CREATE INDEX idx_prestamo_estado        ON prestamo (estado);
CREATE INDEX idx_prestamo_fechas        ON prestamo (fecha_solicitud, fecha_entrega_esperada);

-- Multa
CREATE INDEX idx_multa_estudiante ON multa (id_estudiante);
CREATE INDEX idx_multa_estado     ON multa (estado);

-- Auditoría
CREATE INDEX idx_auditoria_tabla    ON auditoria (tabla_afectada);
CREATE INDEX idx_auditoria_fecha    ON auditoria (fecha_hora DESC);
CREATE INDEX idx_auditoria_empleado ON auditoria (id_empleado);

/*
-- FUNCIÓN: actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers updated_at
CREATE TRIGGER trg_empleado_updated_at
    BEFORE UPDATE ON empleado
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_estudiante_updated_at
    BEFORE UPDATE ON estudiante
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_sala_updated_at
    BEFORE UPDATE ON sala
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_computadora_updated_at
    BEFORE UPDATE ON computadora
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_reserva_updated_at
    BEFORE UPDATE ON reserva
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_prestamo_updated_at
    BEFORE UPDATE ON prestamo
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- FUNCIÓN: sincronizar multas_pendientes en estudiante
-- Se ejecuta al insertar o actualizar una multa
CREATE OR REPLACE FUNCTION fn_sync_multas_pendientes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE estudiante
    SET multas_pendientes = (
        SELECT COALESCE(SUM(monto), 0)
        FROM multa
        WHERE id_estudiante = NEW.id_estudiante
          AND estado = 'PENDIENTE'
    )
    WHERE id_estudiante = NEW.id_estudiante;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_multas
    AFTER INSERT OR UPDATE ON multa
    FOR EACH ROW EXECUTE FUNCTION fn_sync_multas_pendientes();


-- FUNCIÓN: al crear préstamo desde reserva, marcar la reserva
CREATE OR REPLACE FUNCTION fn_convertir_reserva_a_prestamo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_reserva IS NOT NULL THEN
        UPDATE reserva
        SET estado = 'CONVERTIDA_A_PRESTAMO'
        WHERE id_reserva = NEW.id_reserva;
    END IF;

    -- Cambiar estado de la computadora a EN_PRESTAMO
    UPDATE computadora
    SET estado = 'EN_PRESTAMO'
    WHERE id_computadora = NEW.id_computadora;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prestamo_insert
    AFTER INSERT ON prestamo
    FOR EACH ROW EXECUTE FUNCTION fn_convertir_reserva_a_prestamo();


-- FUNCIÓN: al devolver préstamo, liberar la computadora
CREATE OR REPLACE FUNCTION fn_devolver_prestamo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado = 'DEVUELTO' AND OLD.estado = 'ACTIVO' THEN
        UPDATE computadora
        SET estado = 'DISPONIBLE'
        WHERE id_computadora = NEW.id_computadora;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prestamo_devolucion
    AFTER UPDATE ON prestamo
    FOR EACH ROW EXECUTE FUNCTION fn_devolver_prestamo();


-- FUNCIÓN: validar que no exista préstamo activo antes de
-- desactivar o cambiar estado de una computadora
-- (Se recomienda validar también en la capa de aplicación)
CREATE OR REPLACE FUNCTION fn_validar_computadora_libre()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado IN ('INACTIVO', 'MANTENIMIENTO') AND OLD.estado = 'EN_PRESTAMO' THEN
        RAISE EXCEPTION 'No se puede cambiar el estado de una computadora con préstamo activo (id: %)', OLD.id_computadora;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_computadora_estado_check
    BEFORE UPDATE ON computadora
    FOR EACH ROW EXECUTE FUNCTION fn_validar_computadora_libre();


-- FUNCIÓN: validar que no quede el sistema sin administrador

CREATE OR REPLACE FUNCTION fn_validar_ultimo_admin()
RETURNS TRIGGER AS $$
DECLARE
    total_admins INTEGER;
BEGIN
    IF NEW.estado = 'INACTIVO' AND OLD.estado = 'ACTIVO' AND NEW.rol = 'ADMINISTRADOR' THEN
        SELECT COUNT(*) INTO total_admins
        FROM empleado
        WHERE rol = 'ADMINISTRADOR' AND estado = 'ACTIVO';

        IF total_admins <= 1 THEN
            RAISE EXCEPTION 'No se puede desactivar el único administrador activo del sistema';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_empleado_ultimo_admin
    BEFORE UPDATE ON empleado
    FOR EACH ROW EXECUTE FUNCTION fn_validar_ultimo_admin();

*/

-- VISTAS 

-- Computadoras disponibles para préstamo/reserva
CREATE VIEW v_computadoras_disponibles AS
SELECT id_computadora, codigo_inventario, marca, modelo,
       procesador, ram_gb, almacenamiento_gb
FROM computadora
WHERE estado = 'DISPONIBLE';

-- Salas disponibles (con equipamiento como JSON)
CREATE VIEW v_salas_disponibles AS
SELECT s.id_sala, s.nombre, s.torre, s.piso, s.numero_sala,
       s.capacidad_maxima, s.horario_inicio, s.horario_fin,
       JSON_AGG(JSON_BUILD_OBJECT('tipo', e.tipo, 'cantidad', e.cantidad)) AS equipamiento
FROM sala s
LEFT JOIN sala_equipamiento e USING (id_sala)
WHERE s.estado = 'DISPONIBLE'
GROUP BY s.id_sala;

-- Préstamos activos con datos del estudiante y equipo
CREATE VIEW v_prestamos_activos AS
SELECT p.id_prestamo,
       est.nombre_completo AS estudiante,
       est.correo_institucional AS correo_estudiante,
       c.codigo_inventario, c.marca, c.modelo,
       emp.nombre_completo AS empleado_registro,
       p.fecha_solicitud,
       p.fecha_entrega_esperada,
       p.id_reserva
FROM prestamo p
JOIN estudiante est USING (id_estudiante)
JOIN computadora c   USING (id_computadora)
JOIN empleado emp    ON emp.id_empleado = p.id_empleado_registra
WHERE p.estado = 'ACTIVO';

-- Reservas activas del día
CREATE VIEW v_reservas_hoy AS
SELECT r.id_reserva, r.tipo_recurso,
       est.nombre_completo AS estudiante,
       s.nombre AS sala, s.torre, s.piso,
       c.codigo_inventario, c.marca,
       r.hora_inicio, r.hora_fin, r.estado
FROM reserva r
JOIN estudiante est USING (id_estudiante)
LEFT JOIN sala s         USING (id_sala)
LEFT JOIN computadora c  USING (id_computadora)
WHERE r.fecha_reserva = CURRENT_DATE
  AND r.estado = 'ACTIVA';

-- Estudiantes con multas pendientes
CREATE VIEW v_estudiantes_con_multas AS
SELECT e.id_estudiante, e.nombre_completo,
       e.correo_institucional, e.multas_pendientes
FROM estudiante e
WHERE e.multas_pendientes > 0
ORDER BY e.multas_pendientes DESC;



-- DATOS INICIALES: Admin por defecto
-- IMPORTANTE: cambiar la contraseña en el primer acceso
-- Hash BCrypt de ejemplo para 'Admin@2026!'

INSERT INTO empleado (
    numero_identificacion,
    nombre_completo,
    correo_institucional,
    contrasena_hash,
    rol,
    departamento,
    estado,
    fecha_ingreso
) VALUES (
    '00000001',
    'Administrador DTI',
    'admin.dti@ucc.edu.co',
    '$2a$12$PLACEHOLDER_HASH_CAMBIAR_EN_PRIMER_USO',
    'ADMINISTRADOR',
    'DTI',
    'ACTIVO',
    CURRENT_DATE
);