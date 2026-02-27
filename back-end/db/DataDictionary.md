-- ============================================================
--  CampusLend - Diccionario de Datos
--  Universidad Cooperativa de Colombia (UCC)
--  Versión: 1.0
-- ============================================================

/*
=====================================================================
DICCIONARIO DE DATOS - CAMPUSLEND
=====================================================================

SISTEMA        : CampusLend
EMPRESA        : Universidad Cooperativa de Colombia (UCC)
ÁREA           : DTI - Departamento de Tecnología de la Información
SGBD           : PostgreSQL (Neon Cloud)
NORMALIZACIÓN  : Tercera Forma Normal (3FN)
FECHA          : 2026
=====================================================================


=====================================================================
TABLA: empleado
Propósito: Personal del DTI y administradores con acceso al sistema
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_empleado           SERIAL            NO     PK     Identificador único autoincremental
numero_identificacion VARCHAR(20)       NO     UQ     Cédula o documento de identidad
nombre_completo       VARCHAR(150)      NO            Nombre y apellidos del empleado
correo_institucional  VARCHAR(100)      NO     UQ     Correo @ucc.edu.co (validado)
contrasena_hash       VARCHAR(255)      NO            Contraseña cifrada con BCrypt
rol                   ENUM              NO            ADMINISTRADOR | DTI
departamento          VARCHAR(100)      NO            Área o departamento asignado
telefono              VARCHAR(20)       SÍ            Número de contacto
estado                ENUM              NO            ACTIVO | INACTIVO
fecha_ingreso         DATE              NO            Fecha de vinculación institucional
created_at            TIMESTAMPTZ       NO            Fecha de creación del registro
updated_at            TIMESTAMPTZ       NO            Fecha de última modificación

RESTRICCIONES:
- correo_institucional debe contener '@ucc.edu.co'
- No se puede eliminar: se cambia estado a INACTIVO
- No se puede desactivar el último ADMINISTRADOR activo
- El hash BCrypt se genera en la capa de aplicación (Spring Security)

RELACIONES SALIENTES:
- empleado.id_empleado → prestamo.id_empleado_registra
- empleado.id_empleado → auditoria.id_empleado


=====================================================================
TABLA: estudiante
Propósito: Usuarios que realizan reservas y solicitan préstamos
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_estudiante         SERIAL            NO     PK     Identificador único autoincremental
numero_identificacion VARCHAR(20)       NO     UQ     Cédula o documento de identidad
nombre_completo       VARCHAR(150)      NO            Nombre y apellidos del estudiante
correo_institucional  VARCHAR(100)      NO     UQ     Correo @campusucc.edu.co (validado)
contrasena_hash       VARCHAR(255)      NO            Contraseña cifrada con BCrypt
programa_academico    VARCHAR(150)      NO            Carrera o programa cursado
semestre              SMALLINT          NO            Semestre actual (1-12)
estado_academico      ENUM              NO            ACTIVO | INACTIVO
multas_pendientes     NUMERIC(10,2)     NO            Suma de multas sin pagar (calculado)
created_at            TIMESTAMPTZ       NO            Fecha de creación del registro
updated_at            TIMESTAMPTZ       NO            Fecha de última modificación

RESTRICCIONES:
- correo_institucional debe contener '@campusucc.edu.co'
- semestre entre 1 y 12
- multas_pendientes >= 0 (calculado automáticamente por trigger)
- No se puede desactivar con préstamos activos pendientes
- Los estudiantes no pueden modificar sus propios datos

RELACIONES SALIENTES:
- estudiante.id_estudiante → reserva.id_estudiante
- estudiante.id_estudiante → prestamo.id_estudiante
- estudiante.id_estudiante → multa.id_estudiante
- estudiante.id_estudiante → auditoria.id_estudiante


=====================================================================
TABLA: sala
Propósito: Salas de estudio y trabajo disponibles para reserva
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_sala               SERIAL            NO     PK     Identificador único autoincremental
nombre                VARCHAR(100)      NO            Nombre descriptivo de la sala
torre                 VARCHAR(50)       NO            Torre o bloque del edificio
piso                  SMALLINT          NO            Número de piso (0 = planta baja)
numero_sala           VARCHAR(20)       NO            Número o código de la sala
capacidad_maxima      SMALLINT          NO            Aforo máximo de personas
horario_inicio        TIME              NO            Hora de apertura (ej: 07:00)
horario_fin           TIME              NO            Hora de cierre (ej: 22:00)
estado                ENUM              NO            DISPONIBLE | MANTENIMIENTO | INACTIVO
created_at            TIMESTAMPTZ       NO            Fecha de creación del registro
updated_at            TIMESTAMPTZ       NO            Fecha de última modificación

RESTRICCIONES:
- (torre, piso, numero_sala) debe ser UNIQUE (ubicación irrepetible)
- capacidad_maxima > 0
- horario_fin > horario_inicio
- No se puede desactivar con reservas activas en las próximas 24 horas
- Las salas SOLO se reservan, no se prestan directamente

RELACIONES SALIENTES:
- sala.id_sala → reserva.id_sala
- sala.id_sala → sala_equipamiento.id_sala


=====================================================================
TABLA: sala_equipamiento
Propósito: Inventario de recursos físicos disponibles en cada sala
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_equipamiento       SERIAL            NO     PK     Identificador único autoincremental
id_sala               INTEGER           NO     FK     Referencia a sala
tipo                  ENUM              NO            PROYECTOR | TABLERO | COMPUTADORES
| AIRE_ACONDICIONADO | VIDEOBEAM
| TELEVISOR | OTRO
cantidad              SMALLINT          NO            Número de unidades disponibles
observaciones         TEXT              SÍ            Notas adicionales del equipamiento

RESTRICCIONES:
- (id_sala, tipo) UNIQUE: no se repite el mismo tipo en una sala
- cantidad > 0
- Se elimina en cascada si se elimina la sala (operación no habitual)


=====================================================================
TABLA: computadora
Propósito: Portátiles del DTI disponibles para préstamo o reserva
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_computadora        SERIAL            NO     PK     Identificador único autoincremental
codigo_inventario     VARCHAR(50)       NO     UQ     Código físico de inventario (etiqueta)
modelo                VARCHAR(100)      NO            Modelo del equipo (ej: ThinkPad E14)
marca                 VARCHAR(100)      NO            Fabricante (ej: Lenovo, HP, Dell)
procesador            VARCHAR(100)      NO            CPU del equipo (ej: Intel Core i5-12th)
ram_gb                SMALLINT          NO            Memoria RAM en gigabytes
almacenamiento_gb     INTEGER           NO            Almacenamiento en gigabytes
codigo_qr             VARCHAR(255)      SÍ     UQ     QR o código de barras generado
estado                ENUM              NO            DISPONIBLE | EN_PRESTAMO
| MANTENIMIENTO | INACTIVO
fecha_adquisicion     DATE              NO            Fecha de compra o ingreso al inventario
observaciones         TEXT              SÍ            Notas (ej: falla en teclado, rayón)
created_at            TIMESTAMPTZ       NO            Fecha de creación del registro
updated_at            TIMESTAMPTZ       NO            Fecha de última modificación

RESTRICCIONES:
- No se puede cambiar a INACTIVO/MANTENIMIENTO si estado = EN_PRESTAMO (trigger)
- Al crear un préstamo: estado cambia automáticamente a EN_PRESTAMO (trigger)
- Al devolver un préstamo: estado vuelve a DISPONIBLE (trigger)
- ram_gb > 0 y almacenamiento_gb > 0

RELACIONES SALIENTES:
- computadora.id_computadora → reserva.id_computadora
- computadora.id_computadora → prestamo.id_computadora


=====================================================================
TABLA: reserva
Propósito: Reservas de salas o computadoras realizadas por estudiantes
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_reserva            SERIAL            NO     PK     Identificador único autoincremental
id_estudiante         INTEGER           NO     FK     Estudiante que realiza la reserva
tipo_recurso          ENUM              NO            SALA | COMPUTADORA
id_sala               INTEGER           SÍ     FK     Sala reservada (si tipo = SALA)
id_computadora        INTEGER           SÍ     FK     Equipo reservado (si tipo = COMPUTADORA)
fecha_reserva         DATE              NO            Fecha del uso reservado
hora_inicio           TIME              NO            Hora de inicio del uso
hora_fin              TIME              NO            Hora de fin del uso
estado                ENUM              NO            ACTIVA | CANCELADA | COMPLETADA
| CONVERTIDA_A_PRESTAMO
motivo_cancelacion    TEXT              SÍ            Razón si el estado es CANCELADA
created_at            TIMESTAMPTZ       NO            Fecha de creación del registro
updated_at            TIMESTAMPTZ       NO            Fecha de última modificación

RESTRICCIONES:
- Si tipo_recurso = SALA:        id_sala NOT NULL  y id_computadora NULL
- Si tipo_recurso = COMPUTADORA: id_computadora NOT NULL y id_sala NULL
- hora_fin > hora_inicio
- No puede haber dos reservas ACTIVAS para el mismo recurso en el mismo
  horario (índices únicos parciales)
- CONVERTIDA_A_PRESTAMO: solo aplica a reservas de tipo COMPUTADORA

RELACIONES SALIENTES:
- reserva.id_reserva → prestamo.id_reserva (1:1, el préstamo puede venir de reserva)


=====================================================================
TABLA: prestamo
Propósito: Préstamos físicos de computadoras a estudiantes
=====================================================================

COLUMNA                  TIPO              NULL   CLAVE  DESCRIPCIÓN
-----------------------  ----------------  -----  -----  ----------------------------------
id_prestamo              SERIAL            NO     PK     Identificador único autoincremental
id_estudiante            INTEGER           NO     FK     Estudiante que recibe el equipo
id_computadora           INTEGER           NO     FK     Equipo entregado en préstamo
id_empleado_registra     INTEGER           NO     FK     Empleado DTI que registra la entrega
id_reserva               INTEGER           SÍ     FK/UQ  Reserva previa (NULL = préstamo directo)
fecha_solicitud          TIMESTAMPTZ       NO            Momento exacto de entrega del equipo
fecha_entrega_esperada   TIMESTAMPTZ       NO            Fecha/hora límite de devolución
fecha_devolucion_real    TIMESTAMPTZ       SÍ            Fecha/hora real de devolución
estado                   ENUM              NO            ACTIVO | DEVUELTO | VENCIDO
observaciones            TEXT              SÍ            Notas del estado físico al entregar
created_at               TIMESTAMPTZ       NO            Fecha de creación del registro
updated_at               TIMESTAMPTZ       NO            Fecha de última modificación

RESTRICCIONES:
- fecha_entrega_esperada > fecha_solicitud
- fecha_devolucion_real >= fecha_solicitud (cuando no es NULL)
- id_reserva es UNIQUE: una reserva solo puede generar un préstamo
- Al insertar: trigger cambia computadora.estado a EN_PRESTAMO
- Al cambiar estado a DEVUELTO: trigger cambia computadora.estado a DISPONIBLE
- Si la devolución es tardía: se debe generar una multa (lógica en aplicación)


=====================================================================
TABLA: multa
Propósito: Sanciones económicas por incumplimiento en préstamos
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_multa              SERIAL            NO     PK     Identificador único autoincremental
id_estudiante         INTEGER           NO     FK     Estudiante sancionado
id_prestamo           INTEGER           SÍ     FK     Préstamo que originó la multa
monto                 NUMERIC(10,2)     NO            Valor monetario de la multa (> 0)
motivo                TEXT              NO            Descripción del incumplimiento
estado                ENUM              NO            PENDIENTE | PAGADA
fecha_generacion      TIMESTAMPTZ       NO            Fecha en que se generó la multa
fecha_pago            TIMESTAMPTZ       SÍ            Fecha en que se registró el pago

RESTRICCIONES:
- monto > 0
- fecha_pago >= fecha_generacion (cuando no es NULL)
- Al insertar/actualizar: trigger recalcula estudiante.multas_pendientes
- Un estudiante con multas_pendientes > 0 puede tener restricciones
  en nuevas reservas/préstamos (lógica en capa de aplicación)


=====================================================================
TABLA: auditoria
Propósito: Log inmutable de todas las operaciones críticas del sistema
=====================================================================

COLUMNA               TIPO              NULL   CLAVE  DESCRIPCIÓN
--------------------  ----------------  -----  -----  ----------------------------------
id_auditoria          BIGSERIAL         NO     PK     Identificador único autoincremental
tabla_afectada        VARCHAR(100)      NO            Nombre de la tabla modificada
id_registro           INTEGER           SÍ            ID del registro afectado
accion                ENUM              NO            INSERT | UPDATE | DELETE
| DEACTIVATE | LOGIN | LOGOUT
id_empleado           INTEGER           SÍ     FK     Empleado que realizó la acción
id_estudiante         INTEGER           SÍ     FK     Estudiante que realizó la acción
rol_usuario           VARCHAR(50)       SÍ            Rol en el momento de la acción
datos_anteriores      JSONB             SÍ            Snapshot del registro antes del cambio
datos_nuevos          JSONB             SÍ            Snapshot del registro después del cambio
ip_origen             INET              SÍ            IP desde donde se realizó la operación
fecha_hora            TIMESTAMPTZ       NO            Timestamp exacto de la operación

RESTRICCIONES:
- Tabla de solo escritura: NO se permite UPDATE ni DELETE (política de negocio)
- Al menos uno de id_empleado o id_estudiante debe tener valor
- Implementar via Spring AOP o interceptores en capa de aplicación
- Para acciones de LOGIN/LOGOUT: id_registro puede ser NULL


=====================================================================
RESUMEN DE RELACIONES
=====================================================================

TABLA ORIGEN          FK                    TABLA DESTINO         CARDINALIDAD
--------------------  --------------------  --------------------  ------------
prestamo              id_estudiante         estudiante            N:1
prestamo              id_computadora        computadora           N:1
prestamo              id_empleado_registra  empleado              N:1
prestamo              id_reserva            reserva               1:1 (opcional)
reserva               id_estudiante         estudiante            N:1
reserva               id_sala               sala                  N:1 (opcional)
reserva               id_computadora        computadora           N:1 (opcional)
multa                 id_estudiante         estudiante            N:1
multa                 id_prestamo           prestamo              N:1 (opcional)
sala_equipamiento     id_sala               sala                  N:1
auditoria             id_empleado           empleado              N:1 (opcional)
auditoria             id_estudiante         estudiante            N:1 (opcional)


=====================================================================
TIPOS ENUMERADOS DEFINIDOS
=====================================================================

ENUM                  VALORES
--------------------  --------------------------------------------------
rol_empleado          ADMINISTRADOR, DTI
estado_general        ACTIVO, INACTIVO
estado_sala           DISPONIBLE, MANTENIMIENTO, INACTIVO
estado_computadora    DISPONIBLE, EN_PRESTAMO, MANTENIMIENTO, INACTIVO
estado_reserva        ACTIVA, CANCELADA, COMPLETADA, CONVERTIDA_A_PRESTAMO
estado_prestamo       ACTIVO, DEVUELTO, VENCIDO
estado_multa          PENDIENTE, PAGADA
tipo_equipamiento     PROYECTOR, TABLERO, COMPUTADORES, AIRE_ACONDICIONADO,
VIDEOBEAM, TELEVISOR, OTRO
accion_auditoria      INSERT, UPDATE, DELETE, DEACTIVATE, LOGIN, LOGOUT
tipo_recurso          SALA, COMPUTADORA


=====================================================================
TRIGGERS DEFINIDOS
=====================================================================

TRIGGER                         TABLA         EVENTO         FUNCIÓN ASOCIADA
------------------------------  ------------  -------------  ---------------------------
trg_empleado_updated_at         empleado      BEFORE UPDATE  fn_set_updated_at()
trg_estudiante_updated_at       estudiante    BEFORE UPDATE  fn_set_updated_at()
trg_sala_updated_at             sala          BEFORE UPDATE  fn_set_updated_at()
trg_computadora_updated_at      computadora   BEFORE UPDATE  fn_set_updated_at()
trg_reserva_updated_at          reserva       BEFORE UPDATE  fn_set_updated_at()
trg_prestamo_updated_at         prestamo      BEFORE UPDATE  fn_set_updated_at()
trg_sync_multas                 multa         AFTER INS/UPD  fn_sync_multas_pendientes()
trg_prestamo_insert             prestamo      AFTER INSERT   fn_convertir_reserva_a_prestamo()
trg_prestamo_devolucion         prestamo      AFTER UPDATE   fn_devolver_prestamo()
trg_computadora_estado_check    computadora   BEFORE UPDATE  fn_validar_computadora_libre()
trg_empleado_ultimo_admin       empleado      BEFORE UPDATE  fn_validar_ultimo_admin()


=====================================================================
VISTAS DEFINIDAS
=====================================================================

VISTA                         DESCRIPCIÓN
----------------------------  ------------------------------------------
v_computadoras_disponibles    Equipos con estado = DISPONIBLE
v_salas_disponibles           Salas activas con equipamiento agregado JSON
v_prestamos_activos           Préstamos en curso con info de estudiante y equipo
v_reservas_hoy                Reservas activas del día actual
v_estudiantes_con_multas      Estudiantes con saldo pendiente de multas


=====================================================================
FLUJOS PRINCIPALES SOPORTADOS
=====================================================================

FLUJO 1 - Préstamo directo de computadora (sin reserva previa)
1. Empleado DTI crea registro en PRESTAMO
2. id_reserva = NULL
3. Trigger → computadora.estado = EN_PRESTAMO
4. Al devolver → PRESTAMO.estado = DEVUELTO
5. Trigger → computadora.estado = DISPONIBLE
6. Si devolución tardía → crear MULTA (aplicación)

FLUJO 2 - Reserva de computadora → préstamo posterior
1. Estudiante crea RESERVA (tipo_recurso = COMPUTADORA, estado = ACTIVA)
2. Estudiante llega → Empleado crea PRESTAMO con id_reserva
3. Trigger → RESERVA.estado = CONVERTIDA_A_PRESTAMO
4. Trigger → computadora.estado = EN_PRESTAMO
5. Al devolver → igual que Flujo 1 desde paso 4

FLUJO 3 - Reserva de sala
1. Estudiante crea RESERVA (tipo_recurso = SALA, estado = ACTIVA)
2. No genera PRESTAMO
3. Al cumplir el horario → RESERVA.estado = COMPLETADA (aplicación)
4. Si no asiste → RESERVA.estado = CANCELADA (aplicación/manual)
   */