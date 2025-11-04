/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Complete Teardown
 * ⚠️ DESTRUCTIVE OPERATION - ALL DATA WILL BE PERMANENTLY DELETED
 * PURPOSE: Remove all demo objects while preserving SNOWFLAKE_EXAMPLE database.
 * CLEANUP RULE: Drop schemas, tables, streams, tasks, pipes, secrets, repo, warehouse, API integration.
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Suspend and Drop Tasks
-- ============================================================================
-- Tasks must be suspended before dropping, in reverse dependency order

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Suspend child tasks first
ALTER TASK IF EXISTS STAGING_LAYER.sfe_staging_to_analytics_task SUSPEND;
ALTER TASK IF EXISTS RAW_INGESTION.sfe_alert_on_data_quality_violations SUSPEND;

-- Suspend parent task
ALTER TASK IF EXISTS RAW_INGESTION.sfe_raw_to_staging_task SUSPEND;

-- Wait for any running task executions to complete
CALL SYSTEM$WAIT(5);

-- Drop tasks
DROP TASK IF EXISTS RAW_INGESTION.sfe_alert_on_data_quality_violations;
DROP TASK IF EXISTS STAGING_LAYER.sfe_staging_to_analytics_task;
DROP TASK IF EXISTS RAW_INGESTION.sfe_raw_to_staging_task;

-- ============================================================================
-- STEP 2: Drop Data Metric Functions (DMFs) and Event Table
-- ============================================================================
-- DMFs must be dropped before the tables they're associated with

-- Unset database-level event table configuration
ALTER DATABASE IF EXISTS SNOWFLAKE_EXAMPLE 
  UNSET EVENT_TABLE;

-- Drop custom DMF definitions (functions)
DROP FUNCTION IF EXISTS RAW_INGESTION.duplicate_events(TABLE(VARCHAR, TIMESTAMP_NTZ));
DROP FUNCTION IF EXISTS RAW_INGESTION.invalid_signal_strength(TABLE(NUMBER));
DROP FUNCTION IF EXISTS RAW_INGESTION.future_timestamps(TABLE(TIMESTAMP_NTZ));
DROP FUNCTION IF EXISTS RAW_INGESTION.invalid_direction(TABLE(VARCHAR));
DROP FUNCTION IF EXISTS RAW_INGESTION.abnormal_user_activity(TABLE(VARCHAR, TIMESTAMP_NTZ));
DROP FUNCTION IF EXISTS RAW_INGESTION.orphaned_fact_records(TABLE(NUMBER, NUMBER), TABLE(NUMBER));

-- Drop event table (must come after unsetting database parameter)
DROP TABLE IF EXISTS RAW_INGESTION.DATA_QUALITY_EVENTS;

-- ============================================================================
-- STEP 3: Drop Streams
-- ============================================================================
-- Streams should be dropped before their source tables

DROP STREAM IF EXISTS RAW_INGESTION.sfe_badge_events_stream;
DROP STREAM IF EXISTS STAGING_LAYER.stg_badge_events_stream;

-- ============================================================================
-- STEP 4: Drop Stored Procedures
-- ============================================================================

DROP PROCEDURE IF EXISTS STAGING_LAYER.sfe_process_badge_events();
DROP PROCEDURE IF EXISTS DEMO_REPO.SFE_DEPLOY_PIPELINE();
DROP PROCEDURE IF EXISTS DEMO_REPO.SFE_VALIDATE_PIPELINE();
DROP PROCEDURE IF EXISTS DEMO_REPO.SFE_RESET_PIPELINE();

-- ============================================================================
-- STEP 5: Drop Monitoring Views
-- ============================================================================
-- Drop views before tables to avoid dependency issues

DROP VIEW IF EXISTS RAW_INGESTION.V_CHANNEL_STATUS;
DROP VIEW IF EXISTS RAW_INGESTION.V_INGESTION_METRICS;
DROP VIEW IF EXISTS RAW_INGESTION.V_END_TO_END_LATENCY;
DROP VIEW IF EXISTS RAW_INGESTION.V_DATA_FRESHNESS;
DROP VIEW IF EXISTS RAW_INGESTION.V_PARTITION_EFFICIENCY;
DROP VIEW IF EXISTS RAW_INGESTION.V_STREAMING_COSTS;
DROP VIEW IF EXISTS RAW_INGESTION.V_TASK_EXECUTION_HISTORY;

-- Data Quality Monitoring Views
DROP VIEW IF EXISTS RAW_INGESTION.V_DATA_QUALITY_DASHBOARD;
DROP VIEW IF EXISTS RAW_INGESTION.V_DATA_QUALITY_VIOLATIONS;
DROP VIEW IF EXISTS RAW_INGESTION.V_TABLE_QUALITY_SCORES;
DROP VIEW IF EXISTS RAW_INGESTION.V_VIOLATION_TRENDS;

-- ============================================================================
-- STEP 6: Drop Snowpipe
-- ============================================================================
-- Pipe must be dropped before its target table

DROP PIPE IF EXISTS RAW_INGESTION.sfe_badge_events_pipe;

-- ============================================================================
-- STEP 7: Drop Tables
-- ============================================================================
-- Drop fact tables first, then dimensions, then staging, then raw

-- Analytics Layer (Fact and Dimensions)
DROP TABLE IF EXISTS ANALYTICS_LAYER.FCT_ACCESS_EVENTS;
DROP TABLE IF EXISTS ANALYTICS_LAYER.DIM_USERS;
DROP TABLE IF EXISTS ANALYTICS_LAYER.DIM_ZONES;
DROP TABLE IF EXISTS ANALYTICS_LAYER.DIM_READERS;

-- Staging Layer
DROP TABLE IF EXISTS STAGING_LAYER.STG_BADGE_EVENTS;

-- Raw Layer
DROP TABLE IF EXISTS RAW_INGESTION.RAW_BADGE_EVENTS;

-- Data Quality Layer (supporting tables if any)
DROP TABLE IF EXISTS RAW_INGESTION.DQ_VIOLATION_LOG;

-- ============================================================================
-- STEP 8: Drop Schemas
-- ============================================================================
-- Schemas can only be dropped when empty

DROP SCHEMA IF EXISTS ANALYTICS_LAYER;
DROP SCHEMA IF EXISTS STAGING_LAYER;
DROP SCHEMA IF EXISTS RAW_INGESTION;

-- ============================================================================
-- STEP 9: Drop Git Repository, Secrets, and DEMO_REPO Schema
-- ============================================================================
-- These require ACCOUNTADMIN privileges

USE ROLE ACCOUNTADMIN;

-- Drop secrets
DROP SECRET IF EXISTS DEMO_REPO.SFE_SS_ACCOUNT;
DROP SECRET IF EXISTS DEMO_REPO.SFE_SS_USER;
DROP SECRET IF EXISTS DEMO_REPO.SFE_SS_JWT_KEY;

-- Drop Git repository
DROP GIT REPOSITORY IF EXISTS DEMO_REPO.sfe_simple_stream_repo;

-- Drop DEMO_REPO schema
DROP SCHEMA IF EXISTS DEMO_REPO;

-- ============================================================================
-- STEP 10: Drop Warehouse and API Integration
-- ============================================================================
-- Account-level objects (ACCOUNTADMIN required)

DROP WAREHOUSE IF EXISTS SFE_SIMPLE_STREAM_WH;
DROP API INTEGRATION IF EXISTS SFE_GIT_API_INTEGRATION;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify no SFE_ objects remain at account level
SHOW API INTEGRATIONS LIKE 'SFE_%';
SHOW WAREHOUSES LIKE 'SFE_%';

-- Verify SNOWFLAKE_EXAMPLE database still exists but schemas are gone
USE DATABASE SNOWFLAKE_EXAMPLE;
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Expected: Only INFORMATION_SCHEMA and PUBLIC should remain
-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================
-- ✅ All demo objects removed
-- ✅ SNOWFLAKE_EXAMPLE database preserved (as per cleanup rule)
-- ✅ Ready for fresh deployment
