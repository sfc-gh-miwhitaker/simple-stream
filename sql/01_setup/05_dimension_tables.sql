/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Dimension Tables
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Provision demo dimension tables with seed data.
 * OBJECTS: DIM_USERS, DIM_ZONES, DIM_READERS
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_LAYER;

CREATE OR REPLACE TABLE DIM_USERS (
    user_key NUMBER AUTOINCREMENT PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    user_name VARCHAR(100),
    user_type VARCHAR(20),
    department VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    clearance_level VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    effective_start_date TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    effective_end_date TIMESTAMP_NTZ,
    is_current BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: sfe-simple-stream - User dimension with Type 2 SCD';

CREATE OR REPLACE TABLE DIM_ZONES (
    zone_key NUMBER AUTOINCREMENT PRIMARY KEY,
    zone_id VARCHAR(50) NOT NULL UNIQUE,
    reader_id VARCHAR(50),
    building_name VARCHAR(100) NOT NULL,
    floor_number NUMBER(3),
    zone_name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50),
    capacity NUMBER,
    requires_clearance VARCHAR(20),
    is_monitored BOOLEAN DEFAULT TRUE,
    is_restricted BOOLEAN DEFAULT FALSE,
    reader_location VARCHAR(100),
    reader_type VARCHAR(50),
    latitude NUMBER(10, 6),
    longitude NUMBER(10, 6),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: sfe-simple-stream - Zone dimension for badge analytics';

CREATE OR REPLACE TABLE DIM_READERS (
    reader_key NUMBER AUTOINCREMENT PRIMARY KEY,
    reader_id VARCHAR(50) NOT NULL UNIQUE,
    reader_name VARCHAR(100),
    reader_type VARCHAR(50),
    manufacturer VARCHAR(50),
    model VARCHAR(50),
    firmware_version VARCHAR(20),
    is_online BOOLEAN DEFAULT TRUE,
    last_heartbeat TIMESTAMP_NTZ,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: sfe-simple-stream - Badge reader dimension';

INSERT INTO DIM_USERS (user_id, user_name, user_type, department, clearance_level, is_active, is_current)
VALUES
    ('USR-001', 'John Smith', 'EMPLOYEE', 'Engineering', 'CONFIDENTIAL', TRUE, TRUE),
    ('USR-002', 'Jane Doe', 'EMPLOYEE', 'HR', 'PUBLIC', TRUE, TRUE),
    ('USR-003', 'Bob Johnson', 'CONTRACTOR', 'IT Support', 'PUBLIC', TRUE, TRUE),
    ('USR-004', 'Alice Williams', 'EMPLOYEE', 'Security', 'SECRET', TRUE, TRUE),
    ('USR-005', 'Mike Davis', 'VISITOR', 'External', 'PUBLIC', TRUE, TRUE);

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
