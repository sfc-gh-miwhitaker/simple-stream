/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Snowpipe Streaming Pipe
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Define ingestion pipe with basic cleansing and audit columns.
 * OBJECTS: sfe_badge_events_pipe
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

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
