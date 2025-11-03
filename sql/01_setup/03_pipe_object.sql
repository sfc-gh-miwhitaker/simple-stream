-- ============================================================================
-- RFID Badge Tracking: PIPE Object with In-Flight Transformations
-- ============================================================================
-- Purpose: Create the PIPE object that receives data from the Snowpipe
--          Streaming REST API and applies in-flight transformations during
--          ingestion. This centralizes data cleansing, validation, and
--          enrichment logic at the ingestion layer.
--
-- Key Features:
--   - Type casting and validation (TRY_TO_TIMESTAMP_NTZ)
--   - Default value handling (COALESCE for nulls)
--   - Data standardization (UPPER, TRIM)
--   - Enrichment (CASE for signal_quality)
--   - Filtering (WHERE clause for required fields)
--   - Audit trail (CURRENT_TIMESTAMP, raw JSON preservation)
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- Create PIPE with in-flight transformations
CREATE OR REPLACE PIPE badge_events_pipe
AS COPY INTO RAW_BADGE_EVENTS
FROM (
  SELECT 
    -- Extract and clean identifiers
    $1:badge_id::STRING as badge_id,
    $1:user_id::STRING as user_id,
    $1:zone_id::STRING as zone_id,
    $1:reader_id::STRING as reader_id,
    
    -- Parse and validate timestamp (cast to STRING first, then TIMESTAMP)
    TO_TIMESTAMP_NTZ($1:event_timestamp::STRING) as event_timestamp,
    
    -- Handle missing signal strength with default
    COALESCE($1:signal_strength::NUMBER, -999) as signal_strength,
    
    -- Standardize direction to uppercase
    UPPER($1:direction::STRING) as direction,
    
    -- Enrich: Calculate signal quality from strength
    CASE 
      WHEN $1:signal_strength::NUMBER < -80 THEN 'WEAK'
      WHEN $1:signal_strength::NUMBER < -60 THEN 'MEDIUM'
      ELSE 'STRONG'
    END as signal_quality,
    
    -- Audit: Record ingestion timestamp
    CURRENT_TIMESTAMP() as ingestion_time,
    
    -- Preserve original JSON for debugging and replay
    $1 as raw_json
    
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
);

-- Verify PIPE creation
SHOW PIPES IN SCHEMA STAGE_BADGE_TRACKING;

-- Display PIPE details
DESC PIPE badge_events_pipe;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 
-- To use this PIPE via REST API:
-- 
-- 1. Get control plane hostname:
--    GET /v2/streaming/hostname
-- 
-- 2. Open a channel:
--    POST /v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/STAGE_BADGE_TRACKING/pipes/BADGE_EVENTS_PIPE:open-channel
--    Body: {"channel_name": "rfid_channel_001"}
-- 
-- 3. Insert rows:
--    POST /v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/STAGE_BADGE_TRACKING/pipes/BADGE_EVENTS_PIPE/channels/rfid_channel_001:insert-rows
--    Body: {"rows": [{"badge_id": "BADGE-001", ...}]}
-- 
-- See docs/REST_API_GUIDE.md for complete examples with authentication.
-- ============================================================================

