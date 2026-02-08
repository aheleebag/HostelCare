// server.js - Main Backend Server for HostelCare
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, '../frontend')));


// MySQL Database Connection
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'root', // Change this to your MySQL password
    database: 'hostelcare'
});

db.connect((err) => {
    if (err) {
        console.error('Database connection failed:', err);
        return;
    }
    console.log('✅ Connected to MySQL Database');
});

// ============================================
// AUTHENTICATION ROUTES
// ============================================

// Student Login
app.post('/api/student/login', (req, res) => {
    const { email, password } = req.body;
    
    const query = 'SELECT * FROM Students WHERE email = ? AND password = ?';
    db.query(query, [email, password], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        if (results.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        res.json({ 
            success: true, 
            student: {
                student_id: results[0].student_id,
                name: results[0].name,
                email: results[0].email,
                department: results[0].department,
                year: results[0].year
            }
        });
    });
});

// Admin Login
app.post('/api/admin/login', (req, res) => {
    const { username, password } = req.body;
    
    const query = 'SELECT * FROM AdminUsers WHERE username = ? AND password = ?';
    db.query(query, [username, password], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        if (results.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        res.json({ 
            success: true, 
            admin: {
                admin_id: results[0].admin_id,
                username: results[0].username,
                full_name: results[0].full_name,
                role: results[0].role
            }
        });
    });
});

// ============================================
// STUDENT ROUTES
// ============================================

// Get student's room details and roommates
app.get('/api/student/:studentId/room', (req, res) => {
    const studentId = req.params.studentId;
    
    const query = `
        SELECT 
            s.student_id, s.name, s.email, s.phone, s.department, s.year,
            h.hostel_name, h.warden_name, h.warden_phone,
            r.room_number, r.floor, r.capacity, r.current_occupancy, r.room_type, r.has_attached_bathroom,
            a.allocation_date, a.academic_year
        FROM Allocations a
        JOIN Students s ON a.student_id = s.student_id
        JOIN Rooms r ON a.room_id = r.room_id
        JOIN Hostels h ON r.hostel_id = h.hostel_id
        WHERE a.student_id = ? AND a.status = 'Active'
    `;
    
    db.query(query, [studentId], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        if (results.length === 0) {
            return res.json({ allocated: false, message: 'No room allocated yet' });
        }
        
        const roomId = results[0].room_id;
        
        // Get roommates
        const roommatesQuery = `
            SELECT s.student_id, s.name, s.department, s.year, s.phone, s.email
            FROM Allocations a
            JOIN Students s ON a.student_id = s.student_id
            WHERE a.room_id = (
                SELECT room_id FROM Allocations WHERE student_id = ? AND status = 'Active'
            ) AND a.student_id != ? AND a.status = 'Active'
        `;
        
        db.query(roommatesQuery, [studentId, studentId], (err2, roommates) => {
            if (err2) {
                return res.status(500).json({ error: err2.message });
            }
            
            res.json({
                allocated: true,
                roomDetails: results[0],
                roommates: roommates
            });
        });
    });
});

// Get all students for swap target selection
app.get('/api/student/:studentId/swap-targets', (req, res) => {
    const studentId = req.params.studentId;
    
    const query = `
        SELECT 
            s.student_id, s.name, s.department, s.year,
            h.hostel_name, r.room_number, r.room_type
        FROM Allocations a
        JOIN Students s ON a.student_id = s.student_id
        JOIN Rooms r ON a.room_id = r.room_id
        JOIN Hostels h ON r.hostel_id = h.hostel_id
        WHERE a.student_id != ? 
        AND a.status = 'Active'
        AND s.gender = (SELECT gender FROM Students WHERE student_id = ?)
        ORDER BY h.hostel_name, r.room_number
    `;
    
    db.query(query, [studentId, studentId], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Submit swap request
app.post('/api/student/swap-request', (req, res) => {
    const { requester_id, target_id, reason } = req.body;
    
    // Get room IDs for both students
    const getRoomsQuery = `
        SELECT student_id, room_id 
        FROM Allocations 
        WHERE student_id IN (?, ?) AND status = 'Active'
    `;
    
    db.query(getRoomsQuery, [requester_id, target_id], (err, rooms) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        if (rooms.length !== 2) {
            return res.status(400).json({ error: 'Both students must have active allocations' });
        }
        
        const requesterRoom = rooms.find(r => r.student_id === requester_id).room_id;
        const targetRoom = rooms.find(r => r.student_id === target_id).room_id;
        
        const insertQuery = `
            INSERT INTO SwapRequests (requester_id, target_id, requester_room_id, target_room_id, reason)
            VALUES (?, ?, ?, ?, ?)
        `;
        
        db.query(insertQuery, [requester_id, target_id, requesterRoom, targetRoom, reason], (err2, result) => {
            if (err2) {
                return res.status(500).json({ error: err2.message });
            }
            res.json({ success: true, swap_id: result.insertId });
        });
    });
});

// Get student's swap requests
app.get('/api/student/:studentId/swap-requests', (req, res) => {
    const studentId = req.params.studentId;
    
    const query = `
        SELECT 
            sr.*,
            s1.name AS requester_name,
            s2.name AS target_name,
            r1.room_number AS requester_room,
            r2.room_number AS target_room,
            h1.hostel_name AS requester_hostel,
            h2.hostel_name AS target_hostel
        FROM SwapRequests sr
        JOIN Students s1 ON sr.requester_id = s1.student_id
        JOIN Students s2 ON sr.target_id = s2.student_id
        JOIN Rooms r1 ON sr.requester_room_id = r1.room_id
        JOIN Rooms r2 ON sr.target_room_id = r2.room_id
        JOIN Hostels h1 ON r1.hostel_id = h1.hostel_id
        JOIN Hostels h2 ON r2.hostel_id = h2.hostel_id
        WHERE sr.requester_id = ? OR sr.target_id = ?
        ORDER BY sr.request_date DESC
    `;
    
    db.query(query, [studentId, studentId], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Submit complaint
app.post('/api/student/complaint', (req, res) => {
    const { student_id, category, subject, description, priority } = req.body;
    
    const query = `
        INSERT INTO Complaints (student_id, category, subject, description, priority)
        VALUES (?, ?, ?, ?, ?)
    `;
    
    db.query(query, [student_id, category, subject, description, priority || 'Medium'], (err, result) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ success: true, complaint_id: result.insertId });
    });
});

// Get student's complaints
app.get('/api/student/:studentId/complaints', (req, res) => {
    const studentId = req.params.studentId;
    
    const query = `
        SELECT * FROM Complaints 
        WHERE student_id = ? 
        ORDER BY complaint_date DESC
    `;
    
    db.query(query, [studentId], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// ============================================
// ADMIN ROUTES
// ============================================

// Get all students
app.get('/api/admin/students', (req, res) => {
    const query = `
        SELECT 
            s.*,
            a.allocation_id,
            h.hostel_name,
            r.room_number,
            a.allocation_date,
            a.status AS allocation_status
        FROM Students s
        LEFT JOIN Allocations a ON s.student_id = a.student_id AND a.status = 'Active'
        LEFT JOIN Rooms r ON a.room_id = r.room_id
        LEFT JOIN Hostels h ON r.hostel_id = h.hostel_id
        ORDER BY s.created_at DESC
    `;
    
    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Get all hostels and rooms
app.get('/api/admin/hostels', (req, res) => {
    const query = `
        SELECT 
            h.*,
            COUNT(r.room_id) AS total_rooms_count,
            SUM(r.capacity) AS total_capacity,
            SUM(r.current_occupancy) AS total_occupied
        FROM Hostels h
        LEFT JOIN Rooms r ON h.hostel_id = r.hostel_id
        GROUP BY h.hostel_id
    `;
    
    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Get rooms by hostel
app.get('/api/admin/hostel/:hostelId/rooms', (req, res) => {
    const hostelId = req.params.hostelId;
    
    const query = `
        SELECT 
            r.*,
            h.hostel_name,
            h.gender_type,
            (r.capacity - r.current_occupancy) AS available_beds
        FROM Rooms r
        JOIN Hostels h ON r.hostel_id = h.hostel_id
        WHERE r.hostel_id = ?
        ORDER BY r.floor, r.room_number
    `;
    
    db.query(query, [hostelId], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Get all available rooms
app.get('/api/admin/rooms/available', (req, res) => {
    const query = 'SELECT * FROM vw_available_rooms';
    
    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Allocate room to student
app.post('/api/admin/allocate-room', (req, res) => {
    const { student_id, room_id, academic_year } = req.body;
    
    const query = 'CALL sp_allocate_room(?, ?, ?)';
    
    db.query(query, [student_id, room_id, academic_year], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ success: true, message: 'Room allocated successfully' });
    });
});

// Get all swap requests
app.get('/api/admin/swap-requests', (req, res) => {
    const query = `
        SELECT 
            sr.*,
            s1.name AS requester_name, s1.department AS requester_dept, s1.year AS requester_year,
            s2.name AS target_name, s2.department AS target_dept, s2.year AS target_year,
            r1.room_number AS requester_room, h1.hostel_name AS requester_hostel,
            r2.room_number AS target_room, h2.hostel_name AS target_hostel
        FROM SwapRequests sr
        JOIN Students s1 ON sr.requester_id = s1.student_id
        JOIN Students s2 ON sr.target_id = s2.student_id
        JOIN Rooms r1 ON sr.requester_room_id = r1.room_id
        JOIN Rooms r2 ON sr.target_room_id = r2.room_id
        JOIN Hostels h1 ON r1.hostel_id = h1.hostel_id
        JOIN Hostels h2 ON r2.hostel_id = h2.hostel_id
        ORDER BY 
            CASE sr.status 
                WHEN 'Pending' THEN 1 
                WHEN 'Approved' THEN 2 
                WHEN 'Rejected' THEN 3 
            END,
            sr.request_date DESC
    `;
    
    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Approve swap request
app.post('/api/admin/swap/approve', (req, res) => {
    const { swap_id, admin_username } = req.body;
    
    const query = 'CALL sp_swap_rooms(?, ?)';
    
    db.query(query, [swap_id, admin_username], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ success: true, message: 'Room swap completed successfully' });
    });
});

// Reject swap request
app.post('/api/admin/swap/reject', (req, res) => {
    const { swap_id, admin_username, remarks } = req.body;
    
    const query = 'CALL sp_reject_swap(?, ?, ?)';
    
    db.query(query, [swap_id, admin_username, remarks], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ success: true, message: 'Swap request rejected' });
    });
});

// Get all complaints
app.get('/api/admin/complaints', (req, res) => {
    const query = `
        SELECT 
            c.*,
            s.name AS student_name,
            s.department,
            s.year,
            s.phone AS student_phone
        FROM Complaints c
        JOIN Students s ON c.student_id = s.student_id
        ORDER BY 
            CASE c.status 
                WHEN 'Pending' THEN 1 
                WHEN 'In Progress' THEN 2 
                WHEN 'Resolved' THEN 3 
                WHEN 'Closed' THEN 4 
            END,
            c.priority DESC,
            c.complaint_date DESC
    `;
    
    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// Update complaint status
app.post('/api/admin/complaint/update', (req, res) => {
    const { complaint_id, status, admin_response } = req.body;
    
    const query = `
        UPDATE Complaints 
        SET status = ?, 
            admin_response = ?,
            resolved_date = CASE WHEN ? IN ('Resolved', 'Closed') THEN NOW() ELSE resolved_date END
        WHERE complaint_id = ?
    `;
    
    db.query(query, [status, admin_response, status, complaint_id], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ success: true, message: 'Complaint updated successfully' });
    });
});

// Add new student
app.post('/api/admin/student/add', (req, res) => {
    const { student_id, name, email, password, phone, department, year, gender, 
            parent_name, parent_phone, date_of_birth, address } = req.body;
    
    const query = `
        INSERT INTO Students 
        (student_id, name, email, password, phone, department, year, gender, 
         parent_name, parent_phone, date_of_birth, address)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    
    db.query(query, [student_id, name, email, password, phone, department, year, gender,
                     parent_name, parent_phone, date_of_birth, address], (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json({ success: true, message: 'Student added successfully' });
    });
});

// Dashboard statistics
app.get('/api/admin/dashboard/stats', (req, res) => {
    const queries = {
        totalStudents: 'SELECT COUNT(*) AS count FROM Students',
        allocatedStudents: 'SELECT COUNT(DISTINCT student_id) AS count FROM Allocations WHERE status = "Active"',
        totalRooms: 'SELECT COUNT(*) AS count FROM Rooms',
        occupiedRooms: 'SELECT COUNT(DISTINCT room_id) AS count FROM Allocations WHERE status = "Active"',
        pendingSwaps: 'SELECT COUNT(*) AS count FROM SwapRequests WHERE status = "Pending"',
        pendingComplaints: 'SELECT COUNT(*) AS count FROM Complaints WHERE status IN ("Pending", "In Progress")'
    };
    
    const stats = {};
    let completed = 0;
    
    Object.keys(queries).forEach(key => {
        db.query(queries[key], (err, results) => {
            if (!err) {
                stats[key] = results[0].count;
            }
            completed++;
            
            if (completed === Object.keys(queries).length) {
                res.json(stats);
            }
        });
    });
});

// ============================================
// SERVER START
// ============================================

app.listen(PORT, () => {
    console.log(`🚀 HostelCare Server running on http://localhost:${PORT}`);
    console.log(`📊 Admin Dashboard: http://localhost:${PORT}/admin.html`);
    console.log(`👨‍🎓 Student Portal: http://localhost:${PORT}/student.html`);
});