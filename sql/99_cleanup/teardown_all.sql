-- ============================================================================
-- RFID Badge Tracking: Complete Teardown Script
-- ============================================================================
-- Purpose: Remove all objects created by the RFID badge tracking example
--          including database, schemas, tables, streams, tasks, and pipes.
--
-- WARNING: This is destructive! All data will be permanently deleted.
-- ============================================================================

-- Stop all tasks first (to prevent them from running during teardown)
USE DATABASE SNOWFLAKE_EXAMPLE;

ALTER TASK IF EXISTS STAGE_BADGE_TRACKING.raw_to_staging_task SUSPEND;
ALTER TASK IF EXISTS TRANSFORM_BADGE_TRACKING.staging_to_analytics_task SUSPEND;

-- Wait a moment for any running task executions to complete
CALL SYSTEM$WAIT(5);

-- Drop tasks
DROP TASK IF EXISTS TRANSFORM_BADGE_TRACKING.staging_to_analytics_task;
DROP TASK IF EXISTS STAGE_BADGE_TRACKING.raw_to_staging_task;

-- Drop streams
DROP STREAM IF EXISTS STAGE_BADGE_TRACKING.raw_badge_events_stream;

-- Drop pipes
DROP PIPE IF EXISTS STAGE_BADGE_TRACKING.badge_events_pipe;

-- Drop stored procedures
DROP PROCEDURE IF EXISTS STAGE_BADGE_TRACKING.process_badge_events();

-- Drop views in STAGE_BADGE_TRACKING
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_CHANNEL_STATUS;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_INGESTION_METRICS;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_END_TO_END_LATENCY;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_DATA_FRESHNESS;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_PARTITION_EFFICIENCY;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_STREAMING_COSTS;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_TASK_EXECUTION_HISTORY;
DROP VIEW IF EXISTS STAGE_BADGE_TRACKING.V_DATA_QUALITY_SUMMARY;

-- Drop tables in STAGE_BADGE_TRACKING schema
DROP TABLE IF EXISTS STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS;

-- Drop tables in TRANSFORM_BADGE_TRACKING schema
DROP TABLE IF EXISTS TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS;

-- Drop tables in ANALYTICS_BADGE_TRACKING schema
-- Drop fact table first (has foreign keys)
DROP TABLE IF EXISTS ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;

-- Drop dimension tables
DROP TABLE IF EXISTS ANALYTICS_BADGE_TRACKING.DIM_USERS;
DROP TABLE IF EXISTS ANALYTICS_BADGE_TRACKING.DIM_ZONES;

-- Drop schemas
DROP SCHEMA IF EXISTS ANALYTICS_BADGE_TRACKING;
DROP SCHEMA IF EXISTS TRANSFORM_BADGE_TRACKING;
DROP SCHEMA IF EXISTS STAGE_BADGE_TRACKING;

-- Drop warehouse (optional - uncomment if you want to remove it)
-- DROP WAREHOUSE IF EXISTS etl_wh;

-- Database is intentionally preserved for auditing/debugging per cleanup policy.

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- 
-- Verify all objects are removed:
--   SHOW DATABASES LIKE 'SNOWFLAKE_EXAMPLE';  -- Should return no results
--   SHOW WAREHOUSES LIKE 'etl_wh';            -- Should return no results (if dropped)
-- 
-- ============================================================================

