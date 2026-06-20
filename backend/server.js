// =============================================
// HOSPITAL MANAGEMENT SYSTEM - Backend Server
// =============================================
require('dotenv').config();
const Groq = require('groq-sdk');
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
const express = require('express');
const mysql   = require('mysql2');
const cors    = require('cors');

const app  = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || '*'
}));
app.use(express.json());

// =============================================
// DATABASE CONNECTION (POOL)
// =============================================
const db = mysql.createPool({
  host     : process.env.DB_HOST,
  port     : process.env.DB_PORT || 3306,
  user     : process.env.DB_USER,
  password : process.env.DB_PASSWORD,
  database : process.env.DB_NAME,
  ssl      : process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

db.getConnection((err, connection) => {
  if (err) {
    console.log('❌ Database connection failed:', err.message);
    return;
  }
  console.log('✅ Connected to', process.env.DB_NAME, 'successfully!');
  connection.release();
});

// =============================================
// TEST ROUTE — browser mein localhost:3000 kholo
// =============================================
app.get('/', (req, res) => {
  res.json({ message: '🏥 Hospital Management System API is running!' });
});

// =============================================
// PATIENTS ROUTES
// =============================================

// GET all patients
app.get('/patients', (req, res) => {
  const sql = 'SELECT * FROM patients ORDER BY patient_id DESC';
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// GET single patient by ID
app.get('/patients/:id', (req, res) => {
  const sql = 'SELECT * FROM patients WHERE patient_id = ?';
  db.query(sql, [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: 'Patient not found' });
    res.json(results[0]);
  });
});

// POST add new patient
app.post('/patients', (req, res) => {
  const { name, age, gender, phone, blood_group, address } = req.body;
  const sql = 'INSERT INTO patients (name, age, gender, phone, blood_group, address) VALUES (?, ?, ?, ?, ?, ?)';
  db.query(sql, [name, age, gender, phone, blood_group, address], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: '✅ Patient added successfully!', patient_id: result.insertId });
  });
});

// DELETE patient
app.delete('/patients/:id', (req, res) => {
  const sql = 'DELETE FROM patients WHERE patient_id = ?';
  db.query(sql, [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: '✅ Patient deleted successfully!' });
  });
});

// =============================================
// DOCTORS ROUTES
// =============================================

// GET all doctors with department name
app.get('/doctors', (req, res) => {
  const sql = `
    SELECT d.*, dept.dept_name 
    FROM doctors d
    JOIN departments dept ON d.dept_id = dept.dept_id
    ORDER BY d.doctor_id
  `;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// =============================================
// DEPARTMENTS ROUTES
// =============================================

// GET all departments
app.get('/departments', (req, res) => {
  const sql = 'SELECT * FROM departments';
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// =============================================
// APPOINTMENTS ROUTES
// =============================================

// GET all appointments with patient + doctor names
app.get('/appointments', (req, res) => {
  const sql = `
    SELECT 
      a.appt_id,
      a.appt_date,
      a.appt_time,
      a.status,
      a.reason,
      p.name  AS patient_name,
      p.phone AS patient_phone,
      d.name  AS doctor_name,
      d.specialization
    FROM appointments a
    JOIN patients p ON a.patient_id = p.patient_id
    JOIN doctors  d ON a.doctor_id  = d.doctor_id
    ORDER BY a.appt_date DESC, a.appt_time
  `;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// GET today's appointments (uses our VIEW)
app.get('/appointments/today', (req, res) => {
  const sql = 'SELECT * FROM view_today_appointments';
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// POST book new appointment
app.post('/appointments', (req, res) => {
  const { appt_date, appt_time, reason, patient_id, doctor_id } = req.body;
  const sql = 'INSERT INTO appointments (appt_date, appt_time, reason, patient_id, doctor_id) VALUES (?, ?, ?, ?, ?)';
  db.query(sql, [appt_date, appt_time, reason, patient_id, doctor_id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: '✅ Appointment booked successfully!', appt_id: result.insertId });
  });
});

// PUT update appointment status (Scheduled / Completed / Cancelled)
// Note: When status changes to Completed, our TRIGGER auto-creates a bill!
app.put('/appointments/:id/status', (req, res) => {
  const { status } = req.body;
  const sql = 'UPDATE appointments SET status = ? WHERE appt_id = ?';
  db.query(sql, [status, req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: `✅ Appointment marked as ${status}` });
  });
});

// =============================================
// BILLING ROUTES
// =============================================

// GET all bills with patient name
app.get('/billing', (req, res) => {
  const sql = `
    SELECT 
      b.bill_id,
      b.total_amount,
      b.payment_status,
      b.payment_mode,
      b.bill_date,
      p.name AS patient_name
    FROM billing b
    JOIN patients p ON b.patient_id = p.patient_id
    ORDER BY b.bill_date DESC
  `;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// GET pending bills (uses our VIEW)
app.get('/billing/pending', (req, res) => {
  const sql = 'SELECT * FROM view_pending_bills';
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// PUT mark bill as paid
app.put('/billing/:id/pay', (req, res) => {
  const { payment_mode } = req.body;
  const sql = "UPDATE billing SET payment_status = 'Paid', payment_mode = ? WHERE bill_id = ?";
  db.query(sql, [payment_mode, req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: '✅ Bill marked as Paid!' });
  });
});

// =============================================
// DASHBOARD STATS ROUTE
// =============================================
app.get('/dashboard', (req, res) => {
  const stats = {};

  db.query('SELECT COUNT(*) AS total FROM patients', (err, r) => {
    if (err) return res.status(500).json({ error: err.message });
    stats.total_patients = r[0].total;

    db.query('SELECT COUNT(*) AS total FROM doctors', (err, r) => {
      if (err) return res.status(500).json({ error: err.message });
      stats.total_doctors = r[0].total;

      db.query("SELECT COUNT(*) AS total FROM appointments WHERE appt_date = CURDATE()", (err, r) => {
        if (err) return res.status(500).json({ error: err.message });
        stats.today_appointments = r[0].total;

        db.query("SELECT COUNT(*) AS total FROM billing WHERE payment_status = 'Pending'", (err, r) => {
          if (err) return res.status(500).json({ error: err.message });
          stats.pending_bills = r[0].total;

          res.json(stats);
        });
      });
    });
  });
});

// =============================================
// LOGIN ROUTE
// =============================================
app.post('/login', (req, res) => {
  const { username, password } = req.body;
  
  // Simple admin credentials
  // (In real world, this would be in database)
  if (username === 'admin' && password === 'admin123') {
    res.json({ 
      success: true, 
      message: 'Login successful!',
      user: { username: 'admin', role: 'Hospital Admin' }
    });
  } else {
    res.status(401).json({ 
      success: false, 
      message: 'Invalid username or password!' 
    });
  }
});


// =============================================
// MEDICAL RECORDS ROUTES
// =============================================

// GET all records for a patient
app.get('/records/:patientId', (req, res) => {
  const sql = `
    SELECT 
      mr.*,
      d.name AS doctor_name,
      p.name AS patient_name,
      a.appt_date,
      a.appt_time
    FROM medical_records mr
    JOIN appointments a ON a.appt_id    = mr.appt_id
    JOIN doctors      d ON d.doctor_id  = a.doctor_id
    JOIN patients     p ON p.patient_id = a.patient_id
    WHERE a.patient_id = ?
    ORDER BY mr.record_date DESC
  `;
  db.query(sql, [req.params.patientId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// GET all records (for records page)
app.get('/records', (req, res) => {
  const sql = `
    SELECT 
      mr.*,
      d.name AS doctor_name,
      p.name AS patient_name,
      a.appt_date
    FROM medical_records mr
    JOIN appointments a ON a.appt_id    = mr.appt_id
    JOIN doctors      d ON d.doctor_id  = a.doctor_id
    JOIN patients     p ON p.patient_id = a.patient_id
    ORDER BY mr.record_date DESC
  `;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// POST create new medical record
app.post('/records', (req, res) => {
  const { appt_id, diagnosis, prescription, notes } = req.body;
  const sql = `
    INSERT INTO medical_records (appt_id, diagnosis, prescription, notes, record_date)
    VALUES (?, ?, ?, ?, CURDATE())
  `;
  db.query(sql, [appt_id, diagnosis, prescription, notes], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: '✅ Medical record saved!', record_id: result.insertId });
  });
});

// GET completed appointments (for dropdown in records form)
app.get('/appointments/completed', (req, res) => {
  const sql = `
    SELECT 
      a.appt_id,
      a.appt_date,
      p.name AS patient_name,
      d.name AS doctor_name
    FROM appointments a
    JOIN patients p ON p.patient_id = a.patient_id
    JOIN doctors  d ON d.doctor_id  = a.doctor_id
    WHERE a.status = 'Completed'
    AND a.appt_id NOT IN (SELECT appt_id FROM medical_records)
    ORDER BY a.appt_date DESC
  `;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// =============================================
// AI CHATBOT ROUTE
// =============================================
app.post('/ai/chat', async (req, res) => {
  const { message } = req.body;
  try {
    const response = await groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      messages: [
        {
          role: 'system',
          content: `You are a helpful hospital assistant for MediCare HMS. 
          Help patients with:
          - Understanding their symptoms
          - Suggesting which department to visit
          - General health advice
          - Hospital related queries
          Always recommend consulting a real doctor for serious issues.
          Keep responses short and clear — max 3-4 lines.`
        },
        {
          role: 'user',
          content: message
        }
      ],
      max_tokens: 300,
    });
    res.json({ reply: response.choices[0].message.content });
  } catch (err) {
    res.status(500).json({ error: 'AI service error: ' + err.message });
  }
});

// =============================================
// START SERVER
// =============================================
app.listen(PORT, () => {
  console.log(`🏥 Hospital server running on port ${PORT}`);
});
