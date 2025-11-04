/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Dimension Tables Creation
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create dimension tables for the analytics layer implementing Type 2
 *   Slowly Changing Dimensions (SCD) for tracking changes over time.
 * 
 * OBJECTS CREATED:
 *   - DIM_USERS: User attributes with SCD Type 2
 *   - DIM_ZONES: Property layout (buildings, floors, zones, readers)
 *   - DIM_READERS: Badge reader devices (optional - not in original scope)
 * 
 * KEY FEATURES:
 *   - Type 2 SCD for user history tracking
 *   - Hierarchical zone structure
 *   - Sample seed data for testing
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_LAYER;

/*******************************************************************************
 * DIM_USERS: User Dimension with Type 2 SCD
 * 
 * Tracks user attribute changes over time with effective date ranges
 ******************************************************************************/

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
COMMENT = 'DEMO: sfe-simple-stream - User dimension with Type 2 SCD for tracking attribute changes';

/*******************************************************************************
 * DIM_ZONES: Zone/Location Dimension
 * 
 * Hierarchical location structure with reader information
 ******************************************************************************/

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
COMMENT = 'DEMO: sfe-simple-stream - Zone and location dimension with reader information';

/*******************************************************************************
 * DIM_READERS: Badge Reader Dimension (Optional - Not in Original Scope)
 * 
 * This table is for reference but not populated in the demo
 ******************************************************************************/

CREATE OR REPLACE TABLE DIM_READERS (
    -- Surrogate key
    reader_key NUMBER AUTOINCREMENT PRIMARY KEY COMMENT 'Surrogate key for reader dimension',
    
    -- Natural key
    reader_id VARCHAR(50) NOT NULL UNIQUE COMMENT 'Business key: Reader identifier',
    
    -- Reader attributes
    reader_name VARCHAR(100) COMMENT 'Friendly name for reader',
    reader_type VARCHAR(50) COMMENT 'ENTRY, EXIT, BIDIRECTIONAL',
    manufacturer VARCHAR(50) COMMENT 'Device manufacturer',
    model VARCHAR(50) COMMENT 'Device model',
    firmware_version VARCHAR(20) COMMENT 'Firmware version',
    
    -- Status
    is_online BOOLEAN DEFAULT TRUE COMMENT 'Is reader currently online',
    last_heartbeat TIMESTAMP_NTZ COMMENT 'Last communication timestamp',
    
    -- Audit columns
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: sfe-simple-stream - Badge reader device dimension (optional)';

/*******************************************************************************
 * Seed Dimension Data for Testing
 ******************************************************************************/

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

/*******************************************************************************
 * Verification Queries
 ******************************************************************************/

-- Display table structures
DESCRIBE TABLE DIM_USERS;
DESCRIBE TABLE DIM_ZONES;
DESCRIBE TABLE DIM_READERS;

-- Verify seed data loaded
SELECT COUNT(*) AS user_count FROM DIM_USERS;
SELECT COUNT(*) AS zone_count FROM DIM_ZONES;

-- Preview sample data
SELECT * FROM DIM_USERS LIMIT 5;
SELECT * FROM DIM_ZONES LIMIT 5;

/*******************************************************************************
 * TYPE 2 SCD IMPLEMENTATION NOTES
 * 
 * The DIM_USERS table implements Type 2 SCD to track attribute changes:
 * 
 * WHEN A USER ATTRIBUTE CHANGES:
 *   1. Current record: Set is_current = FALSE, effective_end_date = NOW()
 *   2. New record: Insert with is_current = TRUE, effective_start_date = NOW()
 * 
 * QUERY PATTERNS:
 * 
 * Get current users:
 *   SELECT * FROM DIM_USERS WHERE is_current = TRUE;
 * 
 * Point-in-time analysis (who was USR-001 on Jan 1, 2024?):
 *   SELECT * FROM DIM_USERS 
 *   WHERE user_id = 'USR-001'
 *     AND effective_start_date <= '2024-01-01'
 *     AND (effective_end_date IS NULL OR effective_end_date > '2024-01-01');
 * 
 * Full history for a user:
 *   SELECT * FROM DIM_USERS 
 *   WHERE user_id = 'USR-001'
 *   ORDER BY effective_start_date;
 * 
 * The Task (sfe_staging_to_analytics_task) implements MERGE logic to maintain
 * this pattern automatically.
 ******************************************************************************/
