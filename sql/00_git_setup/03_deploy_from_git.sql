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
-- AUTOMATED DEPLOYMENT: Execute all scripts from Git repository
-- ============================================================================
--
-- PREREQUISITE: sql/00_git_setup/01_git_repository_setup.sql must be run first
--               to create the Git repository object at:
--               @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
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
-- VERIFICATION: Deployment Validation Report
-- ============================================================================

SELECT
    'Schemas' AS object_type,
    COUNT(*) AS actual_count,
    4 AS expected_count,
    IFF(COUNT(*) = 4, 'PASS', 'FAIL') AS status
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE CATALOG_NAME = 'SNOWFLAKE_EXAMPLE'
  AND SCHEMA_NAME IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER', 'DEMO_REPO')

UNION ALL

SELECT
    'Tables (RAW_INGESTION)' AS object_type,
    COUNT(*) AS actual_count,
    1 AS expected_count,
    IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'RAW_INGESTION'
  AND TABLE_TYPE = 'BASE TABLE'

UNION ALL

SELECT
    'Tables (STAGING_LAYER)' AS object_type,
    COUNT(*) AS actual_count,
    1 AS expected_count,
    IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'STAGING_LAYER'
  AND TABLE_TYPE = 'BASE TABLE'

UNION ALL

SELECT
    'Tables (ANALYTICS_LAYER)' AS object_type,
    COUNT(*) AS actual_count,
    4 AS expected_count,
    IFF(COUNT(*) >= 4, 'PASS', 'FAIL') AS status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ANALYTICS_LAYER'
  AND TABLE_TYPE = 'BASE TABLE'

UNION ALL

SELECT
    'Views (RAW_INGESTION)' AS object_type,
    COUNT(*) AS actual_count,
    7 AS expected_count,
    IFF(COUNT(*) >= 7, 'PASS', 'FAIL') AS status
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'RAW_INGESTION'

UNION ALL

SELECT
    'Seed Data (DIM_USERS)' AS object_type,
    COUNT(*) AS actual_count,
    5 AS expected_count,
    IFF(COUNT(*) = 5, 'PASS', 'FAIL') AS status
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS
WHERE is_current = TRUE

UNION ALL

SELECT
    'Seed Data (DIM_ZONES)' AS object_type,
    COUNT(*) AS actual_count,
    5 AS expected_count,
    IFF(COUNT(*) = 5, 'PASS', 'FAIL') AS status
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_ZONES

ORDER BY object_type;

-- Check tasks separately (INFORMATION_SCHEMA.TASKS doesn't exist)
SHOW TASKS IN SCHEMA RAW_INGESTION;

SELECT
    'Tasks (RAW_INGESTION)' AS object_type,
    COUNT(*) AS actual_count,
    2 AS expected_count,
    IFF(COUNT(*) = 2, 'PASS', 'FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IN ('SFE_RAW_TO_STAGING_TASK', 'SFE_STAGING_TO_ANALYTICS_TASK');

-- ============================================================================
-- EXPECTED VALIDATION RESULTS
-- ============================================================================
-- 
-- All rows should show status = 'PASS'
-- 
-- If any row shows 'FAIL':
--   - Check error messages from the EXECUTE IMMEDIATE statements above
--   - Verify SYSADMIN has necessary privileges
--   - Run sql/99_cleanup/teardown_all.sql and retry deployment
-- 
-- Next step: Run notebook notebooks/RFID_Simulator.ipynb to send simulated data
-- ============================================================================
