-- ============================================================================
-- RFID Badge Tracking: Raw Landing Table
-- ============================================================================
-- Purpose: Create the raw landing table for RFID badge events ingested via
--          Snowpipe Streaming REST API. This table receives data directly
--          from the PIPE object with in-flight transformations applied.
--
-- Target: SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
-- Source: RFID vendor system via Snowpipe Streaming REST API
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- Create raw landing table
CREATE OR REPLACE TABLE RAW_BADGE_EVENTS (
    -- Primary identifiers
    badge_id VARCHAR(50) NOT NULL COMMENT 'Unique badge identifier (e.g., BADGE-12345)',
    user_id VARCHAR(50) NOT NULL COMMENT 'User associated with badge (e.g., USR-001)',
    
    -- Location and device information
    zone_id VARCHAR(50) NOT NULL COMMENT 'Zone where event occurred (e.g., ZONE-LOBBY-1)',
    reader_id VARCHAR(50) NOT NULL COMMENT 'Badge reader that captured event (e.g., RDR-101)',
    
    -- Event timing
    event_timestamp TIMESTAMP_NTZ NOT NULL COMMENT 'Timestamp when badge was scanned (timezone-naive)',
    
    -- Signal information
    signal_strength NUMBER(5, 2) COMMENT 'RFID signal strength in dBm (-999 if unknown)',
    signal_quality VARCHAR(10) COMMENT 'Signal quality: WEAK, MEDIUM, STRONG',
    
    -- Event details
    direction VARCHAR(10) COMMENT 'Direction of movement: ENTRY, EXIT, or null',
    
    -- Audit columns
    ingestion_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'When record was ingested into Snowflake',
    raw_json VARIANT COMMENT 'Original JSON payload for debugging'
)
COMMENT = 'Raw RFID badge events ingested via Snowpipe Streaming REST API';

-- Note: event_timestamp NOT NULL constraint enforced in column definition above
-- Snowflake uses micro-partitions for automatic optimization; explicit indexes not needed

-- Display table structure
DESCRIBE TABLE RAW_BADGE_EVENTS;

