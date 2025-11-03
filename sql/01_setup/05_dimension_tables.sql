-- ============================================================================
-- RFID Badge Tracking: Dimension Tables
-- ============================================================================
-- Purpose: Create dimension tables for the analytics layer implementing
--          Type 2 Slowly Changing Dimensions (SCD) for tracking changes
--          over time.
--
-- Tables:
--   - DIM_USERS: User attributes with SCD Type 2
--   - DIM_ZONES: Property layout (buildings, floors, zones, readers)
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- ============================================================================
-- DIM_USERS: User Dimension with Type 2 SCD
-- ============================================================================

CREATE OR REPLACE TABLE DIM_USERS (
    -- Surrogate key
    user_key NUMBER AUTOINCREMENT PRIMARY KEY COMMENT 'Surrogate key for user dimension',
    
    -- Natural key
    user_id VARCHAR(50) NOT NULL COMMENT 'Business key: User identifier',
    
    -- User attributes
    user_name VARCHAR(100) COMMENT 'Full name of user',
    user_type VARCHAR(20) COMMENT 'EMPLOYEE, CONTRACTOR, VISITOR, VENDOR',
    department VARCHAR(50) COMMENT 'Department or organization',
    email VARCHAR(100) COMMENT 'Email address',
    phone VARCHAR(20) COMMENT 'Phone number',
    
    -- Access level
    clearance_level VARCHAR(20) COMMENT 'Security clearance: PUBLIC, CONFIDENTIAL, SECRET',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Is this user currently active',
    
    -- Type 2 SCD columns
    effective_start_date TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP() COMMENT 'When this version became effective',
    effective_end_date TIMESTAMP_NTZ COMMENT 'When this version expired (null if current)',
    is_current BOOLEAN DEFAULT TRUE COMMENT 'Is this the current record for the user',
    
    -- Audit columns
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'User dimension with Type 2 SCD for tracking attribute changes over time';

-- Note: Snowflake uses automatic micro-partitioning for optimization
-- No explicit indexes needed - queries on user_id will be automatically optimized

-- ============================================================================
-- DIM_ZONES: Zone/Location Dimension
-- ============================================================================

CREATE OR REPLACE TABLE DIM_ZONES (
    -- Surrogate key
    zone_key NUMBER AUTOINCREMENT PRIMARY KEY COMMENT 'Surrogate key for zone dimension',
    
    -- Natural keys
    zone_id VARCHAR(50) NOT NULL UNIQUE COMMENT 'Business key: Zone identifier',
    reader_id VARCHAR(50) COMMENT 'Badge reader identifier in this zone',
    
    -- Location hierarchy
    building_name VARCHAR(100) NOT NULL COMMENT 'Building name or identifier',
    floor_number NUMBER(3) COMMENT 'Floor number',
    zone_name VARCHAR(100) NOT NULL COMMENT 'Zone name (e.g., Main Lobby, Server Room)',
    zone_type VARCHAR(50) COMMENT 'LOBBY, OFFICE, CONFERENCE_ROOM, SECURE_AREA, PARKING',
    
    -- Zone attributes
    capacity NUMBER COMMENT 'Maximum occupancy',
    requires_clearance VARCHAR(20) COMMENT 'Required clearance level: null, CONFIDENTIAL, SECRET',
    is_monitored BOOLEAN DEFAULT TRUE COMMENT 'Is zone under active monitoring',
    is_restricted BOOLEAN DEFAULT FALSE COMMENT 'Is zone access-restricted',
    
    -- Reader information
    reader_location VARCHAR(100) COMMENT 'Physical location of reader',
    reader_type VARCHAR(50) COMMENT 'ENTRY, EXIT, BIDIRECTIONAL',
    
    -- Coordinates (optional)
    latitude NUMBER(10, 6) COMMENT 'Geographic latitude',
    longitude NUMBER(10, 6) COMMENT 'Geographic longitude',
    
    -- Audit columns
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Zone and location dimension with reader information';

-- Note: Snowflake uses automatic micro-partitioning for optimization
-- No explicit indexes needed - queries on zone_id and reader_id will be automatically optimized

-- ============================================================================
-- Seed Dimension Data
-- ============================================================================

-- Insert sample users
INSERT INTO DIM_USERS (user_id, user_name, user_type, department, clearance_level, is_active, is_current)
VALUES
    ('USR-001', 'John Smith', 'EMPLOYEE', 'Engineering', 'CONFIDENTIAL', TRUE, TRUE),
    ('USR-002', 'Jane Doe', 'EMPLOYEE', 'HR', 'PUBLIC', TRUE, TRUE),
    ('USR-003', 'Bob Johnson', 'CONTRACTOR', 'IT Support', 'PUBLIC', TRUE, TRUE),
    ('USR-004', 'Alice Williams', 'EMPLOYEE', 'Security', 'SECRET', TRUE, TRUE),
    ('USR-005', 'Mike Davis', 'VISITOR', 'External', 'PUBLIC', TRUE, TRUE);

-- Insert sample zones
INSERT INTO DIM_ZONES (
    zone_id, reader_id, building_name, floor_number, zone_name, zone_type,
    capacity, requires_clearance, is_restricted, reader_location, reader_type
)
VALUES
    ('ZONE-LOBBY-1', 'RDR-101', 'Main Building', 1, 'Main Lobby', 'LOBBY', 100, NULL, FALSE, 'Main Entrance', 'BIDIRECTIONAL'),
    ('ZONE-OFFICE-2A', 'RDR-201', 'Main Building', 2, 'Engineering Office 2A', 'OFFICE', 30, 'CONFIDENTIAL', TRUE, 'Floor 2 East', 'ENTRY'),
    ('ZONE-SERVER-B1', 'RDR-B101', 'Main Building', -1, 'Server Room B1', 'SECURE_AREA', 5, 'SECRET', TRUE, 'Basement Security Door', 'BIDIRECTIONAL'),
    ('ZONE-CONF-3B', 'RDR-301', 'Main Building', 3, 'Conference Room 3B', 'CONFERENCE_ROOM', 20, NULL, FALSE, 'Floor 3 West', 'ENTRY'),
    ('ZONE-PARKING-1', 'RDR-P01', 'Parking Structure', 1, 'Employee Parking Level 1', 'PARKING', 200, NULL, FALSE, 'Garage Entry', 'ENTRY');

-- Display table structures and sample data
DESCRIBE TABLE DIM_USERS;
DESCRIBE TABLE DIM_ZONES;

-- Verify seed data loaded
SELECT COUNT(*) AS user_count FROM DIM_USERS;
SELECT COUNT(*) AS zone_count FROM DIM_ZONES;

-- ============================================================================
-- TYPE 2 SCD NOTES
-- ============================================================================
-- 
-- The DIM_USERS table implements Type 2 SCD to track attribute changes:
-- 
-- When a user attribute changes:
--   1. Current record: Set is_current = FALSE, effective_end_date = NOW()
--   2. New record: Insert with is_current = TRUE, effective_start_date = NOW()
-- 
-- Example query to get current users:
--   SELECT * FROM DIM_USERS WHERE is_current = TRUE;
-- 
-- Example query for point-in-time analysis:
--   SELECT * FROM DIM_USERS 
--   WHERE user_id = 'USR-001'
--     AND effective_start_date <= '2024-01-01'
--     AND (effective_end_date IS NULL OR effective_end_date > '2024-01-01');
-- 
-- The Task will implement MERGE logic to maintain this pattern.
-- ============================================================================

