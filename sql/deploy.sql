/*******************************************************************************
 * Simple Streaming Pipeline - Complete Deployment
 * 
 * PURPOSE: Deploy complete Snowpipe Streaming pipeline from Git in one command
 * DEPLOYS: Git integration + infrastructure + analytics + tasks + monitoring
 * TIME: 45 seconds
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Git Integration & Database
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Example projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO;

USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION SFE_GIT_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream';

-- ============================================================================
-- STEP 2: Deploy Pipeline from Git
-- ============================================================================

EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/01_core.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/02_analytics.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/03_tasks.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/04_monitoring.sql;

-- ============================================================================
-- VALIDATION
-- ============================================================================

USE SCHEMA RAW_INGESTION;

SELECT 'Schemas' AS object, COUNT(*) AS count, IFF(COUNT(*)=4, '✓', '✗') AS ok
FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.SCHEMATA
WHERE CATALOG_NAME = 'SNOWFLAKE_EXAMPLE' 
  AND SCHEMA_NAME IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER', 'DEMO_REPO')
UNION ALL
SELECT 'Tables', COUNT(*), IFF(COUNT(*)>=5, '✓', '✗')
FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE' 
  AND TABLE_SCHEMA IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER')
  AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'Views', COUNT(*), IFF(COUNT(*)>=7, '✓', '✗')
FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE' AND TABLE_SCHEMA = 'RAW_INGESTION'
ORDER BY object;

SHOW TASKS IN SCHEMA RAW_INGESTION;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
-- 
-- Next Steps:
--   1. Run @sql/05_validate.sql to verify deployment
--   2. Run @sql/06_configure_auth.sql to set up credentials
--   3. Run @sql/07_api_handoff.sql to generate provider documentation
-- 
-- ============================================================================