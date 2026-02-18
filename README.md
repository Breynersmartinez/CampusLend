# Entidades y Atributos - Sistema CampusLend
## Préstamo y Reserva de Salas y Computadores Portátiles

---

## 1. EMPLEADO
**Descripción:** Usuarios administradores y personal de TI que gestionan el sistema

### Atributos:
- ID_Empleado (PK)
- Numero_Identificacion (UNIQUE)
- Nombre
- Correo_Institucional (UNIQUE, dominio @ucc.edu.co)
- Contraseña (encriptada)
- Rol (Administrador, Personal_TI)
- Departamento
- Numero_Telefonico
- Estado (Activo, Inactivo)
- Fecha_Ingreso
- Fecha_Desactivacion (nullable)
- Motivo_Desactivacion (nullable)

---

## 2. ESTUDIANTE
**Descripción:** Usuarios que realizan préstamos de computadores y reservas de salas

### Atributos:
- ID_Estudiante (PK)
- Numero_Identificacion (UNIQUE)
- Nombre
- Correo_Institucional (UNIQUE, dominio @campusucc.edu.co)
- Contraseña (encriptada)
- Programa_Academico
- Semestre
- Estado_Academico (Activo, Inactivo)
- Multas_Totales_Pendientes
- Estado (Activo, Inactivo)
- Fecha_Registro
- Fecha_Desactivacion (nullable)
- Historial_Prestamos (relación)

---

## 3. SALA
**Descripción:** Espacios de estudio o trabajo disponibles para reserva

### Atributos:
- ID_Sala (PK)
- Nombre
- Torre
- Piso
- Numero_Sala
- Capacidad_Maxima
- Equipamiento (Proyector, Tablero, Computadores, etc.)
- Horario_Disponibilidad_Inicio (hora)
- Horario_Disponibilidad_Fin (hora)
- Estado (Disponible, Mantenimiento, Inactivo)
- Responsable (nullable, FK a Empleado)
- Fecha_Registro
- Ubicacion_Unica (validación)

---

## 4. COMPUTADORA (Portátil)
**Descripción:** Equipos portátiles disponibles para préstamo

### Atributos:
- ID_Computadora (PK)
- Numero_Serie (UNIQUE)
- Modelo
- Marca
- Especificaciones_Tecnicas (RAM, Almacenamiento, Procesador)
- Estado (Disponible, Prestado, Mantenimiento, Inactivo)
- Responsable_Actual (nullable, FK a Estudiante)
- Fecha_Registro
- Fecha_Mantenimiento_Ultimo (nullable)
- Ubicacion_Actual
- Condicion_Fisica (Excelente, Buena, Regular, Mala)

---

## 5. PRESTAMO
**Descripción:** Registro de préstamos de computadoras

### Atributos:
- ID_Prestamo (PK)
- ID_Estudiante (FK)
- ID_Computadora (FK)
- Fecha_Prestamo
- Fecha_Devolucion_Programada
- Fecha_Devolucion_Real (nullable)
- Estado (Activo, Devuelto, Vencido, Cancelado)
- Multa_Generada (si aplica)
- Observaciones (nullable)
- Empleado_Autoriza (FK a Empleado)

---

## 6. RESERVA
**Descripción:** Registro de reservas de salas

### Atributos:
- ID_Reserva (PK)
- ID_Estudiante (FK)
- ID_Sala (FK)
- Fecha_Reserva
- Hora_Inicio
- Hora_Fin
- Estado (Confirmada, Cancelada, Completada, No_Presentado)
- Proposito (opcional)
- Num_Participantes (opcional)
- Fecha_Creacion_Reserva
- Empleado_Autoriza (FK a Empleado, nullable)

---

## 7. MULTA
**Descripción:** Registro de multas por incumplimiento

### Atributos:
- ID_Multa (PK)
- ID_Estudiante (FK)
- ID_Prestamo (FK, nullable)
- Tipo_Multa (Retardo_Devolucion, Daño_Equipo, Otro)
- Monto
- Fecha_Generacion
- Estado (Pendiente, Pagada, Condonada)
- Descripcion
- Fecha_Pago (nullable)

---

## 8. AUDITORIA
**Descripción:** Registro de cambios y operaciones en el sistema

### Atributos:
- ID_Auditoria (PK)
- Tabla_Afectada
- Tipo_Operacion (INSERT, UPDATE, DELETE)
- ID_Registro_Afectado
- Usuario_Realiza (FK a Empleado)
- Fecha_Hora
- Cambios_Realizados (descripción)
- Razon_Cambio (nullable)

---

## 9. ACCESO_SESION
**Descripción:** Registro de accesos al sistema

### Atributos:
- ID_Sesion (PK)
- ID_Usuario (FK, puede ser Estudiante o Empleado)
- Tipo_Usuario (Estudiante, Empleado)
- Fecha_Inicio_Sesion
- Fecha_Cierre_Sesion (nullable)
- Duracion_Sesion
- IP_Acceso
- Dispositivo

---

## RELACIONES IDENTIFICADAS

### EMPLEADO
- 1:N con SALA (responsabiliza salas)
- 1:N con PRESTAMO (autoriza préstamos)
- 1:N con RESERVA (autoriza reservas)
- 1:N con AUDITORIA (realiza cambios)

### ESTUDIANTE
- 1:N con PRESTAMO (realiza)
- 1:N con RESERVA (realiza)
- 1:N con MULTA (incurre)
- 1:N con ACCESO_SESION (accede)

### SALA
- 1:N con RESERVA (es reservada)
- 0:1 con EMPLEADO (responsable)

### COMPUTADORA
- 1:N con PRESTAMO (es prestada)
- 0:1 con ESTUDIANTE (actualmente prestada a)

### PRESTAMO
- N:1 con ESTUDIANTE
- N:1 con COMPUTADORA
- N:1 con EMPLEADO
- 1:N con MULTA

### RESERVA
- N:1 con ESTUDIANTE
- N:1 con SALA
- N:1 con EMPLEADO (nullable)

### MULTA
- N:1 con ESTUDIANTE
- N:1 con PRESTAMO (nullable)

### AUDITORIA
- N:1 con EMPLEADO

### ACCESO_SESION
- N:1 con ESTUDIANTE o EMPLEADO