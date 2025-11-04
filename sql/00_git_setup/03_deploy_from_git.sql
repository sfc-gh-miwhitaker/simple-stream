/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Automated Deployment from Git
 * 
 * WARNING:  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Automated deployment that reads SQL scripts from the Git repository and
 *   executes them in the correct order to build the complete pipeline.
 * 
 * DEPLOYS:
 *   1. Core infrastructure (database, schemas, raw table, pipe, stream)
 *   2. Analytics layer (staging, dimensions, facts)
 *   3. Task automation (CDC tasks with auto-resume)
 *   4. Monitoring views
 * 
 * DEPENDENCIES:
 *   - Git workspace created in Snowsight (contains the repository)
 *   - API integration exists (SFE_GIT_API_INTEGRATION)
 *   - Optional: secrets configured (only needed if running simulator)
 * 
 * WARNING:  IMPORTANT: This script must be run from within your Git workspace!
 *     The workspace knows where the Git repository is located.
 * 
 * USAGE:
 *   1. Open your Git workspace in Snowsight (Projects → Workspaces)
 *   2. Navigate to: sql/00_git_setup/03_deploy_from_git.sql
 *   3. Click "Run All" (▶▶ button)
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 40 seconds
 ******************************************************************************/

USE ROLE SYSADMIN;

-- ============================================================================
-- STEP 1: Discover Git Repository Location
-- ============================================================================
--
-- The workspace UI creates the Git repository object somewhere in your account.
-- Let's find it dynamically so this script works regardless of where it was created.
--

SHOW GIT REPOSITORIES IN ACCOUNT;

-- Capture the Git repo path from the SHOW command above
SET git_repo_path = (
    SELECT '@' || "database_name" || '.' || "schema_name" || '.' || "name"
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "origin" LIKE '%sfe-simple-stream%'
    LIMIT 1
);

SELECT $git_repo_path AS discovered_git_repository;

-- ============================================================================
-- STEP 2: Execute All Setup Scripts from Git Repository
-- ============================================================================

-- Step 1: Core infrastructure (DB, schemas, raw table, pipe, stream)
EXECUTE IMMEDIATE 'EXECUTE IMMEDIATE FROM ' || $git_repo_path || '/branches/main/sql/01_setup/01_core_setup.sql';

-- Step 2: Analytics layer (staging, dimensions, facts)
EXECUTE IMMEDIATE 'EXECUTE IMMEDIATE FROM ' || $git_repo_path || '/branches/main/sql/01_setup/02_analytics_layer.sql';

-- Step 3: Task automation (CDC tasks with auto-resume)
EXECUTE IMMEDIATE 'EXECUTE IMMEDIATE FROM ' || $git_repo_path || '/branches/main/sql/01_setup/03_enable_tasks.sql';

-- Step 4: Monitoring views
EXECUTE IMMEDIATE 'EXECUTE IMMEDIATE FROM ' || $git_repo_path || '/branches/main/sql/03_monitoring/monitoring_views.sql';

-- ============================================================================
-- VERIFICATION: Confirm deployment succeeded
-- ============================================================================

-- Check schemas created
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Check core infrastructure (raw layer) - Using SHOW commands for reliability
SHOW TABLES IN SCHEMA RAW_INGESTION;

SHOW PIPES IN SCHEMA RAW_INGESTION;

SHOW STREAMS IN SCHEMA RAW_INGESTION;

-- Check analytics layer tables
SHOW TABLES IN SCHEMA ANALYTICS_LAYER;

-- Check staging layer tables
SHOW TABLES IN SCHEMA STAGING_LAYER;

-- Check monitoring views created (in RAW_INGESTION schema)
SHOW VIEWS IN SCHEMA RAW_INGESTION;

-- Check seed data loaded
SELECT COUNT(*) AS user_count FROM ANALYTICS_LAYER.DIM_USERS WHERE is_current = TRUE;

SELECT COUNT(*) AS zone_count FROM ANALYTICS_LAYER.DIM_ZONES;

-- Check tasks created and running (both tasks now in RAW_INGESTION schema)
SHOW TASKS IN SCHEMA RAW_INGESTION;

-- ============================================================================
-- EXPECTED OUTPUT VERIFICATION
-- ============================================================================
-- 
-- SHOW SCHEMAS: Should display RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER, DEMO_REPO
-- 
-- SHOW TABLES IN SCHEMA RAW_INGESTION: Should show RAW_BADGE_EVENTS (1 table)
-- 
-- SHOW PIPES IN SCHEMA RAW_INGESTION: Should show sfe_badge_events_pipe (1 pipe)
-- 
-- SHOW STREAMS IN SCHEMA RAW_INGESTION: Should show sfe_badge_events_stream (1 stream)
-- 
-- SHOW TABLES IN SCHEMA ANALYTICS_LAYER: Should show DIM_USERS, DIM_ZONES, DIM_READERS, FCT_ACCESS_EVENTS (4 tables)
-- 
-- SHOW TABLES IN SCHEMA STAGING_LAYER: Should show STG_BADGE_EVENTS (1 table)
-- 
-- SHOW VIEWS IN SCHEMA RAW_INGESTION: Should show V_CHANNEL_STATUS, V_INGESTION_METRICS, etc. (7+ views)
-- 
-- SELECT COUNT... DIM_USERS: Should return 5 (seed data)
-- 
-- SELECT COUNT... DIM_ZONES: Should return 5 (seed data)
-- 
-- SHOW TASKS IN SCHEMA RAW_INGESTION: Should show 2 tasks:
--   - sfe_raw_to_staging_task (state = "started")
--   - sfe_staging_to_analytics_task (state = "started")
-- 
-- NOTE: Tasks may show state = "suspended" - this is normal, they activate when stream has data
-- 
-- If deployment fails:
--   - Check error message to identify which script failed
--   - Verify Git repository is accessible: SHOW GIT REPOSITORIES;
--   - Ensure SYSADMIN has necessary privileges
--   - Run sql/99_cleanup/teardown_all.sql and retry deployment
-- 
-- Next step: Run notebook notebooks/RFID_Simulator.ipynb to send simulated data
-- ============================================================================
