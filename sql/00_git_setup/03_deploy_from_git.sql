/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Automated Deployment from Git
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
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
 * ⚠️  IMPORTANT: This script must be run from within your Git workspace!
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
-- Find the Git Repository
-- ============================================================================
--
-- The workspace created the Git repository in a schema. Let's find it:

SHOW GIT REPOSITORIES LIKE '%sfe_simple_stream%';

-- If you see your repository listed, note its database and schema.
-- The repository stage path will be: @DATABASE.SCHEMA.REPOSITORY_NAME
--
-- Common locations:
--   - Workspace default: @<your_db>.<your_schema>.sfe_simple_stream_repo
--   - Manual setup: @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
--

-- ============================================================================
-- AUTOMATED DEPLOYMENT: Execute scripts from Git repository
-- ============================================================================
--
-- ⚠️  EDIT THE @... PATHS BELOW TO MATCH YOUR GIT REPOSITORY LOCATION
--
-- Replace "SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo" with the
-- actual database.schema.repository_name from the SHOW command above.
--
-- If running from the Git workspace, Snowsight should auto-complete these paths!
--

-- Step 1: Core infrastructure (DB, schemas, raw table, pipe, stream)
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/01_setup/01_core_setup.sql;

-- Step 2: Analytics layer (staging, dimensions, facts)
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/01_setup/02_analytics_layer.sql;

-- Step 3: Task automation (CDC tasks with auto-resume)
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/01_setup/03_enable_tasks.sql;

-- Step 4: Monitoring views
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/03_monitoring/monitoring_views.sql;

-- ============================================================================
-- VERIFICATION: Confirm deployment succeeded
-- ============================================================================

-- Check schemas created
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Check core infrastructure (raw layer)
SELECT 
    'RAW_INGESTION' AS layer,
    COUNT(DISTINCT CASE WHEN object_type = 'TABLE' THEN object_name END) AS tables,
    COUNT(DISTINCT CASE WHEN object_type = 'PIPE' THEN object_name END) AS pipes,
    COUNT(DISTINCT CASE WHEN object_type = 'STREAM' THEN object_name END) AS streams
FROM (
    SELECT table_name AS object_name, 'TABLE' AS object_type FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'RAW_INGESTION'
    UNION ALL
    SELECT pipe_name, 'PIPE' FROM INFORMATION_SCHEMA.PIPES WHERE pipe_schema = 'RAW_INGESTION'
    UNION ALL
    SELECT stream_name, 'STREAM' FROM INFORMATION_SCHEMA.STREAMS WHERE table_schema = 'RAW_INGESTION'
);

-- Check analytics layer
SELECT 
    'ANALYTICS_LAYER' AS layer,
    COUNT(DISTINCT CASE WHEN table_name LIKE 'DIM_%' THEN table_name END) AS dimensions,
    COUNT(DISTINCT CASE WHEN table_name LIKE 'FCT_%' THEN table_name END) AS facts,
    COUNT(DISTINCT CASE WHEN table_name LIKE 'V_%' THEN table_name END) AS views
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('STAGING_LAYER', 'ANALYTICS_LAYER');

-- Check seed data loaded
SELECT 
    'Dimension Seed Data' AS check_type,
    (SELECT COUNT(*) FROM ANALYTICS_LAYER.DIM_USERS WHERE is_current = TRUE) AS dim_users,
    (SELECT COUNT(*) FROM ANALYTICS_LAYER.DIM_ZONES) AS dim_zones;

-- Check tasks created and running
SELECT 
    name AS task_name,
    state,
    schedule,
    CASE 
        WHEN state = 'started' THEN '✅ Running'
        ELSE '❌ Suspended'
    END AS status
FROM INFORMATION_SCHEMA.TASKS
WHERE task_schema IN ('RAW_INGESTION', 'STAGING_LAYER')
ORDER BY name;

-- Check monitoring views created
SELECT 
    table_name,
    table_type
FROM INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'ANALYTICS_LAYER'
  AND table_name LIKE 'V_%MONITORING%'
ORDER BY table_name;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- ✅ DEPLOYMENT_COMPLETE returned
-- ✅ Schemas: RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER created
-- ✅ RAW layer: 1 table (RAW_BADGE_EVENTS), 1 pipe, 1 stream
-- ✅ ANALYTICS layer: 3 dimensions, 1 fact table, 1 staging table
-- ✅ Seed data: 5 users, 5 zones loaded
-- ✅ Tasks: 2 tasks created and in "started" state
-- ✅ Monitoring views: Created and accessible
-- 
-- If tasks show "suspended":
--   - This is OK - they'll resume when data arrives
--   - Or manually resume: ALTER TASK <task_name> RESUME;
-- 
-- If deployment fails:
--   - Check error message for specific script that failed
--   - Verify Git repository is accessible
--   - Ensure SYSADMIN has necessary privileges
--   - Run sql/99_cleanup/teardown_all.sql and retry
-- 
-- Next step: Run notebook notebooks/RFID_Simulator.ipynb to send data
-- ============================================================================
