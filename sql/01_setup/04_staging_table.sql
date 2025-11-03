-- ============================================================================
-- RFID Badge Tracking: Staging Table
-- ============================================================================
-- Purpose: Create a TRANSIENT staging table for deduplication and
--          transformation. This table sits between raw and analytics layers,
--          providing a clean, deduplicated dataset.
--
-- Key Features:
--   - TRANSIENT table type (no Fail-safe = lower storage costs)
--   - Deduplication handled by Task using QUALIFY
--   - Additional validation and standardization
--   - Optimized for rebuild from source
--
-- Target: SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
-- Source: RAW_BADGE_EVENTS via Stream
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA TRANSFORM_BADGE_TRACKING;

-- Create transient staging table
CREATE OR REPLACE TRANSIENT TABLE STG_BADGE_EVENTS (
    -- Primary identifiers
    badge_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    
    -- Location and device
    zone_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    
    -- Event timing
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    
    -- Signal information
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    
    -- Event details
    direction VARCHAR(10),
    
    -- Audit columns
    ingestion_time TIMESTAMP_NTZ NOT NULL,
    staging_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Primary key for analytics
    CONSTRAINT pk_stg_badge_events PRIMARY KEY (badge_id, event_timestamp)
)
COMMENT = 'Staging table for deduplicated and validated badge events'
DATA_RETENTION_TIME_IN_DAYS = 1;  -- Shorter retention for staging

-- Display table structure
DESCRIBE TABLE STG_BADGE_EVENTS;

-- ============================================================================
-- DESIGN NOTES
-- ============================================================================
-- 
-- TRANSIENT TABLE:
--   - Used for intermediate, rebuildable data
--   - No 7-day Fail-safe period = significant cost savings
--   - Can be fully reconstructed from RAW_BADGE_EVENTS
--   - Ideal for ETL staging layers
-- 
-- DATA RETENTION:
--   - Set to 1 day (sufficient for operational recovery)
--   - Can be set to 0 if historical staging data not needed
--   - Reduces storage costs for high-volume ingestion
-- 
-- DEDUPLICATION:
--   - Task will use QUALIFY with ROW_NUMBER() to deduplicate
--   - Partitioned by (badge_id, event_timestamp)
--   - Keeps most recent ingestion_time per duplicate
-- ============================================================================

