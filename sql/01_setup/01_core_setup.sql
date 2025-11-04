/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Core Infrastructure Setup
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Provision the core infrastructure for badge event streaming:
 *   - Database and schemas (layered architecture)
 *   - Raw landing table for Snowpipe Streaming
 *   - Snowpipe object with transformation logic
 *   - CDC stream for downstream processing
 * 
 * OBJECTS CREATED:
 *   - Database: SNOWFLAKE_EXAMPLE
 *   - Schemas: RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER
 *   - Table: RAW_BADGE_EVENTS
 *   - Pipe: sfe_badge_events_pipe
 *   - Stream: sfe_badge_events_stream
 * 
 * DEPENDENCIES:
 *   - None (first script to run)
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 10 seconds
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Create Database and Schemas
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS RAW_INGESTION
    COMMENT = 'DEMO: sfe-simple-stream - Raw landing tables and PIPE objects';

CREATE SCHEMA IF NOT EXISTS STAGING_LAYER
    COMMENT = 'DEMO: sfe-simple-stream - Staging tables for cleaning and deduplication';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_LAYER
    COMMENT = 'DEMO: sfe-simple-stream - Dimensional model for the demo';

USE SCHEMA RAW_INGESTION;

-- ============================================================================
-- STEP 2: Create Raw Landing Table
-- ============================================================================

CREATE OR REPLACE TABLE RAW_BADGE_EVENTS (
    badge_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    direction VARCHAR(10),
    ingestion_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    raw_json VARIANT
)
COMMENT = 'DEMO: sfe-simple-stream - Raw RFID badge events ingested via Snowpipe Streaming REST API';

-- ============================================================================
-- STEP 3: Create Snowpipe Streaming Object
-- ============================================================================

CREATE OR REPLACE PIPE sfe_badge_events_pipe
  COMMENT = 'DEMO: sfe-simple-stream - Snowpipe Streaming REST API endpoint for badge events'
AS COPY INTO RAW_BADGE_EVENTS
FROM (
  SELECT
    $1:badge_id::STRING AS badge_id,
    $1:user_id::STRING AS user_id,
    $1:zone_id::STRING AS zone_id,
    $1:reader_id::STRING AS reader_id,
    TO_TIMESTAMP_NTZ($1:event_timestamp::STRING) AS event_timestamp,
    COALESCE($1:signal_strength::NUMBER, -999) AS signal_strength,
    UPPER($1:direction::STRING) AS direction,
    CASE
      WHEN $1:signal_strength::NUMBER < -80 THEN 'WEAK'
      WHEN $1:signal_strength::NUMBER < -60 THEN 'MEDIUM'
      ELSE 'STRONG'
    END AS signal_quality,
    CURRENT_TIMESTAMP() AS ingestion_time,
    $1 AS raw_json
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
);

-- ============================================================================
-- STEP 4: Create CDC Stream
-- ============================================================================

CREATE OR REPLACE STREAM sfe_badge_events_stream
ON TABLE RAW_BADGE_EVENTS
COMMENT = 'DEMO: sfe-simple-stream - CDC stream for RAW_BADGE_EVENTS';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify database and schemas
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Verify raw table structure
DESCRIBE TABLE RAW_BADGE_EVENTS;

-- Verify pipe exists
SHOW PIPES IN SCHEMA RAW_INGESTION;

-- Verify stream exists
SHOW STREAMS IN SCHEMA RAW_INGESTION;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- ✅ Database created: SNOWFLAKE_EXAMPLE
-- ✅ Schemas created: RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER
-- ✅ Table created: RAW_BADGE_EVENTS (10 columns)
-- ✅ Pipe created: sfe_badge_events_pipe
-- ✅ Stream created: sfe_badge_events_stream
-- 
-- Next step: Run sql/01_setup/02_analytics_layer.sql
-- ============================================================================

