# 🏠 HostelCare - Hostel Room Allocation and Swap Management System

A comprehensive full-stack web application for managing hostel room allocations, swap requests, and student complaints with a strong focus on database management and SQL concepts.

## 🎯 Features

### Student Portal

- ✅ Secure login system
- 🏠 View room details and roommate information
- 🔄 Request room swaps with other students
- 📝 Submit and track complaints
- 📊 Real-time status updates

### Admin Dashboard

- 👥 Complete student management
- 🏠 Room allocation system
- 🔄 Approve/reject swap requests
- 📝 Manage complaints
- 📊 Dashboard with statistics
- ➕ Add new students

## 🛠️ Technology Stack

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Node.js, Express.js
- **Database**: MySQL
- **Architecture**: RESTful API

## 📋 Database Features

### DBMS Concepts Implemented

1. **Normalization**: All tables are in 3NF
2. **Constraints**: Primary keys, foreign keys, CHECK constraints
3. **Triggers**: Automatic room occupancy updates, allocation history
4. **Stored Procedures**: Room swap transaction logic, room allocation
5. **Transactions**: ACID properties with COMMIT/ROLLBACK
6. **Views**: Pre-defined views for reports
7. **Indexes**: Performance optimization

### Database Schema

- Students
- Hostels
- Rooms
- Allocations
- SwapRequests
- AllocationHistory
- Complaints
- AdminUsers

## 🚀 Installation Steps

### Prerequisites

1. **Node.js** (v14 or higher)
2. **MySQL** (v8 or higher)
3. **VS Code** (or any code editor)

### Step 1: Install MySQL

#### Windows:

1. Download MySQL Installer from https://dev.mysql.com/downloads/installer/
2. Run the installer and choose "Developer Default"
3. Set root password (remember this!)
4. Complete installation

#### Mac:

```bash
brew install mysql
brew services start mysql
mysql_secure_installation
```

#### Linux:

```bash
sudo apt update
sudo apt install mysql-server
sudo mysql_secure_installation
```

### Step 2: Set Up the Database

1. Open MySQL Command Line or MySQL Workbench
2. Login with root user:
   ```bash
   mysql -u root -p
   ```
3. Navigate to the database folder and run:
   ```bash
   source /path/to/hostelcare/database/schema.sql
   ```
   OR copy the entire contents of `database/schema.sql` and paste in MySQL

### Step 3: Install Node.js Dependencies

1. Open VS Code
2. Open Terminal in VS Code (Ctrl + ` or View > Terminal)
3. Navigate to the project folder:
   ```bash
   cd hostelcare
   ```
4. Install dependencies:
   ```bash
   npm install
   ```

### Step 4: Configure Database Connection

1. Open `server.js` in VS Code
2. Find the database configuration (around line 13):
   ```javascript
   const db = mysql.createConnection({
     host: "localhost",
     user: "root",
     password: "", // CHANGE THIS to your MySQL password
     database: "hostelcare",
   });
   ```
3. Update the `password` field with your MySQL root password

### Step 5: Run the Application

1. In VS Code terminal, run:
   ```bash
   npm start
   ```
2. You should see:
   ```
   ✅ Connected to MySQL Database
   🚀 HostelCare Server running on http://localhost:3000
   ```

### Step 6: Access the Application

Open your browser and navigate to:

- **Student Portal**: http://localhost:3000/index.html
- **Admin Dashboard**: http://localhost:3000/admin-login.html

## 🔐 Default Login Credentials

### Admin Login

- Username: `admin`
- Password: `admin123`

### Student Login (Sample Accounts)

- Email: `rahul.sharma@student.com`
- Password: `pass123`

Other student accounts:

- `priya.patel@student.com` / `pass123`
- `amit.kumar@student.com` / `pass123`
- `sneha.singh@student.com` / `pass123`

## 📁 Project Structure

```
hostelcare/
├── database/
│   └── schema.sql          # Complete database schema with sample data
├── public/                 # Frontend files
│   ├── index.html         # Student login page
│   ├── student-dashboard.html
│   ├── swap-request.html
│   ├── submit-complaint.html
│   ├── admin-login.html
│   └── admin-dashboard.html
├── server.js              # Main backend server
├── package.json           # Node.js dependencies
└── README.md             # This file
```

## 🎨 UI Features

- **Colorful & Interactive**: Modern gradient designs
- **Responsive**: Works on desktop, tablet, and mobile
- **User-Friendly**: Intuitive navigation and forms
- **Real-time Updates**: Live data from database

## 📊 SQL Queries & Reports

The system includes pre-built views for reports:

1. **Occupied Rooms Report**: `SELECT * FROM vw_occupied_rooms;`
2. **Available Rooms Report**: `SELECT * FROM vw_available_rooms;`
3. **Unallocated Students**: `SELECT * FROM vw_unallocated_students;`

## 🔧 Troubleshooting

### Problem: "Cannot connect to database"

**Solution**:

- Make sure MySQL is running
- Check username/password in server.js
- Verify database 'hostelcare' exists

### Problem: "Port 3000 already in use"

**Solution**:

- Change PORT in server.js (line 6)
- Or kill the process using port 3000

### Problem: "Module not found"

**Solution**:

- Run `npm install` again
- Delete `node_modules` folder and run `npm install`

### Problem: Database errors

**Solution**:

- Re-run the schema.sql file
- Check MySQL is running
- Verify all tables are created

## 📝 DBMS Concepts Demonstration

### 1. Triggers

```sql
-- Automatic room occupancy update
CREATE TRIGGER after_allocation_insert
AFTER INSERT ON Allocations
FOR EACH ROW
BEGIN
    UPDATE Rooms SET current_occupancy = current_occupancy + 1;
END;
```

### 2. Stored Procedures

```sql
-- Room swap with transaction
CALL sp_swap_rooms(swap_id, admin_username);
```

### 3. Transactions

```sql
START TRANSACTION;
-- Swap logic
COMMIT; -- or ROLLBACK on error
```

## 🎓 Academic Project Notes

This project demonstrates:

- ✅ Complete DBMS lifecycle
- ✅ Normalization (3NF)
- ✅ Entity-Relationship design
- ✅ Complex SQL queries
- ✅ Transaction management
- ✅ Trigger implementation
- ✅ Stored procedures
- ✅ Referential integrity
- ✅ Full-stack integration

## 📱 Screenshots

### Student Dashboard

- View room details
- See roommate information
- Track swap requests
- Submit complaints

### Admin Dashboard

- Manage all students
- Allocate rooms
- Approve/reject swaps
- Handle complaints
- View statistics

## 🤝 Support

For any issues or questions:

1. Check the troubleshooting section
2. Review database connection settings
3. Ensure all dependencies are installed
4. Verify MySQL is running

## 📄 License

This project is created for educational purposes.

---

**Made with ❤️ for DBMS Academic Project**
