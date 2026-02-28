-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- UUID alternative


-- ENUMERATED TYPES

CREATE TYPE employee_role       AS ENUM ('ADMINISTRATOR', 'IT_STAFF');
CREATE TYPE general_status      AS ENUM ('ACTIVE', 'INACTIVE');
CREATE TYPE room_status         AS ENUM ('AVAILABLE', 'MAINTENANCE', 'INACTIVE');
CREATE TYPE computer_status     AS ENUM ('AVAILABLE', 'ON_LOAN', 'MAINTENANCE', 'INACTIVE');
CREATE TYPE reservation_status  AS ENUM ('ACTIVE', 'CANCELLED', 'COMPLETED', 'CONVERTED_TO_LOAN');
CREATE TYPE loan_status         AS ENUM ('ACTIVE', 'RETURNED', 'OVERDUE');
CREATE TYPE fine_status         AS ENUM ('PENDING', 'PAID');
CREATE TYPE equipment_type      AS ENUM ('PROJECTOR', 'WHITEBOARD', 'COMPUTERS', 'AIR_CONDITIONING', 'VIDEOBEAM', 'TELEVISION', 'OTHER');
CREATE TYPE audit_action        AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'DEACTIVATE', 'LOGIN', 'LOGOUT');
CREATE TYPE resource_type       AS ENUM ('ROOM', 'COMPUTER');


-- TABLE: employee
-- Stores IT personnel and system administrators
CREATE TABLE employee (
    id_employee             SERIAL          PRIMARY KEY,
    identification_number   VARCHAR(20)     NOT NULL UNIQUE,
    full_name               VARCHAR(150)    NOT NULL,
    institutional_email     VARCHAR(100)    NOT NULL UNIQUE
                                CHECK (institutional_email LIKE '%@ucc.edu.co'),
    password_hash           VARCHAR(255)    NOT NULL,
    role                    employee_role   NOT NULL DEFAULT 'IT_STAFF',
    department              VARCHAR(100)    NOT NULL,
    phone                   VARCHAR(20),
    status                  general_status  NOT NULL DEFAULT 'ACTIVE',
    hire_date               DATE            NOT NULL DEFAULT CURRENT_DATE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE employee IS 'IT personnel and administrators with access to the CampusLend system';
COMMENT ON COLUMN employee.password_hash IS 'Password encrypted with BCrypt (Spring Security)';
COMMENT ON COLUMN employee.role IS 'ADMINISTRATOR: full access | IT_STAFF: operational management';


-- TABLE: student
-- Stores students who can make reservations and loans
CREATE TABLE student (
    id_student              SERIAL          PRIMARY KEY,
    identification_number   VARCHAR(20)     NOT NULL UNIQUE,
    full_name               VARCHAR(150)    NOT NULL,
    institutional_email     VARCHAR(100)    NOT NULL UNIQUE
                                CHECK (institutional_email LIKE '%@campusucc.edu.co'),
    password_hash           VARCHAR(255)    NOT NULL,
    academic_program        VARCHAR(150)    NOT NULL,
    semester                SMALLINT        NOT NULL CHECK (semester BETWEEN 1 AND 12),
    academic_status         general_status  NOT NULL DEFAULT 'ACTIVE',
    pending_fines           NUMERIC(10,2)   NOT NULL DEFAULT 0.00
                                CHECK (pending_fines >= 0),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE student IS 'Registered students who can reserve rooms or request equipment loans';
COMMENT ON COLUMN student.pending_fines IS 'Total accumulated amount of unpaid fines (calculated)';


-- TABLE: room
-- Study and work rooms available for reservation
CREATE TABLE room (
    id_room             SERIAL          PRIMARY KEY,
    name                VARCHAR(100)    NOT NULL,
    building            VARCHAR(50)     NOT NULL, -- torre
    floor               SMALLINT        NOT NULL CHECK (floor >= 0), -- piso
    room_number         VARCHAR(20)     NOT NULL, -- numero salon
    max_capacity        SMALLINT        NOT NULL CHECK (max_capacity > 0), -- capacidad maxima
    opening_time        TIME            NOT NULL,
    closing_time        TIME            NOT NULL CHECK (closing_time > opening_time),
    status              room_status     NOT NULL DEFAULT 'AVAILABLE', -- estado
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    UNIQUE (building, floor, room_number)   -- Unique location
);

COMMENT ON TABLE room IS 'Study and work rooms available for reservation by students';
COMMENT ON COLUMN room.opening_time IS 'Room opening time (e.g., 07:00)';
COMMENT ON COLUMN room.closing_time IS 'Room closing time (e.g., 22:00)';


-- TABLE: room_equipment
-- Equipment available per room (decomposed N:M relationship)
CREATE TABLE room_equipment (
    id_equipment        SERIAL              PRIMARY KEY,
    id_room             INTEGER             NOT NULL REFERENCES room(id_room) ON DELETE CASCADE,
    type                equipment_type      NOT NULL,
    quantity            SMALLINT            NOT NULL DEFAULT 1 CHECK (quantity > 0),
    notes               TEXT,

    UNIQUE (id_room, type)
);

COMMENT ON TABLE room_equipment IS 'Equipment inventory available in each room';


-- TABLE: computer
-- Portable devices available for loan and reservation
CREATE TABLE computer (
    id_computer         SERIAL              PRIMARY KEY,
    inventory_code      VARCHAR(50)         NOT NULL UNIQUE,
    model               VARCHAR(100)        NOT NULL,
    brand               VARCHAR(100)        NOT NULL,
    processor           VARCHAR(100)        NOT NULL,
    ram_gb              SMALLINT            NOT NULL CHECK (ram_gb > 0),
    storage_gb          INTEGER             NOT NULL CHECK (storage_gb > 0),
    qr_code             VARCHAR(255)        UNIQUE,
    status              computer_status    NOT NULL DEFAULT 'AVAILABLE',
    acquisition_date    DATE                NOT NULL,
    notes               TEXT,
    created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE computer IS 'Laptops from IT department available for direct loan or prior reservation';
COMMENT ON COLUMN computer.inventory_code IS 'Unique physical inventory code (label on equipment)';
COMMENT ON COLUMN computer.qr_code IS 'QR or barcode generated for quick identification';


-- TABLE: reservation
-- Reservations of rooms or computers made by students
-- A reservation can be for a room OR a computer (never both)
CREATE TABLE reservation (
    id_reservation      SERIAL          PRIMARY KEY,
    id_student          INTEGER         NOT NULL REFERENCES student(id_student),
    resource_type       resource_type   NOT NULL,
    id_room             INTEGER         REFERENCES room(id_room),
    id_computer         INTEGER         REFERENCES computer(id_computer),
    reservation_date    DATE            NOT NULL,
    start_time          TIME            NOT NULL,
    end_time            TIME            NOT NULL CHECK (end_time > start_time),
    status              reservation_status NOT NULL DEFAULT 'ACTIVE',
    cancellation_reason TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Only one of the two FKs can have a value according to resource_type
    CONSTRAINT chk_resource_exclusive CHECK (
        (resource_type = 'ROOM'      AND id_room IS NOT NULL           AND id_computer IS NULL) OR
        (resource_type = 'COMPUTER'  AND id_computer IS NOT NULL      AND id_room IS NULL)
    )
);

COMMENT ON TABLE reservation IS 'Reservations of rooms or computers. The resource_type determines which FK applies';
COMMENT ON COLUMN reservation.resource_type IS 'ROOM: physical space reservation | COMPUTER: equipment reservation';
COMMENT ON COLUMN reservation.status IS 'ACTIVE | CANCELLED | COMPLETED | CONVERTED_TO_LOAN (computers only)';


-- Index to avoid overlapping reservations in the same room
CREATE UNIQUE INDEX idx_reservation_room_no_overlap
    ON reservation (id_room, reservation_date, start_time, end_time)
    WHERE status = 'ACTIVE' AND id_room IS NOT NULL;

-- Index to avoid overlapping reservations on the same computer
CREATE UNIQUE INDEX idx_reservation_computer_no_overlap
    ON reservation (id_computer, reservation_date, start_time, end_time)
    WHERE status = 'ACTIVE' AND id_computer IS NOT NULL;


-- TABLE: loan
-- Computer loans. Can originate from a prior reservation
-- or be a direct loan without reservation.
CREATE TABLE loan (
    id_loan                 SERIAL          PRIMARY KEY,
    id_student              INTEGER         NOT NULL REFERENCES student(id_student),
    id_computer             INTEGER         NOT NULL REFERENCES computer(id_computer),
    id_employee_registrant  INTEGER         NOT NULL REFERENCES employee(id_employee),
    id_reservation          INTEGER         UNIQUE REFERENCES reservation(id_reservation),   -- nullable: direct loan
    request_date            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expected_return_date    TIMESTAMPTZ     NOT NULL,
    actual_return_date      TIMESTAMPTZ,
    status                  loan_status     NOT NULL DEFAULT 'ACTIVE',
    notes                   TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CHECK (expected_return_date > request_date),
    CHECK (actual_return_date IS NULL OR actual_return_date >= request_date)
);

COMMENT ON TABLE loan IS 'Computer loans. id_reservation is NULL if it was a direct loan without prior reservation';
COMMENT ON COLUMN loan.id_reservation IS 'Optional FK: if from prior reservation, the reservation changes to CONVERTED_TO_LOAN';
COMMENT ON COLUMN loan.id_employee_registrant IS 'IT employee who physically delivered the equipment';


-- TABLE: fine
-- Fines generated for late return or other non-compliance
CREATE TABLE fine (
    id_fine             SERIAL          PRIMARY KEY,
    id_student          INTEGER         NOT NULL REFERENCES student(id_student),
    id_loan             INTEGER         REFERENCES loan(id_loan),
    amount              NUMERIC(10,2)   NOT NULL CHECK (amount > 0),
    reason              TEXT            NOT NULL,
    status              fine_status     NOT NULL DEFAULT 'PENDING',
    generation_date     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    payment_date        TIMESTAMPTZ,

    CHECK (payment_date IS NULL OR payment_date >= generation_date)
);

COMMENT ON TABLE fine IS 'Economic fines for non-compliance in loans. Updates pending_fines in student';


-- TABLE: audit
-- Immutable record of all critical system operations
CREATE TABLE audit (
    id_audit            BIGSERIAL       PRIMARY KEY,
    affected_table      VARCHAR(100)    NOT NULL,
    record_id           INTEGER,
    action              audit_action    NOT NULL,
    id_employee         INTEGER         REFERENCES employee(id_employee),   -- nullable if student action
    id_student          INTEGER         REFERENCES student(id_student),
    user_role           VARCHAR(50),
    previous_data       JSONB,
    new_data            JSONB,
    source_ip           INET,
    date_time           TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit IS 'Immutable log of all critical operations. Never deleted or updated';
COMMENT ON COLUMN audit.previous_data IS 'Record state before change (JSON)';
COMMENT ON COLUMN audit.new_data IS 'Record state after change (JSON)';


-- PERFORMANCE INDICES

-- Employee
CREATE INDEX idx_employee_email  ON employee (institutional_email);
CREATE INDEX idx_employee_status  ON employee (status);
CREATE INDEX idx_employee_role     ON employee (role);

-- Student
CREATE INDEX idx_student_email        ON student (institutional_email);
CREATE INDEX idx_student_status       ON student (academic_status);
CREATE INDEX idx_student_identification ON student (identification_number);

-- Room
CREATE INDEX idx_room_status    ON room (status);
CREATE INDEX idx_room_location  ON room (building, floor);

-- Computer
CREATE INDEX idx_computer_status    ON computer (status);
CREATE INDEX idx_computer_code      ON computer (inventory_code);

-- Reservation
CREATE INDEX idx_reservation_student     ON reservation (id_student);
CREATE INDEX idx_reservation_room        ON reservation (id_room);
CREATE INDEX idx_reservation_computer    ON reservation (id_computer);
CREATE INDEX idx_reservation_date_status ON reservation (reservation_date, status);

-- Loan
CREATE INDEX idx_loan_student    ON loan (id_student);
CREATE INDEX idx_loan_computer   ON loan (id_computer);
CREATE INDEX idx_loan_status     ON loan (status);
CREATE INDEX idx_loan_dates      ON loan (request_date, expected_return_date);

-- Fine
CREATE INDEX idx_fine_student ON fine (id_student);
CREATE INDEX idx_fine_status  ON fine (status);

-- Audit
CREATE INDEX idx_audit_table    ON audit (affected_table);
CREATE INDEX idx_audit_date     ON audit (date_time DESC);
CREATE INDEX idx_audit_employee ON audit (id_employee);

/*
-- FUNCTION: automatically update updated_at
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER trg_employee_updated_at
    BEFORE UPDATE ON employee
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_student_updated_at
    BEFORE UPDATE ON student
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_room_updated_at
    BEFORE UPDATE ON room
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_computer_updated_at
    BEFORE UPDATE ON computer
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_reservation_updated_at
    BEFORE UPDATE ON reservation
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_loan_updated_at
    BEFORE UPDATE ON loan
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- FUNCTION: synchronize pending_fines in student
-- Executed when inserting or updating a fine
CREATE OR REPLACE FUNCTION fn_sync_pending_fines()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE student
    SET pending_fines = (
        SELECT COALESCE(SUM(amount), 0)
        FROM fine
        WHERE id_student = NEW.id_student
          AND status = 'PENDING'
    )
    WHERE id_student = NEW.id_student;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_fines
    AFTER INSERT OR UPDATE ON fine
    FOR EACH ROW EXECUTE FUNCTION fn_sync_pending_fines();


-- FUNCTION: when creating a loan from a reservation, mark the reservation
CREATE OR REPLACE FUNCTION fn_convert_reservation_to_loan()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_reservation IS NOT NULL THEN
        UPDATE reservation
        SET status = 'CONVERTED_TO_LOAN'
        WHERE id_reservation = NEW.id_reservation;
    END IF;

    -- Change computer status to ON_LOAN
    UPDATE computer
    SET status = 'ON_LOAN'
    WHERE id_computer = NEW.id_computer;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loan_insert
    AFTER INSERT ON loan
    FOR EACH ROW EXECUTE FUNCTION fn_convert_reservation_to_loan();


-- FUNCTION: when returning a loan, free the computer
CREATE OR REPLACE FUNCTION fn_return_loan()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'RETURNED' AND OLD.status = 'ACTIVE' THEN
        UPDATE computer
        SET status = 'AVAILABLE'
        WHERE id_computer = NEW.id_computer;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loan_return
    AFTER UPDATE ON loan
    FOR EACH ROW EXECUTE FUNCTION fn_return_loan();


-- FUNCTION: validate that no active loan exists before
-- deactivating or changing status of a computer
-- (Validation in application layer is also recommended)
CREATE OR REPLACE FUNCTION fn_validate_computer_free()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IN ('INACTIVE', 'MAINTENANCE') AND OLD.status = 'ON_LOAN' THEN
        RAISE EXCEPTION 'Cannot change status of a computer with active loan (id: %)', OLD.id_computer;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_computer_status_check
    BEFORE UPDATE ON computer
    FOR EACH ROW EXECUTE FUNCTION fn_validate_computer_free();


-- FUNCTION: validate that the system never has zero administrators

CREATE OR REPLACE FUNCTION fn_validate_last_admin()
RETURNS TRIGGER AS $$
DECLARE
    total_admins INTEGER;
BEGIN
    IF NEW.status = 'INACTIVE' AND OLD.status = 'ACTIVE' AND NEW.role = 'ADMINISTRATOR' THEN
        SELECT COUNT(*) INTO total_admins
        FROM employee
        WHERE role = 'ADMINISTRATOR' AND status = 'ACTIVE';

        IF total_admins <= 1 THEN
            RAISE EXCEPTION 'Cannot deactivate the only active administrator in the system';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_employee_last_admin
    BEFORE UPDATE ON employee
    FOR EACH ROW EXECUTE FUNCTION fn_validate_last_admin();

*/

-- VIEWS

-- Available computers for loan/reservation
CREATE VIEW v_computers_available AS
SELECT id_computer, inventory_code, brand, model,
       processor, ram_gb, storage_gb
FROM computer
WHERE status = 'AVAILABLE';

-- Available rooms (with equipment as JSON)
CREATE VIEW v_rooms_available AS
SELECT r.id_room, r.name, r.building, r.floor, r.room_number,
       r.max_capacity, r.opening_time, r.closing_time,
       JSON_AGG(JSON_BUILD_OBJECT('type', e.type, 'quantity', e.quantity)) AS equipment
FROM room r
LEFT JOIN room_equipment e USING (id_room)
WHERE r.status = 'AVAILABLE'
GROUP BY r.id_room;

-- Active loans with student and equipment data
CREATE VIEW v_active_loans AS
SELECT l.id_loan,
       st.full_name AS student,
       st.institutional_email AS student_email,
       c.inventory_code, c.brand, c.model,
       emp.full_name AS registrant_employee,
       l.request_date,
       l.expected_return_date,
       l.id_reservation
FROM loan l
JOIN student st USING (id_student)
JOIN computer c USING (id_computer)
JOIN employee emp ON emp.id_employee = l.id_employee_registrant
WHERE l.status = 'ACTIVE';

-- Active reservations for today
CREATE VIEW v_reservations_today AS
SELECT r.id_reservation, r.resource_type,
       st.full_name AS student,
       rm.name AS room, rm.building, rm.floor,
       c.inventory_code, c.brand,
       r.start_time, r.end_time, r.status
FROM reservation r
JOIN student st USING (id_student)
LEFT JOIN room rm USING (id_room)
LEFT JOIN computer c USING (id_computer)
WHERE r.reservation_date = CURRENT_DATE
  AND r.status = 'ACTIVE';

-- Students with pending fines
CREATE VIEW v_students_with_fines AS
SELECT s.id_student, s.full_name,
       s.institutional_email, s.pending_fines
FROM student s
WHERE s.pending_fines > 0
ORDER BY s.pending_fines DESC;



-- INITIAL DATA: Default Admin
-- IMPORTANT: Change password on first login
-- BCrypt hash example for 'Admin@2026!'

INSERT INTO employee (
    identification_number,
    full_name,
    institutional_email,
    password_hash,
    role,
    department,
    status,
    hire_date
) VALUES (
    '00000001',
    'IT Administrator',
    'admin.dti@ucc.edu.co',
    '$2a$12$PLACEHOLDER_HASH_CHANGE_ON_FIRST_LOGIN',
    'ADMINISTRATOR',
    'IT',
    'ACTIVE',
    CURRENT_DATE
);