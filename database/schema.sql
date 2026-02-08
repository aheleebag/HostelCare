-- ============================================
-- HOSTELCARE DATABASE SCHEMA
-- Student Hostel Room Allocation and Swap Management System
-- ============================================

-- Drop existing database if exists and create new
DROP DATABASE IF EXISTS hostelcare;
CREATE DATABASE hostelcare;
USE hostelcare;

-- ============================================
-- TABLE DEFINITIONS
-- ============================================

-- Students Table
CREATE TABLE Students (
    student_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(15),
    department VARCHAR(50) NOT NULL,
    year INT NOT NULL CHECK (year BETWEEN 1 AND 4),
    gender ENUM('Male', 'Female', 'Other') NOT NULL,
    parent_name VARCHAR(100),
    parent_phone VARCHAR(15),
    date_of_birth DATE,
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Hostels Table
CREATE TABLE Hostels (
    hostel_id INT AUTO_INCREMENT PRIMARY KEY,
    hostel_name VARCHAR(100) NOT NULL UNIQUE,
    gender_type ENUM('Male', 'Female', 'Co-ed') NOT NULL,
    total_rooms INT NOT NULL,
    warden_name VARCHAR(100),
    warden_phone VARCHAR(15),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Rooms Table
CREATE TABLE Rooms (
    room_id INT AUTO_INCREMENT PRIMARY KEY,
    hostel_id INT NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    floor INT NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0),
    current_occupancy INT DEFAULT 0 CHECK (current_occupancy >= 0),
    room_type ENUM('Single', 'Double', 'Triple', 'Quad') NOT NULL,
    has_attached_bathroom BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (hostel_id) REFERENCES Hostels(hostel_id) ON DELETE CASCADE,
    UNIQUE KEY unique_room (hostel_id, room_number),
    CHECK (current_occupancy <= capacity)
);

-- Room Allocations Table
CREATE TABLE Allocations (
    allocation_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    room_id INT NOT NULL,
    allocation_date DATE NOT NULL,
    academic_year VARCHAR(20) NOT NULL,
    status ENUM('Active', 'Inactive', 'Pending') DEFAULT 'Active',
    allocated_by VARCHAR(50) DEFAULT 'ADMIN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (room_id) REFERENCES Rooms(room_id) ON DELETE CASCADE,
    UNIQUE KEY unique_active_allocation (student_id, status)
);

-- Swap Requests Table
CREATE TABLE SwapRequests (
    swap_id INT AUTO_INCREMENT PRIMARY KEY,
    requester_id VARCHAR(20) NOT NULL,
    target_id VARCHAR(20) NOT NULL,
    requester_room_id INT NOT NULL,
    target_room_id INT NOT NULL,
    reason TEXT NOT NULL,
    status ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
    request_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_date TIMESTAMP NULL,
    reviewed_by VARCHAR(50),
    admin_remarks TEXT,
    FOREIGN KEY (requester_id) REFERENCES Students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES Students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (requester_room_id) REFERENCES Rooms(room_id),
    FOREIGN KEY (target_room_id) REFERENCES Rooms(room_id),
    CHECK (requester_id != target_id)
);

-- Allocation History Table (for audit trail)
CREATE TABLE AllocationHistory (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    room_id INT NOT NULL,
    hostel_id INT NOT NULL,
    allocation_date DATE NOT NULL,
    deallocation_date DATE,
    reason VARCHAR(255),
    academic_year VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (room_id) REFERENCES Rooms(room_id),
    FOREIGN KEY (hostel_id) REFERENCES Hostels(hostel_id)
);

-- Complaints Table
CREATE TABLE Complaints (
    complaint_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    category ENUM('Maintenance', 'Cleanliness', 'Security', 'Roommate', 'Food', 'Other') NOT NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority ENUM('Low', 'Medium', 'High', 'Urgent') DEFAULT 'Medium',
    status ENUM('Pending', 'In Progress', 'Resolved', 'Closed') DEFAULT 'Pending',
    complaint_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_date TIMESTAMP NULL,
    admin_response TEXT,
    FOREIGN KEY (student_id) REFERENCES Students(student_id) ON DELETE CASCADE
);

-- Admin Users Table
CREATE TABLE AdminUsers (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role ENUM('Super Admin', 'Warden', 'Staff') DEFAULT 'Staff',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger to update room occupancy when allocation is made
DELIMITER //
CREATE TRIGGER after_allocation_insert
AFTER INSERT ON Allocations
FOR EACH ROW
BEGIN
    IF NEW.status = 'Active' THEN
        UPDATE Rooms 
        SET current_occupancy = current_occupancy + 1 
        WHERE room_id = NEW.room_id;
    END IF;
END//

-- Trigger to update room occupancy when allocation is deleted
CREATE TRIGGER after_allocation_delete
AFTER DELETE ON Allocations
FOR EACH ROW
BEGIN
    IF OLD.status = 'Active' THEN
        UPDATE Rooms 
        SET current_occupancy = current_occupancy - 1 
        WHERE room_id = OLD.room_id;
    END IF;
END//

-- Trigger to prevent over-allocation
CREATE TRIGGER before_allocation_insert
BEFORE INSERT ON Allocations
FOR EACH ROW
BEGIN
    DECLARE room_capacity INT;
    DECLARE room_occupancy INT;
    
    SELECT capacity, current_occupancy INTO room_capacity, room_occupancy
    FROM Rooms WHERE room_id = NEW.room_id;
    
    IF room_occupancy >= room_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room is already at full capacity';
    END IF;
END//

-- Trigger to add to allocation history when allocation changes
CREATE TRIGGER after_allocation_status_update
AFTER UPDATE ON Allocations
FOR EACH ROW
BEGIN
    IF OLD.status = 'Active' AND NEW.status = 'Inactive' THEN
        INSERT INTO AllocationHistory (student_id, room_id, hostel_id, allocation_date, deallocation_date, reason, academic_year)
        SELECT NEW.student_id, NEW.room_id, r.hostel_id, NEW.allocation_date, CURDATE(), 'Allocation deactivated', NEW.academic_year
        FROM Rooms r WHERE r.room_id = NEW.room_id;
        
        UPDATE Rooms 
        SET current_occupancy = current_occupancy - 1 
        WHERE room_id = NEW.room_id;
    END IF;
END//

DELIMITER ;

-- ============================================
-- STORED PROCEDURES
-- ============================================

-- Procedure to perform room swap with transaction
DELIMITER //
CREATE PROCEDURE sp_swap_rooms(
    IN p_swap_id INT,
    IN p_admin_username VARCHAR(50)
)
BEGIN
    DECLARE v_requester_id VARCHAR(20);
    DECLARE v_target_id VARCHAR(20);
    DECLARE v_requester_room INT;
    DECLARE v_target_room INT;
    DECLARE v_swap_status VARCHAR(20);
    DECLARE v_requester_alloc_id INT;
    DECLARE v_target_alloc_id INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room swap failed - transaction rolled back';
    END;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Get swap request details
    SELECT requester_id, target_id, requester_room_id, target_room_id, status
    INTO v_requester_id, v_target_id, v_requester_room, v_target_room, v_swap_status
    FROM SwapRequests
    WHERE swap_id = p_swap_id;
    
    -- Check if swap is pending
    IF v_swap_status != 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Swap request is not pending';
    END IF;
    
    -- Get allocation IDs
    SELECT allocation_id INTO v_requester_alloc_id
    FROM Allocations
    WHERE student_id = v_requester_id AND status = 'Active';
    
    SELECT allocation_id INTO v_target_alloc_id
    FROM Allocations
    WHERE student_id = v_target_id AND status = 'Active';
    
    -- Update allocations (swap rooms)
    UPDATE Allocations SET room_id = v_target_room WHERE allocation_id = v_requester_alloc_id;
    UPDATE Allocations SET room_id = v_requester_room WHERE allocation_id = v_target_alloc_id;
    
    -- Update swap request status
    UPDATE SwapRequests
    SET status = 'Approved',
        reviewed_date = NOW(),
        reviewed_by = p_admin_username
    WHERE swap_id = p_swap_id;
    
    -- Add to allocation history
    INSERT INTO AllocationHistory (student_id, room_id, hostel_id, allocation_date, deallocation_date, reason, academic_year)
    SELECT v_requester_id, v_requester_room, r.hostel_id, CURDATE(), CURDATE(), 'Room swap approved', '2024-25'
    FROM Rooms r WHERE r.room_id = v_requester_room;
    
    INSERT INTO AllocationHistory (student_id, room_id, hostel_id, allocation_date, deallocation_date, reason, academic_year)
    SELECT v_target_id, v_target_room, r.hostel_id, CURDATE(), CURDATE(), 'Room swap approved', '2024-25'
    FROM Rooms r WHERE r.room_id = v_target_room;
    
    COMMIT;
END//

-- Procedure to allocate room to student
CREATE PROCEDURE sp_allocate_room(
    IN p_student_id VARCHAR(20),
    IN p_room_id INT,
    IN p_academic_year VARCHAR(20)
)
BEGIN
    DECLARE v_capacity INT;
    DECLARE v_occupancy INT;
    DECLARE v_existing_allocation INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room allocation failed';
    END;
    
    START TRANSACTION;
    
    -- Check for existing active allocation
    SELECT COUNT(*) INTO v_existing_allocation
    FROM Allocations
    WHERE student_id = p_student_id AND status = 'Active';
    
    IF v_existing_allocation > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student already has an active room allocation';
    END IF;
    
    -- Check room capacity
    SELECT capacity, current_occupancy INTO v_capacity, v_occupancy
    FROM Rooms WHERE room_id = p_room_id;
    
    IF v_occupancy >= v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is at full capacity';
    END IF;
    
    -- Insert allocation
    INSERT INTO Allocations (student_id, room_id, allocation_date, academic_year, status)
    VALUES (p_student_id, p_room_id, CURDATE(), p_academic_year, 'Active');
    
    COMMIT;
END//

-- Procedure to reject swap request
CREATE PROCEDURE sp_reject_swap(
    IN p_swap_id INT,
    IN p_admin_username VARCHAR(50),
    IN p_remarks TEXT
)
BEGIN
    UPDATE SwapRequests
    SET status = 'Rejected',
        reviewed_date = NOW(),
        reviewed_by = p_admin_username,
        admin_remarks = p_remarks
    WHERE swap_id = p_swap_id AND status = 'Pending';
END//

DELIMITER ;

-- ============================================
-- SAMPLE DATA INSERTION
-- ============================================

-- Insert Admin Users
INSERT INTO AdminUsers (username, password, full_name, email, role) VALUES
('admin', 'admin123', 'Super Administrator', 'admin@hostelcare.com', 'Super Admin'),
('warden1', 'warden123', 'Dr. Rajesh Kumar', 'rajesh@hostelcare.com', 'Warden'),
('staff1', 'staff123', 'Priya Sharma', 'priya@hostelcare.com', 'Staff');

-- Insert Hostels
INSERT INTO Hostels (hostel_name, gender_type, total_rooms, warden_name, warden_phone, address) VALUES
('Himalaya Boys Hostel', 'Male', 50, 'Dr. Rajesh Kumar', '9876543210', 'North Campus Block A'),
('Nilgiri Girls Hostel', 'Female', 45, 'Dr. Sunita Verma', '9876543211', 'North Campus Block B'),
('Aravalli Boys Hostel', 'Male', 40, 'Mr. Amit Singh', '9876543212', 'South Campus Block C'),
('Vindhya Girls Hostel', 'Female', 42, 'Ms. Kavita Reddy', '9876543213', 'South Campus Block D');

-- Insert Rooms
INSERT INTO Rooms (hostel_id, room_number, floor, capacity, room_type, has_attached_bathroom) VALUES
-- Himalaya Boys Hostel (ID: 1)
(1, '101', 1, 2, 'Double', TRUE),
(1, '102', 1, 2, 'Double', TRUE),
(1, '103', 1, 3, 'Triple', FALSE),
(1, '104', 1, 3, 'Triple', FALSE),
(1, '201', 2, 2, 'Double', TRUE),
(1, '202', 2, 2, 'Double', TRUE),
(1, '203', 2, 4, 'Quad', FALSE),
(1, '204', 2, 1, 'Single', TRUE),
-- Nilgiri Girls Hostel (ID: 2)
(2, 'G101', 1, 2, 'Double', TRUE),
(2, 'G102', 1, 2, 'Double', TRUE),
(2, 'G103', 1, 3, 'Triple', FALSE),
(2, 'G104', 1, 3, 'Triple', FALSE),
(2, 'G201', 2, 2, 'Double', TRUE),
(2, 'G202', 2, 2, 'Double', TRUE),
-- Aravalli Boys Hostel (ID: 3)
(3, 'A101', 1, 2, 'Double', TRUE),
(3, 'A102', 1, 2, 'Double', TRUE),
(3, 'A103', 1, 3, 'Triple', FALSE),
-- Vindhya Girls Hostel (ID: 4)
(4, 'V101', 1, 2, 'Double', TRUE),
(4, 'V102', 1, 2, 'Double', TRUE),
(4, 'V103', 1, 3, 'Triple', FALSE);

-- Insert Students
INSERT INTO Students (student_id, name, email, password, phone, department, year, gender, parent_name, parent_phone, date_of_birth, address) VALUES
('CS2021001', 'Rahul Sharma', 'rahul.sharma@student.com', 'pass123', '9876501001', 'Computer Science', 3, 'Male', 'Mr. Vijay Sharma', '9876501000', '2003-05-15', 'Delhi'),
('CS2021002', 'Priya Patel', 'priya.patel@student.com', 'pass123', '9876501002', 'Computer Science', 3, 'Female', 'Mr. Ramesh Patel', '9876501003', '2003-08-22', 'Gujarat'),
('EE2022001', 'Amit Kumar', 'amit.kumar@student.com', 'pass123', '9876502001', 'Electrical Engineering', 2, 'Male', 'Mrs. Sunita Kumar', '9876502000', '2004-03-10', 'Bihar'),
('EE2022002', 'Sneha Singh', 'sneha.singh@student.com', 'pass123', '9876502002', 'Electrical Engineering', 2, 'Female', 'Mr. Rajesh Singh', '9876502003', '2004-07-18', 'UP'),
('ME2021001', 'Vikram Reddy', 'vikram.reddy@student.com', 'pass123', '9876503001', 'Mechanical Engineering', 3, 'Male', 'Mr. Krishna Reddy', '9876503000', '2003-11-25', 'Telangana'),
('ME2021002', 'Ananya Iyer', 'ananya.iyer@student.com', 'pass123', '9876503002', 'Mechanical Engineering', 3, 'Female', 'Mrs. Lakshmi Iyer', '9876503003', '2003-09-30', 'Tamil Nadu'),
('CS2023001', 'Arjun Mehta', 'arjun.mehta@student.com', 'pass123', '9876504001', 'Computer Science', 1, 'Male', 'Mr. Suresh Mehta', '9876504000', '2005-01-20', 'Maharashtra'),
('CS2023002', 'Divya Nair', 'divya.nair@student.com', 'pass123', '9876504002', 'Computer Science', 1, 'Female', 'Mr. Mohan Nair', '9876504003', '2005-04-12', 'Kerala'),
('EC2022001', 'Rohan Gupta', 'rohan.gupta@student.com', 'pass123', '9876505001', 'Electronics', 2, 'Male', 'Mrs. Meena Gupta', '9876505000', '2004-06-08', 'Rajasthan'),
('EC2022002', 'Pooja Desai', 'pooja.desai@student.com', 'pass123', '9876505002', 'Electronics', 2, 'Female', 'Mr. Kiran Desai', '9876505003', '2004-10-15', 'Gujarat');

-- Allocate rooms to students
INSERT INTO Allocations (student_id, room_id, allocation_date, academic_year, status) VALUES
('CS2021001', 1, '2024-07-01', '2024-25', 'Active'),  -- Rahul in Himalaya 101
('EE2022001', 1, '2024-07-01', '2024-25', 'Active'),  -- Amit in Himalaya 101
('CS2021002', 9, '2024-07-01', '2024-25', 'Active'),  -- Priya in Nilgiri G101
('EE2022002', 9, '2024-07-01', '2024-25', 'Active'),  -- Sneha in Nilgiri G101
('ME2021001', 2, '2024-07-01', '2024-25', 'Active'),  -- Vikram in Himalaya 102
('CS2023001', 2, '2024-07-01', '2024-25', 'Active'),  -- Arjun in Himalaya 102
('ME2021002', 10, '2024-07-01', '2024-25', 'Active'), -- Ananya in Nilgiri G102
('CS2023002', 10, '2024-07-01', '2024-25', 'Active'), -- Divya in Nilgiri G102
('EC2022001', 5, '2024-07-01', '2024-25', 'Active'),  -- Rohan in Himalaya 201
('EC2022002', 13, '2024-07-01', '2024-25', 'Active'); -- Pooja in Nilgiri G201

-- Insert sample swap requests
INSERT INTO SwapRequests (requester_id, target_id, requester_room_id, target_room_id, reason, status) VALUES
('CS2021001', 'ME2021001', 1, 2, 'Want to stay with department mate for project collaboration', 'Pending'),
('EE2022002', 'CS2023002', 9, 10, 'Better roommate compatibility and closer to my classes', 'Pending');

-- Insert sample complaints
INSERT INTO Complaints (student_id, category, subject, description, priority, status) VALUES
('CS2021001', 'Maintenance', 'Broken Window', 'The window in room 101 is broken and needs immediate repair', 'High', 'Pending'),
('CS2021002', 'Cleanliness', 'Washroom Cleaning', 'Common washroom on floor 1 needs better cleaning', 'Medium', 'In Progress'),
('ME2021001', 'Security', 'Gate Security', 'Late night gate access is too strict, affecting students returning from library', 'Medium', 'Pending');

-- ============================================
-- USEFUL QUERIES FOR REPORTS
-- ============================================

-- View all occupied rooms with student details
CREATE VIEW vw_occupied_rooms AS
SELECT 
    h.hostel_name,
    r.room_number,
    r.capacity,
    r.current_occupancy,
    s.student_id,
    s.name AS student_name,
    s.department,
    s.year,
    a.allocation_date
FROM Allocations a
JOIN Students s ON a.student_id = s.student_id
JOIN Rooms r ON a.room_id = r.room_id
JOIN Hostels h ON r.hostel_id = h.hostel_id
WHERE a.status = 'Active'
ORDER BY h.hostel_name, r.room_number;

-- View available rooms
CREATE VIEW vw_available_rooms AS
SELECT 
    h.hostel_name,
    h.gender_type,
    r.room_id,
    r.room_number,
    r.floor,
    r.capacity,
    r.current_occupancy,
    (r.capacity - r.current_occupancy) AS available_beds,
    r.room_type,
    r.has_attached_bathroom
FROM Rooms r
JOIN Hostels h ON r.hostel_id = h.hostel_id
WHERE r.current_occupancy < r.capacity
ORDER BY h.hostel_name, r.room_number;

-- View students without allocation
CREATE VIEW vw_unallocated_students AS
SELECT 
    s.student_id,
    s.name,
    s.email,
    s.department,
    s.year,
    s.gender,
    s.phone
FROM Students s
WHERE NOT EXISTS (
    SELECT 1 FROM Allocations a 
    WHERE a.student_id = s.student_id AND a.status = 'Active'
)
ORDER BY s.year, s.department;

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_student_email ON Students(email);
CREATE INDEX idx_allocation_student ON Allocations(student_id, status);
CREATE INDEX idx_allocation_room ON Allocations(room_id, status);
CREATE INDEX idx_swap_status ON SwapRequests(status);
CREATE INDEX idx_complaint_status ON Complaints(status);

-- End of schema