/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Convenience Stored Procedures
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create optional helper procedures for common operations:
 *   - One-command deployment from Git
 *   - Quick pipeline health check
 *   - Clean reset for re-deployment
 * 
 * OBJECTS CREATED:
 *   - Procedure: SFE_DEPLOY_PIPELINE() - Deploy full pipeline from Git
 *   - Procedure: SFE_VALIDATE_PIPELINE() - Return health check JSON
 *   - Procedure: SFE_RESET_PIPELINE() - Clean teardown
 * 
 * DEPENDENCIES:
 *   - sql/00_git_setup/01_git_repository_setup.sql (Git repo must exist)
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 *   Then call procedures: CALL SFE_DEPLOY_PIPELINE();
 * 
 * NOTE: These are convenience wrappers. You can also run scripts directly.
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 5 seconds
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA DEMO_REPO;

-- ============================================================================
-- PROCEDURE 1: Deploy Pipeline from Git
-- ============================================================================
-- 
-- Wrapper around 03_deploy_from_git.sql for one-command deployment
-- 
-- Usage:
--   CALL SFE_DEPLOY_PIPELINE();
-- 
-- Returns: 'DEPLOYED' on success
-- 

CREATE OR REPLACE PROCEDURE SFE_DEPLOY_PIPELINE()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - One-command deployment from Git repository'
EXECUTE AS CALLER
AS
$$
DECLARE
    script STRING;
BEGIN
    -- Read deployment script from Git
    SELECT file_content INTO :script
    FROM TABLE(READ_GIT_FILE(
        repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
        file_path => 'sql/00_git_setup/03_deploy_from_git.sql',
        ref => 'main'
    ));

    -- Execute deployment
    EXECUTE IMMEDIATE :script;
    
    RETURN 'DEPLOYED';
END;
$$;

-- ============================================================================
-- PROCEDURE 2: Validate Pipeline Health
-- ============================================================================
-- 
-- Quick health check that returns JSON object with pipeline status
-- 
-- Usage:
--   CALL SFE_VALIDATE_PIPELINE();
-- 
-- Returns JSON:
--   {
--     "raw_rows": 1000,
--     "staging_rows": 1000,
--     "fact_rows": 1000,
--     "stream_has_data": "false",
--     "tasks_running": 2
--   }
-- 

CREATE OR REPLACE PROCEDURE SFE_VALIDATE_PIPELINE()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - Pipeline health check (returns JSON summary)'
EXECUTE AS CALLER
AS
$$
DECLARE
    report VARIANT;
BEGIN
    report := OBJECT_CONSTRUCT(
        'timestamp', CURRENT_TIMESTAMP(),
        'raw_rows', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS),
        'staging_rows', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS),
        'fact_rows', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS),
        'stream_has_data', SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_badge_events_stream'),
        'tasks_running', (
            SELECT COUNT(*)
            FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.TASKS
            WHERE TASK_SCHEMA IN ('RAW_INGESTION', 'STAGING_LAYER')
              AND STATE = 'started'
        ),
        'dim_users', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS WHERE is_current = TRUE),
        'dim_zones', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_ZONES)
    );

    RETURN report;
END;
$$;

-- ============================================================================
-- PROCEDURE 3: Reset Pipeline (Clean Teardown)
-- ============================================================================
-- 
-- Wrapper around teardown_all.sql for clean removal
-- 
-- Usage:
--   CALL SFE_RESET_PIPELINE();
-- 
-- Returns: 'RESET' on success
-- 
-- WARNING: This drops all tables and data! Use for testing/redeploy only.
-- 

CREATE OR REPLACE PROCEDURE SFE_RESET_PIPELINE()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - Clean teardown for re-deployment (DROPS DATA)'
EXECUTE AS CALLER
AS
$$
DECLARE
    script STRING;
BEGIN
    -- Read teardown script from Git
    SELECT file_content INTO :script
    FROM TABLE(READ_GIT_FILE(
        repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
        file_path => 'sql/99_cleanup/teardown_all.sql',
        ref => 'main'
    ));

    -- Execute teardown
    EXECUTE IMMEDIATE :script;
    
    RETURN 'RESET';
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON PROCEDURE SFE_DEPLOY_PIPELINE() TO ROLE SYSADMIN;
GRANT USAGE ON PROCEDURE SFE_VALIDATE_PIPELINE() TO ROLE SYSADMIN;
GRANT USAGE ON PROCEDURE SFE_RESET_PIPELINE() TO ROLE SYSADMIN;

-- ============================================================================
-- VERIFICATION: Test procedures exist and are callable
-- ============================================================================

-- Show all SFE procedures
SHOW PROCEDURES LIKE 'SFE_%' IN SCHEMA DEMO_REPO;

-- Test validate procedure (safe to call anytime)
CALL SFE_VALIDATE_PIPELINE();

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- ✅ Procedures created: SFE_DEPLOY_PIPELINE, SFE_VALIDATE_PIPELINE, SFE_RESET_PIPELINE
-- ✅ Permissions granted to SYSADMIN role
-- ✅ Validation test returns JSON object (may show 0 rows if pipeline not deployed)
-- 
-- USAGE EXAMPLES:
-- 
-- Deploy the pipeline:
--   CALL SFE_DEPLOY_PIPELINE();
-- 
-- Check pipeline health:
--   CALL SFE_VALIDATE_PIPELINE();
-- 
-- Reset for re-deployment:
--   CALL SFE_RESET_PIPELINE();
--   CALL SFE_DEPLOY_PIPELINE();  -- Re-deploy fresh
-- 
-- NOTE: These are convenience wrappers. You can also run scripts directly:
--   - @sql/00_git_setup/03_deploy_from_git.sql
--   - @sql/02_validation/validate_pipeline.sql
--   - @sql/99_cleanup/teardown_all.sql
-- 
-- ============================================================================
