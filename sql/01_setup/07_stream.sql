/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: CDC Stream
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Expose RAW_BADGE_EVENTS changes to downstream tasks.
 * OBJECTS: sfe_badge_events_stream
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

CREATE OR REPLACE STREAM sfe_badge_events_stream
ON TABLE RAW_BADGE_EVENTS
COMMENT = 'DEMO: sfe-simple-stream - CDC stream for RAW_BADGE_EVENTS';
