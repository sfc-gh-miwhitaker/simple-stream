/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Raw Landing Table
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Create RAW_BADGE_EVENTS Snowpipe streaming target.
 * OBJECTS: RAW_BADGE_EVENTS
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

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
