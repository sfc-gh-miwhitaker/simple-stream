-- ============================================================================
-- RFID Badge Tracking: Fact Table
-- ============================================================================
-- Purpose: Create the fact table for access events with clustering for
--          optimal query performance on time-series data.
--
-- Target: SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
-- Source: STG_BADGE_EVENTS joined with dimension tables
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- ============================================================================
-- FCT_ACCESS_EVENTS: Access Event Fact Table
-- ============================================================================

CREATE OR REPLACE TABLE FCT_ACCESS_EVENTS (
    -- Surrogate key
    event_key NUMBER AUTOINCREMENT PRIMARY KEY COMMENT 'Surrogate key for event fact',
    
    -- Dimension foreign keys
    user_key NUMBER NOT NULL COMMENT 'Foreign key to DIM_USERS',
    zone_key NUMBER NOT NULL COMMENT 'Foreign key to DIM_ZONES',
    
    -- Degenerate dimensions (attributes carried in fact)
    badge_id VARCHAR(50) NOT NULL COMMENT 'Badge identifier',
    reader_id VARCHAR(50) NOT NULL COMMENT 'Reader identifier',
    
    -- Date/Time dimensions
    event_timestamp TIMESTAMP_NTZ NOT NULL COMMENT 'When event occurred',
    event_date DATE NOT NULL COMMENT 'Event date (for clustering)',
    event_hour NUMBER(2) NOT NULL COMMENT 'Hour of day (0-23)',
    event_day_of_week NUMBER(1) NOT NULL COMMENT 'Day of week (0=Sunday)',
    
    -- Event attributes
    direction VARCHAR(10) COMMENT 'ENTRY, EXIT, or null',
    
    -- Measures/Metrics
    signal_strength NUMBER(5, 2) COMMENT 'Signal strength in dBm',
    signal_quality VARCHAR(10) COMMENT 'WEAK, MEDIUM, STRONG',
    
    -- Flags for analytics
    is_restricted_access BOOLEAN COMMENT 'Was this a restricted zone access',
    is_after_hours BOOLEAN COMMENT 'Did event occur outside business hours (before 6am or after 10pm)',
    is_weekend BOOLEAN COMMENT 'Did event occur on weekend',
    
    -- Audit columns
    ingestion_time TIMESTAMP_NTZ NOT NULL COMMENT 'When raw event was ingested',
    fact_load_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'When fact record was created',
    
    -- Foreign key constraints
    CONSTRAINT fk_fct_user FOREIGN KEY (user_key) REFERENCES DIM_USERS(user_key),
    CONSTRAINT fk_fct_zone FOREIGN KEY (zone_key) REFERENCES DIM_ZONES(zone_key)
)
COMMENT = 'Fact table for RFID badge access events with time-series optimization'
CLUSTER BY (event_date);  -- Cluster by date for time-series query performance

-- ============================================================================
-- Clustering Strategy
-- ============================================================================
-- 
-- We cluster on event_date (not event_timestamp) because:
--   1. Most queries filter by date ranges
--   2. Date has lower cardinality than timestamp (better clustering)
--   3. Reduces micro-partition scanning for date-based queries
--   4. Optimal for time-series analytics
-- 
-- This follows the principle: cluster on lowest cardinality column
-- that appears in WHERE clauses.
-- ============================================================================

-- Display table structure
DESCRIBE TABLE FCT_ACCESS_EVENTS;

-- Verify clustering
SHOW TABLES LIKE 'FCT_ACCESS_EVENTS' IN SCHEMA ANALYTICS_BADGE_TRACKING;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 
-- Optimal Query Patterns:
-- 
-- 1. Time-series queries (leverages clustering):
--    SELECT * FROM FCT_ACCESS_EVENTS 
--    WHERE event_date BETWEEN '2024-01-01' AND '2024-01-31';
-- 
-- 2. User access history:
--    SELECT e.*, u.user_name, z.zone_name
--    FROM FCT_ACCESS_EVENTS e
--    JOIN DIM_USERS u ON e.user_key = u.user_key
--    JOIN DIM_ZONES z ON e.zone_key = z.zone_key
--    WHERE e.badge_id = 'BADGE-12345'
--      AND e.event_date >= CURRENT_DATE() - 7;
-- 
-- 3. Zone occupancy tracking:
--    SELECT zone_key, COUNT(*) as entry_count
--    FROM FCT_ACCESS_EVENTS
--    WHERE event_date = CURRENT_DATE()
--      AND direction = 'ENTRY'
--    GROUP BY zone_key;
-- 
-- 4. After-hours access alerts:
--    SELECT * FROM FCT_ACCESS_EVENTS
--    WHERE is_after_hours = TRUE
--      AND is_restricted_access = TRUE
--      AND event_date = CURRENT_DATE();
-- 
-- Monitor Clustering Health:
--    SELECT SYSTEM$CLUSTERING_INFORMATION('FCT_ACCESS_EVENTS');
-- ============================================================================

