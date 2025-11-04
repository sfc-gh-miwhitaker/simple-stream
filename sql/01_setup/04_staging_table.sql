/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Staging Table
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Create transient staging table used by pipeline tasks.
 * OBJECTS: STG_BADGE_EVENTS
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
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
