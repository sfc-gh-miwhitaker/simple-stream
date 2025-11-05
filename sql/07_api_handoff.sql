/*******************************************************************************
 * DEMO PROJECT: simple-stream
 * Script: API Provider Handoff Document Generator
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 ******************************************************************************/

-- ============================================================================
-- PURPOSE: Generate complete API configuration and credentials for data provider
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

SELECT 
'================================================================================
SNOWPIPE STREAMING API - DATA PROVIDER HANDOFF
================================================================================

ENDPOINT URL:
  https://' || LOWER(REPLACE(CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME(), '_', '-')) || '.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_badge_events_pipe/insertRows

CREDENTIALS:
  Account:      ' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '
  Username:     sfe_ingest_user
  Role:         sfe_ingest_role
  Private Key:  rsa_key.p8 (provided separately via secure channel)

AUTH METHOD:
  Key Pair JWT (RSA 2048-bit)

JSON SCHEMA (Required Fields):
  badge_id, user_id, zone_id, reader_id, event_timestamp (ISO 8601)

--------------------------------------------------------------------------------
QUICKSTART DEMO
--------------------------------------------------------------------------------

Working scripts with JWT token management and sample data:

  https://github.com/USERNAME/simple-stream/tree/main/examples

  Unix/Mac:  ./send_events.sh
  Windows:   send_events.bat

Includes:
  - Production-ready SnowpipeAuthManager class
  - Auto-refreshing JWT tokens (59-min lifespan, 5-min pre-refresh)
  - Complete error handling and troubleshooting
  - Sample events demonstrating API usage

Edit script and set ACCOUNT_ID=' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '

--------------------------------------------------------------------------------
DOCUMENTATION
--------------------------------------------------------------------------------

Complete Guide:
  https://github.com/USERNAME/simple-stream/blob/main/examples/README.md

Snowflake Docs:
  https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming
  https://docs.snowflake.com/en/developer-guide/sql-api/authenticating

--------------------------------------------------------------------------------
MONITORING VIEWS
--------------------------------------------------------------------------------

SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS;
SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_END_TO_END_LATENCY;
SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_STREAMING_COSTS;

(Contact Snowflake admin to grant SELECT privileges if needed)

================================================================================
' AS api_handoff_document;

-- ============================================================================
-- VERIFY CREDENTIALS EXIST
-- ============================================================================

USE ROLE ACCOUNTADMIN;

SELECT 
    'sfe_ingest_user' AS username,
    CASE 
        WHEN rsa_public_key_fp IS NOT NULL THEN '✓ Public key registered'
        ELSE '✗ NO PUBLIC KEY - Run sql/06_configure_auth.sql Step 4'
    END AS key_status,
    default_role AS role,
    disabled AS account_disabled
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE name = 'SFE_INGEST_USER'
AND deleted_on IS NULL;

-- ============================================================================
-- DONE
-- ============================================================================
-- 
-- Copy the API handoff document above and share with your data provider
-- along with the rsa_key.p8 file via a secure channel.
-- 
-- ============================================================================

