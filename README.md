# CampusLend
SaaS web system that automates the management of equipment and room loans in university institutions, replacing manual Excel-based processes with a real-time solution that includes inventory control, penalty validation, and automatic detection of overdue items.


#  Entidad-Relación del Sistema de Préstamos

INSTITUCION
-----------




- institucion_id (PK)
- nombre (UNIQUE)
- sigla (UNIQUE)
- ciudad
- pais
- estado_suscripcion
- plan
- fecha_inicio_suscripcion
- fecha_vencimiento_suscripcion

USUARIO
-------
- usuario_id (PK)
- email (UNIQUE)
- contraseña_hash
- nombre_completo
- rol
- estado
- institucion_id (FK→INSTITUCION)
- ultimo_login
- intentos_fallidos

ESTUDIANTE

----------
- estudiante_id (PK, FK→USUARIO)
- carnet_numero (UNIQUE)
- numero_cedula (UNIQUE)
- programa_academico
- estado_academico
- multas_totales_pendientes
- numero_atrasos
- total_prestamos

EQUIPO
------
- equipo_id (PK)
- codigo_equipo (UNIQUE)
- nombre
- categoria
- especificaciones_tecnicas (JSON)
- ubicacion_fisica
- estado
- condicion
- institucion_id (FK→INSTITUCION)
- valor_reposicion
- fecha_adquisicion

SALON
-----
- salon_id (PK)
- codigo_salon (UNIQUE)
- nombre
- ubicacion
- capacidad_personas
- equipos_incluidos (JSON)
- horario_disponibilidad_inicio
- horario_disponibilidad_fin
- institucion_id (FK→INSTITUCION)

PRESTAMO
--------
- prestamo_id (PK)
- numero_prestamo (UNIQUE)
- estudiante_id (FK→ESTUDIANTE)
- equipo_id (FK→EQUIPO, NULLABLE)
- salon_id (FK→SALON, NULLABLE)
- reserva_id (FK→RESERVA, NULLABLE)
- fecha_hora_inicio
- fecha_hora_plazo_cierre
- fecha_hora_fin_real
- tipo_prestamo
- estado
- condicion_inicial
- condicion_final
- personal_ti_inicio_id (FK→USUARIO)
- personal_ti_fin_id (FK→USUARIO)
- institucion_id (FK→INSTITUCION)

RESERVA
-------
- reserva_id (PK)
- numero_reserva (UNIQUE)
- estudiante_id (FK→ESTUDIANTE)
- equipo_id (FK→EQUIPO, NULLABLE)
- salon_id (FK→SALON, NULLABLE)
- fecha_inicio_reserva
- fecha_fin_reserva
- estado
- codigo_qr_checkin
- fecha_checkin_real
- institucion_id (FK→INSTITUCION)

SANCION
-------
- sancion_id (PK)
- estudiante_id (FK→ESTUDIANTE)
- razon
- descripcion_razon
- fecha_inicio
- fecha_fin
- duracion_dias
- estado
- usuario_que_la_impuso_id (FK→USUARIO)
- institucion_id (FK→INSTITUCION)

MULTA
-----
- multa_id (PK)
- estudiante_id (FK→ESTUDIANTE)
- prestamo_id (FK→PRESTAMO)
- monto
- razon
- minutos_atraso
- tarifa_por_hora
- estado
- fecha_pago
- metodo_pago
- usuario_que_pago_id (FK→USUARIO)
- institucion_id (FK→INSTITUCION)

REPORTE_DAÑO
-----------
- reporte_daño_id (PK)
- prestamo_id (FK→PRESTAMO)
- equipo_id (FK→EQUIPO)
- estudiante_id (FK→ESTUDIANTE)
- descripcion_daño
- fotos_daño (JSON)
- severidad
- costo_estimado_reparacion
- responsabilidad
- estado_daño
- usuario_que_reporto_id (FK→USUARIO)
- institucion_id (FK→INSTITUCION)

PARAMETRO_SISTEMA
------------------
- parametro_id (PK)
- institucion_id (FK→INSTITUCION)
- clave (UNIQUE con institucion_id)
- valor
- tipo_valor
- es_configurable
- modificado_por_id (FK→USUARIO)

NOTIFICACION
-----------
- notificacion_id (PK)
- estudiante_id (FK→ESTUDIANTE)
- tipo
- asunto
- contenido
- canal
- estado_envio
- fecha_programada
- fecha_envio_real
- institucion_id (FK→INSTITUCION)
- datos_contexto (JSON)

AUDITORIA
---------
- auditoria_id (PK)
- usuario_id (FK→USUARIO)
- tipo_evento
- entidad_afectada
- id_entidad_afectada
- valores_anteriores (JSON)
- valores_nuevos (JSON)
- descripcion
- ip_origen
- resultado
- institucion_id (FK→INSTITUCION)
- fecha_creacion

HISTORIAL_EQUIPO
----------------
- historial_id (PK)
- equipo_id (FK→EQUIPO)
- estado_anterior
- estado_nuevo
- razon_cambio
- usuario_que_cambio_id (FK→USUARIO)
- fecha_cambio
- institucion_id (FK→INSTITUCION)

RELACIONES PRINCIPALES:
INSTITUCION (1) ──→ (N) USUARIO
INSTITUCION (1) ──→ (N) EQUIPO
INSTITUCION (1) ──→ (N) SALON
INSTITUCION (1) ──→ (N) PRESTAMO
INSTITUCION (1) ──→ (N) RESERVA
INSTITUCION (1) ──→ (N) ESTUDIANTE
INSTITUCION (1) ──→ (N) SANCION
INSTITUCION (1) ──→ (N) MULTA

USUARIO (1) ──────────→ (N) USUARIO (creado_por)
USUARIO (1) ──────────→ (N) PRESTAMO (personal_ti_inicio)
USUARIO (1) ──────────→ (N) PRESTAMO (personal_ti_fin)
USUARIO (1) ──────────→ (N) SANCION
USUARIO (1) ──────────→ (N) MULTA
USUARIO (1) ──────────→ (N) AUDITORIA
USUARIO (1) ──────────→ (N) REPORTE_DAÑO

ESTUDIANTE (1) ────────→ (N) PRESTAMO
ESTUDIANTE (1) ────────→ (N) RESERVA
ESTUDIANTE (1) ────────→ (N) SANCION
ESTUDIANTE (1) ────────→ (N) MULTA
ESTUDIANTE (1) ────────→ (N) NOTIFICACION
ESTUDIANTE (1) ────────→ (N) REPORTE_DAÑO

EQUIPO (1) ──────────→ (N) PRESTAMO
EQUIPO (1) ──────────→ (N) RESERVA
EQUIPO (1) ──────────→ (N) REPORTE_DAÑO
EQUIPO (1) ──────────→ (N) HISTORIAL_EQUIPO

SALON (1) ──────────→ (N) PRESTAMO
SALON (1) ──────────→ (N) RESERVA

PRESTAMO (1) ───────→ (N) MULTA
PRESTAMO (1) ───────→ (N) REPORTE_DAÑO
PRESTAMO (1) ───────→ (1) RESERVA (opcional)

RESERVA (1) ────────→ (1) PRESTAMO (cuando check-in)