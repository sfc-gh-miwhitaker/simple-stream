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
-- DEPLOYMENT COMPLETE - API Integration Guide
-- ============================================================================

SELECT '
================================================================================
SNOWPIPE STREAMING API - INTEGRATION GUIDE
================================================================================

ENDPOINT:
https://' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE/insertRows

CREDENTIALS:
- Account: ' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '
- User: sfe_ingest_user
- Role: sfe_ingest_role
- Private Key: rsa_key.p8 (provided separately)

AUTHENTICATION:
Generate JWT token using key pair authentication.
See: https://docs.snowflake.com/en/developer-guide/sql-api/authenticating

--------------------------------------------------------------------------------
CURL EXAMPLE
--------------------------------------------------------------------------------

curl -X POST \\
  -H "Authorization: Bearer <JWT_TOKEN>" \\
  -H "Content-Type: application/json" \\
  -d ''{"badge_id":"BADGE-001","user_id":"USR-001","zone_id":"ZONE-LOBBY-1","reader_id":"RDR-101","event_timestamp":"2024-11-04T10:30:00"}'' \\
  https://' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE/insertRows

Replace <JWT_TOKEN> with your generated token.

--------------------------------------------------------------------------------
JSON FIELD REQUIREMENTS
--------------------------------------------------------------------------------

REQUIRED:
  badge_id           STRING      Unique badge identifier
  user_id            STRING      User identifier
  zone_id            STRING      Zone/location identifier
  reader_id          STRING      RFID reader identifier
  event_timestamp    STRING      ISO 8601 format (YYYY-MM-DDTHH:MM:SS)

OPTIONAL:
  signal_strength    NUMBER      RSSI in dBm (e.g., -65.5)
  direction          STRING      "ENTRY" or "EXIT"

--------------------------------------------------------------------------------
DOCUMENTATION
--------------------------------------------------------------------------------

Snowpipe Streaming: https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming
Key Pair Auth:      https://docs.snowflake.com/en/developer-guide/sql-api/authenticating

================================================================================
' AS api_handoff;