/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Complete Teardown
 * 
 * ⚠️  DESTRUCTIVE OPERATION - ALL DATA WILL BE PERMANENTLY DELETED
 * 
 * PURPOSE:
 *   Remove all objects created by the sfe-simple-stream demo including:
 *   - Tasks, Streams, Pipes (pipeline objects)
 *   - Stored Procedures
 *   - Tables (facts and dimensions)
 *   - Schemas
 *   - Git Repository
 *   - Secrets
 *   - Warehouse
 *   - API Integration
 * 
 * IMPORTANT: Database (SNOWFLAKE_EXAMPLE) is preserved per cleanup policy
 * 
 * USAGE:
 *   Review this script carefully before executing
 *   Execute in Snowsight Workspaces (Projects → Workspaces → + SQL File)
 * 
 * ESTIMATED TIME: 30 seconds
 ******************************************************************************/

-- Set execution context
USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * STEP 1: Stop All Tasks
 * 
 * Suspend tasks to prevent execution during teardown
 ******************************************************************************/

-- Suspend child task first, then parent (reverse dependency order)
ALTER TASK IF EXISTS STAGING_LAYER.sfe_staging_to_analytics_task SUSPEND;
ALTER TASK IF EXISTS RAW_INGESTION.sfe_raw_to_staging_task SUSPEND;

-- Wait for any running task executions to complete
CALL SYSTEM$WAIT(5);

/*******************************************************************************
 * STEP 2: Drop Pipeline Objects
 * 
 * Drop in dependency order: Tasks → Streams → Pipes → Procedures
 ******************************************************************************/

-- Drop tasks
DROP TASK IF EXISTS STAGING_LAYER.sfe_staging_to_analytics_task;
DROP TASK IF EXISTS RAW_INGESTION.sfe_raw_to_staging_task;

-- Drop streams
DROP STREAM IF EXISTS RAW_INGESTION.sfe_badge_events_stream;

-- Note: Staging stream is created automatically by the task, may not exist
DROP STREAM IF EXISTS STAGING_LAYER.stg_badge_events_stream;

-- Drop pipes
DROP PIPE IF EXISTS RAW_INGESTION.sfe_badge_events_pipe;

-- Drop stored procedures
DROP PROCEDURE IF EXISTS STAGING_LAYER.sfe_process_badge_events();
DROP PROCEDURE IF EXISTS DEMO_REPO.SFE_DEPLOY_PIPELINE();
DROP PROCEDURE IF EXISTS DEMO_REPO.SFE_VALIDATE_PIPELINE();
DROP PROCEDURE IF EXISTS DEMO_REPO.SFE_RESET_PIPELINE();

/*******************************************************************************
 * STEP 3: Drop Monitoring Views (if created)
 * 
 * These may not exist if monitoring scripts weren't run
 ******************************************************************************/

DROP VIEW IF EXISTS RAW_INGESTION.V_CHANNEL_STATUS;
DROP VIEW IF EXISTS RAW_INGESTION.V_INGESTION_METRICS;
DROP VIEW IF EXISTS RAW_INGESTION.V_END_TO_END_LATENCY;
DROP VIEW IF EXISTS RAW_INGESTION.V_DATA_FRESHNESS;
DROP VIEW IF EXISTS RAW_INGESTION.V_PARTITION_EFFICIENCY;
DROP VIEW IF EXISTS RAW_INGESTION.V_STREAMING_COSTS;
DROP VIEW IF EXISTS RAW_INGESTION.V_TASK_EXECUTION_HISTORY;
DROP VIEW IF EXISTS RAW_INGESTION.V_DATA_QUALITY_SUMMARY;

/*******************************************************************************
 * STEP 4: Drop Tables
 * 
 * Drop in dependency order: Facts → Dimensions → Staging → Raw
 ******************************************************************************/

-- Drop fact table first (has foreign key constraints to dimensions)
DROP TABLE IF EXISTS ANALYTICS_LAYER.FCT_ACCESS_EVENTS;

-- Drop dimension tables
DROP TABLE IF EXISTS ANALYTICS_LAYER.DIM_USERS;
DROP TABLE IF EXISTS ANALYTICS_LAYER.DIM_ZONES;
DROP TABLE IF EXISTS ANALYTICS_LAYER.DIM_READERS;

-- Drop staging table
DROP TABLE IF EXISTS STAGING_LAYER.STG_BADGE_EVENTS;

-- Drop raw table
DROP TABLE IF EXISTS RAW_INGESTION.RAW_BADGE_EVENTS;

/*******************************************************************************
 * STEP 5: Drop Schemas
 * 
 * Drop data schemas (not DEMO_REPO - contains Git repo)
 ******************************************************************************/

DROP SCHEMA IF EXISTS ANALYTICS_LAYER;
DROP SCHEMA IF EXISTS STAGING_LAYER;
DROP SCHEMA IF EXISTS RAW_INGESTION;

/*******************************************************************************
 * STEP 6: Drop Git Repository and Secrets
 * 
 * Requires ACCOUNTADMIN for Git repository deletion
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

-- Drop secrets
DROP SECRET IF EXISTS DEMO_REPO.SFE_SS_ACCOUNT;
DROP SECRET IF EXISTS DEMO_REPO.SFE_SS_USER;
DROP SECRET IF EXISTS DEMO_REPO.SFE_SS_JWT_KEY;

-- Drop Git repository
DROP GIT REPOSITORY IF EXISTS DEMO_REPO.sfe_simple_stream_repo;

-- Drop DEMO_REPO schema
DROP SCHEMA IF EXISTS DEMO_REPO;

/*******************************************************************************
 * STEP 7: Drop Warehouse
 * 
 * This removes the dedicated demo warehouse
 ******************************************************************************/

DROP WAREHOUSE IF EXISTS SFE_SIMPLE_STREAM_WH;

/*******************************************************************************
 * STEP 8: Drop API Integration
 * 
 * Remove the Git API integration (requires ACCOUNTADMIN)
 ******************************************************************************/

DROP API INTEGRATION IF EXISTS SFE_GIT_API_INTEGRATION;

/*******************************************************************************
 * STEP 9: Preserve Database (Per Cleanup Policy)
 * 
 * The SNOWFLAKE_EXAMPLE database is intentionally preserved for audit
 * and potential reuse. To drop it, uncomment the following:
 * 
 * DROP DATABASE IF EXISTS SNOWFLAKE_EXAMPLE;
 ******************************************************************************/

/*******************************************************************************
 * VERIFICATION
 * 
 * Run these queries to verify complete cleanup:
 ******************************************************************************/

-- Verify all SFE_ objects are removed
SHOW API INTEGRATIONS LIKE 'SFE_%';
SHOW WAREHOUSES LIKE 'SFE_%';
SHOW GIT REPOSITORIES LIKE 'sfe_%';
SHOW SECRETS LIKE 'SFE_%' IN DATABASE SNOWFLAKE_EXAMPLE;
SHOW PIPES LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;
SHOW STREAMS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;
SHOW TASKS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;
SHOW PROCEDURES LIKE 'SFE_%' IN DATABASE SNOWFLAKE_EXAMPLE;

-- Verify schemas are removed
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;
-- Expected: Only DEMO_REPO remains (or none if that was dropped too)

-- If you see any SFE_ objects in the above results, they were not properly
-- cleaned up. Review the error messages and re-run specific DROP statements.

/*******************************************************************************
 * SUCCESS CRITERIA
 * 
 * ✅ All SHOW commands return 0 results for SFE_ prefixed objects
 * ✅ Only SNOWFLAKE_EXAMPLE database remains (empty)
 * ✅ No warehouse named SFE_SIMPLE_STREAM_WH
 * ✅ No API integration named SFE_GIT_API_INTEGRATION
 * 
 * NEXT STEPS:
 * - Review SNOWFLAKE_EXAMPLE database for any remaining objects
 * - Optionally drop SNOWFLAKE_EXAMPLE database
 * - Project can be re-deployed by running sql/00_git_setup/ scripts again
 ******************************************************************************/
