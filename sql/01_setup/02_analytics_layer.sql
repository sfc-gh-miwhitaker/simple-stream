/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Analytics Layer Setup
 * 
 * WARNING:  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Provision staging and analytics layer tables for badge event processing:
 *   - Staging table for deduplication
 *   - Dimension tables (Users, Zones, Readers) with seed data
 *   - Fact table for access events (clustered by date)
 * 
 * OBJECTS CREATED:
 *   - Staging: STG_BADGE_EVENTS (transient)
 *   - Dimensions: DIM_USERS, DIM_ZONES, DIM_READERS
 *   - Fact: FCT_ACCESS_EVENTS (clustered)
 * 
 * DEPENDENCIES:
 *   - sql/01_setup/01_core_setup.sql (must run first)
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 15 seconds
 ******************************************************************************/

-- ============================================================================
-- PREREQUISITE: Core setup must be complete
-- ============================================================================
-- Run sql/01_setup/01_core_setup.sql first

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- STEP 1: Create Staging Table
-- ============================================================================

USE SCHEMA STAGING_LAYER;

CREATE OR REPLACE TRANSIENT TABLE STG_BADGE_EVENTS (
    badge_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    direction VARCHAR(10),
    ingestion_time TIMESTAMP_NTZ NOT NULL,
    staging_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_stg_badge_events PRIMARY KEY (badge_id, event_timestamp)
)
COMMENT = 'DEMO: sfe-simple-stream - Staging table for deduplicated badge events'
DATA_RETENTION_TIME_IN_DAYS = 1;

-- ============================================================================
-- STEP 2: Create Dimension Tables
-- ============================================================================

USE SCHEMA ANALYTICS_LAYER;

-- Dimension: Users (Type 2 SCD)
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

-- Dimension: Zones
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

-- Dimension: Readers
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

-- ============================================================================
-- STEP 3: Seed Dimension Tables with Sample Data
-- ============================================================================

-- Seed Users (5 sample users)
INSERT INTO DIM_USERS (user_id, user_name, user_type, department, clearance_level, is_active, is_current)
VALUES
    ('USR-001', 'John Smith', 'EMPLOYEE', 'Engineering', 'CONFIDENTIAL', TRUE, TRUE),
    ('USR-002', 'Jane Doe', 'EMPLOYEE', 'HR', 'PUBLIC', TRUE, TRUE),
    ('USR-003', 'Bob Johnson', 'CONTRACTOR', 'IT Support', 'PUBLIC', TRUE, TRUE),
    ('USR-004', 'Alice Williams', 'EMPLOYEE', 'Security', 'SECRET', TRUE, TRUE),
    ('USR-005', 'Mike Davis', 'VISITOR', 'External', 'PUBLIC', TRUE, TRUE);

-- Seed Zones (5 sample zones)
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

-- ============================================================================
-- STEP 4: Create Fact Table (Clustered)
-- ============================================================================

CREATE OR REPLACE TABLE FCT_ACCESS_EVENTS (
    event_key NUMBER AUTOINCREMENT PRIMARY KEY,
    user_key NUMBER NOT NULL,
    zone_key NUMBER NOT NULL,
    badge_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    event_date DATE NOT NULL,
    event_hour NUMBER(2) NOT NULL,
    event_day_of_week NUMBER(1) NOT NULL,
    direction VARCHAR(10),
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    is_restricted_access BOOLEAN,
    is_after_hours BOOLEAN,
    is_weekend BOOLEAN,
    ingestion_time TIMESTAMP_NTZ NOT NULL,
    fact_load_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT fk_fct_user FOREIGN KEY (user_key) REFERENCES DIM_USERS(user_key),
    CONSTRAINT fk_fct_zone FOREIGN KEY (zone_key) REFERENCES DIM_ZONES(zone_key)
)
COMMENT = 'DEMO: sfe-simple-stream - Fact table for badge access events'
CLUSTER BY (event_date);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_LAYER;

-- Verify staging table
DESCRIBE TABLE STAGING_LAYER.STG_BADGE_EVENTS;

-- Verify dimension tables
SHOW TABLES LIKE 'DIM_%' IN SCHEMA ANALYTICS_LAYER;

-- Verify fact table
DESCRIBE TABLE FCT_ACCESS_EVENTS;

-- Verify seed data
SELECT 'DIM_USERS' AS dimension, COUNT(*) AS seed_rows FROM DIM_USERS;
SELECT 'DIM_ZONES' AS dimension, COUNT(*) AS seed_rows FROM DIM_ZONES;

-- Verify clustering
SHOW TABLES LIKE 'FCT_ACCESS_EVENTS' IN SCHEMA ANALYTICS_LAYER;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
--  Staging table created: STG_BADGE_EVENTS (transient, 1-day retention)
--  Dimension tables created: DIM_USERS, DIM_ZONES, DIM_READERS
--  Seed data loaded: 5 users, 5 zones
--  Fact table created: FCT_ACCESS_EVENTS (clustered by event_date)
-- 
-- Next step: Run sql/01_setup/03_enable_tasks.sql
-- ============================================================================

