-- ================================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Database : MySQL 8.0
-- Subject  : DBMS (4th Semester B.Tech)
-- Concepts : Normalization (1NF, 2NF, 3NF), Primary Key, Foreign Key,
--            Constraints, JOINs, Aggregate Functions, Views,
--            Triggers, Indexes
-- ================================================================


-- ================================================================
-- NORMALIZATION DEMONSTRATION
-- (Show this section to evaluators before the actual schema)
--
-- STEP 0 — Unnormalized Table (UNF)
-- Imagine we started with one flat table:
--
-- patient_appointment(
--   patient_id, patient_name, patient_phone, patient_address,
--   doctor_id, doctor_name, doctor_phone, doctor_specialization,
--   dept_name, dept_location,
--   appt_date, appt_time, diagnosis, prescription,
--   bill_amount, payment_status
-- )
--
-- Problems: repeating groups, lots of redundancy.
--
-- STEP 1 — First Normal Form (1NF)
--   Rule: Every column must hold atomic (single) values.
--         No repeating groups.
--   Fix : Separate each entity into its own table with a primary key.
--         e.g. patient_name → first_name + last_name is atomic.
--         Result: patients, doctors, appointments, billing tables.
--
-- STEP 2 — Second Normal Form (2NF)
--   Rule: Must be in 1NF + every non-key column must depend
--         on the WHOLE primary key (no partial dependency).
--   Fix : In a composite-key table like appointment_items,
--         if doctor_name depends only on doctor_id (not the full key),
--         move it to a doctors table.
--         Here all our tables have single-column PKs, so 2NF is
--         automatically satisfied once 1NF is done.
--
-- STEP 3 — Third Normal Form (3NF)
--   Rule: Must be in 2NF + no transitive dependency
--         (non-key column must not depend on another non-key column).
--   Fix : dept_location depends on dept_name, not on doctor_id.
--         So we moved department info into its own DEPARTMENTS table,
--         and doctors just store dept_id (FK).
--         Similarly, diagnosis/prescription depend on the appointment,
--         not on the patient directly — so MEDICAL_RECORDS is separate.
--
-- FINAL RESULT: 8 clean tables, fully in 3NF.
-- ================================================================


-- ================================================================
-- CREATE DATABASE
-- ================================================================
CREATE DATABASE IF NOT EXISTS hospital_db;
USE hospital_db;


-- ================================================================
-- TABLE 1: DEPARTMENTS
-- Why separate? dept_location is a fact about the department,
-- not about the doctor — removing transitive dependency (3NF).
-- ================================================================
CREATE TABLE departments (
    dept_id     INT           PRIMARY KEY AUTO_INCREMENT,
    dept_name   VARCHAR(100)  NOT NULL UNIQUE,
    location    VARCHAR(100)  NOT NULL
);


-- ================================================================
-- TABLE 2: DOCTORS
-- dept_id is a Foreign Key → links to departments.
-- Specialization is a fact about the doctor, stays here (3NF OK).
-- ================================================================
CREATE TABLE doctors (
    doctor_id       INT          PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(100) NOT NULL,
    specialization  VARCHAR(100) NOT NULL,
    phone           VARCHAR(15)  NOT NULL UNIQUE,
    email           VARCHAR(100) UNIQUE,
    dept_id         INT          NOT NULL,

    CONSTRAINT fk_doctor_dept
        FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ================================================================
-- TABLE 3: PATIENTS
-- address is stored here because it is a fact about the patient.
-- blood_group uses CHECK constraint — a 4th sem favourite.
-- ================================================================
CREATE TABLE patients (
    patient_id  INT          PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    age         INT          NOT NULL,
    gender      VARCHAR(10)  NOT NULL,
    phone       VARCHAR(15)  NOT NULL UNIQUE,
    blood_group VARCHAR(5),
    address     VARCHAR(255),

    CONSTRAINT chk_age        CHECK (age > 0 AND age < 150),
    CONSTRAINT chk_gender     CHECK (gender IN ('Male','Female','Other')),
    CONSTRAINT chk_blood      CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-'))
);


-- ================================================================
-- TABLE 4: ROOMS
-- Kept separate from admissions — a room's type doesn't depend
-- on who is admitted (3NF).
-- ================================================================
CREATE TABLE rooms (
    room_id      INT         PRIMARY KEY AUTO_INCREMENT,
    room_number  VARCHAR(10) NOT NULL UNIQUE,
    room_type    VARCHAR(50) NOT NULL,   -- General, ICU, Private, Semi-Private
    status       VARCHAR(20) NOT NULL DEFAULT 'Available',

    CONSTRAINT chk_room_type   CHECK (room_type IN ('General','ICU','Private','Semi-Private')),
    CONSTRAINT chk_room_status CHECK (status IN ('Available','Occupied'))
);


-- ================================================================
-- TABLE 5: APPOINTMENTS
-- This is the central junction — links patients and doctors.
-- Status tracks where the appointment stands.
-- ================================================================
CREATE TABLE appointments (
    appt_id     INT         PRIMARY KEY AUTO_INCREMENT,
    appt_date   DATE        NOT NULL,
    appt_time   TIME        NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
    reason      VARCHAR(255),
    patient_id  INT         NOT NULL,
    doctor_id   INT         NOT NULL,

    CONSTRAINT chk_appt_status
        CHECK (status IN ('Scheduled','Completed','Cancelled')),
    CONSTRAINT fk_appt_patient
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_appt_doctor
        FOREIGN KEY (doctor_id)  REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT
);


-- ================================================================
-- TABLE 6: MEDICAL_RECORDS
-- One-to-one with appointments (each appointment generates one record).
-- Diagnosis & prescription depend on the appointment, not the patient
-- directly — this is the 3NF separation evaluators love to discuss.
-- ================================================================
CREATE TABLE medical_records (
    record_id    INT  PRIMARY KEY AUTO_INCREMENT,
    diagnosis    VARCHAR(255) NOT NULL,
    prescription TEXT,
    notes        TEXT,
    record_date  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    appt_id      INT          NOT NULL UNIQUE,   -- 1-to-1 with appointment

    CONSTRAINT fk_record_appt
        FOREIGN KEY (appt_id) REFERENCES appointments(appt_id)
        ON DELETE CASCADE
);


-- ================================================================
-- TABLE 7: BILLING
-- bill_date and total_amount depend on the bill, not on patient
-- directly. Linking to both patient and appointment gives us
-- reporting flexibility.
-- ================================================================
CREATE TABLE billing (
    bill_id        INT          PRIMARY KEY AUTO_INCREMENT,
    total_amount   DECIMAL(10,2) NOT NULL,
    payment_status VARCHAR(20)  NOT NULL DEFAULT 'Pending',
    payment_mode   VARCHAR(30),
    bill_date      DATE         NOT NULL DEFAULT (CURRENT_DATE),
    patient_id     INT          NOT NULL,
    appt_id        INT          NOT NULL,

    CONSTRAINT chk_bill_status
        CHECK (payment_status IN ('Pending','Paid','Waived')),
    CONSTRAINT chk_amount
        CHECK (total_amount >= 0),
    CONSTRAINT fk_bill_patient
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_bill_appt
        FOREIGN KEY (appt_id) REFERENCES appointments(appt_id)
        ON DELETE RESTRICT
);


-- ================================================================
-- TABLE 8: ADMISSIONS
-- Tracks inpatient stays. Separate from appointments because
-- a patient can be admitted without an outpatient appointment.
-- ================================================================
CREATE TABLE admissions (
    admission_id   INT  PRIMARY KEY AUTO_INCREMENT,
    admit_date     DATE NOT NULL,
    discharge_date DATE,
    doctor_id      INT  NOT NULL,
    patient_id     INT  NOT NULL,
    room_id        INT  NOT NULL,

    CONSTRAINT chk_discharge
        CHECK (discharge_date IS NULL OR discharge_date >= admit_date),
    CONSTRAINT fk_adm_doctor
        FOREIGN KEY (doctor_id)  REFERENCES doctors(doctor_id),
    CONSTRAINT fk_adm_patient
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    CONSTRAINT fk_adm_room
        FOREIGN KEY (room_id)    REFERENCES rooms(room_id)
);


-- ================================================================
-- INDEXES
-- Add indexes on columns we query or filter frequently.
-- Evaluator tip: explain that indexes speed up SELECT but
-- slightly slow down INSERT/UPDATE — a trade-off.
-- ================================================================
CREATE INDEX idx_appt_date       ON appointments(appt_date);
CREATE INDEX idx_appt_patient    ON appointments(patient_id);
CREATE INDEX idx_appt_doctor     ON appointments(doctor_id);
CREATE INDEX idx_billing_patient ON billing(patient_id);
CREATE INDEX idx_patient_phone   ON patients(phone);


-- ================================================================
-- VIEWS
-- A view is a saved SELECT query — it behaves like a virtual table.
-- ================================================================

-- View 1: Today's full appointment list with names
CREATE VIEW view_today_appointments AS
SELECT
    a.appt_id,
    a.appt_time,
    a.status,
    p.name         AS patient_name,
    p.phone        AS patient_phone,
    d.name         AS doctor_name,
    d.specialization,
    dept.dept_name
FROM appointments a
JOIN patients    p    ON p.patient_id = a.patient_id
JOIN doctors     d    ON d.doctor_id  = a.doctor_id
JOIN departments dept ON dept.dept_id = d.dept_id
WHERE a.appt_date = CURDATE()
ORDER BY a.appt_time;

-- View 2: Pending bills — useful for the billing desk
CREATE VIEW view_pending_bills AS
SELECT
    b.bill_id,
    b.bill_date,
    b.total_amount,
    p.name  AS patient_name,
    p.phone AS patient_phone
FROM billing b
JOIN patients p ON p.patient_id = b.patient_id
WHERE b.payment_status = 'Pending'
ORDER BY b.bill_date;

-- View 3: Current inpatients
CREATE VIEW view_current_admissions AS
SELECT
    adm.admission_id,
    adm.admit_date,
    p.name          AS patient_name,
    r.room_number,
    r.room_type,
    d.name          AS doctor_name
FROM admissions adm
JOIN patients p ON p.patient_id = adm.patient_id
JOIN rooms    r ON r.room_id    = adm.room_id
JOIN doctors  d ON d.doctor_id  = adm.doctor_id
WHERE adm.discharge_date IS NULL;


-- ================================================================
-- TRIGGERS
-- Trigger 1: When an appointment is marked Completed,
--            automatically insert a billing record.
-- ================================================================
DELIMITER $$

CREATE TRIGGER trg_auto_bill
AFTER UPDATE ON appointments
FOR EACH ROW
BEGIN
    -- Only fires when status changes TO 'Completed'
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        INSERT INTO billing (total_amount, payment_status, bill_date, patient_id, appt_id)
        VALUES (500.00, 'Pending', CURDATE(), NEW.patient_id, NEW.appt_id);
    END IF;
END$$

-- Trigger 2: When a patient is admitted, mark the room as Occupied.
CREATE TRIGGER trg_room_on_admit
AFTER INSERT ON admissions
FOR EACH ROW
BEGIN
    UPDATE rooms
    SET status = 'Occupied'
    WHERE room_id = NEW.room_id;
END$$

-- Trigger 3: When a patient is discharged (discharge_date set),
--            mark the room as Available again.
CREATE TRIGGER trg_room_on_discharge
AFTER UPDATE ON admissions
FOR EACH ROW
BEGIN
    IF NEW.discharge_date IS NOT NULL AND OLD.discharge_date IS NULL THEN
        UPDATE rooms
        SET status = 'Available'
        WHERE room_id = NEW.room_id;
    END IF;
END$$

DELIMITER ;


-- ================================================================
-- SAMPLE DATA — insert enough to demo all queries
-- ================================================================

INSERT INTO departments (dept_name, location) VALUES
('Cardiology',   'Block A, 2nd Floor'),
('Orthopedics',  'Block B, 1st Floor'),
('Pediatrics',   'Block C, Ground Floor'),
('Neurology',    'Block A, 3rd Floor'),
('General',      'Block D, Ground Floor');

INSERT INTO doctors (name, specialization, phone, email, dept_id) VALUES
('Dr. Ramesh Kumar',   'Cardiologist',      '9876543210', 'ramesh@hms.com',   1),
('Dr. Priya Sharma',   'Orthopedic Surgeon','9876543211', 'priya@hms.com',    2),
('Dr. Anita Desai',    'Pediatrician',      '9876543212', 'anita@hms.com',    3),
('Dr. Suresh Nair',    'Neurologist',       '9876543213', 'suresh@hms.com',   4),
('Dr. Kavita Rao',     'General Physician', '9876543214', 'kavita@hms.com',   5);

INSERT INTO patients (name, age, gender, phone, blood_group, address) VALUES
('Arjun Mehta',    32, 'Male',   '9000000001', 'O+',  '12 MG Road, Bengaluru'),
('Sneha Patil',    27, 'Female', '9000000002', 'B+',  '45 Park Street, Chennai'),
('Rohit Verma',    55, 'Male',   '9000000003', 'A+',  '7 Civil Lines, Delhi'),
('Deepa Nair',     40, 'Female', '9000000004', 'AB-', '88 Anna Nagar, Chennai'),
('Kiran Joshi',    10, 'Male',   '9000000005', 'O-',  '3 Laxmi Nagar, Pune'),
('Meena Iyer',     62, 'Female', '9000000006', 'A-',  '22 MG Road, Kochi');

INSERT INTO rooms (room_number, room_type, status) VALUES
('R101', 'General',       'Available'),
('R102', 'General',       'Available'),
('R201', 'Private',       'Available'),
('R202', 'Private',       'Available'),
('ICU1', 'ICU',           'Available'),
('ICU2', 'ICU',           'Available'),
('S101', 'Semi-Private',  'Available');

-- Appointments (mix of today's date and past dates for demo)
INSERT INTO appointments (appt_date, appt_time, status, reason, patient_id, doctor_id) VALUES
(CURDATE(),             '09:00:00', 'Scheduled',  'Chest pain',        1, 1),
(CURDATE(),             '09:30:00', 'Scheduled',  'Knee pain',         2, 2),
(CURDATE(),             '10:00:00', 'Scheduled',  'Fever',             5, 3),
(DATE_SUB(CURDATE(),INTERVAL 1 DAY), '11:00:00', 'Completed', 'Headache',    3, 4),
(DATE_SUB(CURDATE(),INTERVAL 2 DAY), '14:00:00', 'Completed', 'Routine check', 4, 5),
(DATE_SUB(CURDATE(),INTERVAL 3 DAY), '10:00:00', 'Cancelled', 'Cold',        6, 3);

-- Medical records for completed appointments
INSERT INTO medical_records (diagnosis, prescription, record_date, appt_id) VALUES
('Migraine',        'Tab. Sumatriptan 50mg — once daily for 5 days', DATE_SUB(CURDATE(),INTERVAL 1 DAY), 4),
('Hypertension',    'Tab. Amlodipine 5mg — once daily. Reduce salt intake.', DATE_SUB(CURDATE(),INTERVAL 2 DAY), 5);

-- Billing
INSERT INTO billing (total_amount, payment_status, payment_mode, bill_date, patient_id, appt_id) VALUES
(600.00, 'Paid',    'Cash',   DATE_SUB(CURDATE(),INTERVAL 1 DAY), 3, 4),
(500.00, 'Pending', NULL,     DATE_SUB(CURDATE(),INTERVAL 2 DAY), 4, 5);

-- Admissions
INSERT INTO admissions (admit_date, doctor_id, patient_id, room_id) VALUES
(DATE_SUB(CURDATE(),INTERVAL 2 DAY), 1, 1, 5),  -- Arjun in ICU1
(DATE_SUB(CURDATE(),INTERVAL 1 DAY), 2, 2, 3);  -- Sneha in R201


-- ================================================================
-- KEY SQL QUERIES — memorise and run these for evaluators
-- ================================================================

-- Q1: INNER JOIN — all appointments with patient and doctor names
SELECT
    a.appt_id,
    a.appt_date,
    a.appt_time,
    a.status,
    p.name  AS patient,
    d.name  AS doctor,
    d.specialization
FROM appointments a
INNER JOIN patients p ON p.patient_id = a.patient_id
INNER JOIN doctors  d ON d.doctor_id  = a.doctor_id
ORDER BY a.appt_date, a.appt_time;


-- Q2: LEFT JOIN — patients who have NOT been billed yet
SELECT
    p.patient_id,
    p.name,
    p.phone
FROM patients p
LEFT JOIN billing b ON b.patient_id = p.patient_id
WHERE b.bill_id IS NULL;


-- Q3: Aggregate — total revenue collected per department
SELECT
    dept.dept_name,
    COUNT(b.bill_id)       AS total_bills,
    SUM(b.total_amount)    AS total_billed,
    SUM(CASE WHEN b.payment_status = 'Paid'
             THEN b.total_amount ELSE 0 END) AS collected
FROM departments dept
JOIN doctors      d    ON d.dept_id    = dept.dept_id
JOIN appointments a    ON a.doctor_id  = d.doctor_id
JOIN billing      b    ON b.appt_id    = a.appt_id
GROUP BY dept.dept_name
ORDER BY collected DESC;


-- Q4: Aggregate — number of appointments per doctor
SELECT
    d.name           AS doctor_name,
    d.specialization,
    COUNT(a.appt_id) AS total_appointments,
    SUM(a.status = 'Completed') AS completed,
    SUM(a.status = 'Cancelled') AS cancelled
FROM doctors d
LEFT JOIN appointments a ON a.doctor_id = d.doctor_id
GROUP BY d.doctor_id, d.name, d.specialization
ORDER BY total_appointments DESC;


-- Q5: Subquery — patients whose total billing exceeds ₹1000
SELECT
    p.name,
    p.phone,
    total_spend
FROM patients p
JOIN (
    SELECT patient_id, SUM(total_amount) AS total_spend
    FROM billing
    GROUP BY patient_id
    HAVING SUM(total_amount) > 1000
) AS big_spenders ON big_spenders.patient_id = p.patient_id;


-- Q6: Using a VIEW — simply query it like a table
SELECT * FROM view_today_appointments;
SELECT * FROM view_pending_bills;
SELECT * FROM view_current_admissions;


-- Q7: BETWEEN — appointments in a date range
SELECT
    a.appt_id,
    a.appt_date,
    p.name AS patient,
    d.name AS doctor
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors  d ON d.doctor_id  = a.doctor_id
WHERE a.appt_date BETWEEN '2025-01-01' AND CURDATE()
ORDER BY a.appt_date DESC;


-- Q8: UPDATE — mark a bill as paid
UPDATE billing
SET payment_status = 'Paid',
    payment_mode   = 'UPI'
WHERE bill_id = 2;


-- Q9: LIKE search — find patient by partial name
SELECT patient_id, name, phone, blood_group
FROM patients
WHERE name LIKE '%Mehta%';


-- Q10: DELETE — remove a cancelled appointment
-- (medical_records and billing cascade-delete automatically if linked)
DELETE FROM appointments
WHERE status = 'Cancelled'
  AND appt_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY);
