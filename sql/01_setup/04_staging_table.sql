/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Staging Table Creation
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create a TRANSIENT staging table for deduplication and transformation.
 *   This table sits between raw and analytics layers, providing a clean,
 *   deduplicated dataset.
 * 
 * OBJECTS CREATED:
 *   - STG_BADGE_EVENTS (Transient Table) - Cleaned and deduplicated events
 * 
 * KEY FEATURES:
 *   - TRANSIENT table type (no Fail-safe = lower storage costs)
 *   - Deduplication handled by Task using QUALIFY
 *   - Additional validation and standardization
 *   - Optimized for rebuild from source
 * 
 * TARGET:
 *   SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS
 * 
 * SOURCE:
 *   RAW_BADGE_EVENTS via Stream
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGING_LAYER;

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
COMMENT = 'DEMO: sfe-simple-stream - Staging table for deduplicated and validated badge events'
DATA_RETENTION_TIME_IN_DAYS = 1;  -- Shorter retention for staging

-- Display table structure
DESCRIBE TABLE STG_BADGE_EVENTS;

/*******************************************************************************
 * USAGE NOTES
 * 
 * This table is populated by sfe_raw_to_staging_task which:
 *   1. Reads from sfe_badge_events_stream
 *   2. Deduplicates using QUALIFY ROW_NUMBER()
 *   3. Inserts only unique badge_id + event_timestamp combinations
 * 
 * Table is TRANSIENT because:
 *   - Can be rebuilt from RAW_BADGE_EVENTS if needed
 *   - No Fail-safe period = lower storage costs
 *   - 1-day Time Travel for operational recovery
 ******************************************************************************/
