/*******************************************************************************
 * Configure Authentication for Data Provider
 * 
 * PURPOSE: Set up a service account with key pair auth for external data ingestion
 * 
 * RUN THIS ONCE: Before sharing API configuration with data provider
 * 
 * TIME: 5 minutes
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Create service account for data ingestion
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS sfe_ingest_user
  COMMENT = 'Service account for external badge event ingestion'
  DEFAULT_ROLE = 'PUBLIC'
  MUST_CHANGE_PASSWORD = FALSE;

CREATE ROLE IF NOT EXISTS sfe_ingest_role
  COMMENT = 'Role for Snowpipe Streaming ingestion';

GRANT ROLE sfe_ingest_role TO USER sfe_ingest_user;

-- ============================================================================
-- STEP 2: Grant privileges to ingest data
-- ============================================================================

USE ROLE SYSADMIN;

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE sfe_ingest_role;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION TO ROLE sfe_ingest_role;
GRANT INSERT ON PIPE SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE TO ROLE sfe_ingest_role;

-- ============================================================================
-- STEP 3: Generate RSA key pair (run on your local machine)
-- ============================================================================

-- Run these commands in your terminal:
-- 
-- openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
-- openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
--
-- This creates:
--   rsa_key.p8   (private key - give to data provider, NEVER commit to git)
--   rsa_key.pub  (public key  - register with Snowflake below)

-- ============================================================================
-- STEP 4: Register public key with Snowflake
-- ============================================================================

-- Copy the contents of rsa_key.pub (without header/footer lines)
-- and paste into the command below:

USE ROLE ACCOUNTADMIN;

ALTER USER sfe_ingest_user SET RSA_PUBLIC_KEY='
-----PASTE YOUR PUBLIC KEY HERE-----
';

-- Example:
-- ALTER USER sfe_ingest_user SET RSA_PUBLIC_KEY='
-- MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy...
-- ';

-- ============================================================================
-- STEP 5: Verify setup
-- ============================================================================

SHOW USERS LIKE 'sfe_ingest_user';
SHOW GRANTS TO ROLE sfe_ingest_role;

-- ============================================================================
-- STEP 6: Share credentials with data provider
-- ============================================================================

SELECT '
================================================================================
CREDENTIALS FOR DATA PROVIDER
================================================================================

Username:     sfe_ingest_user
Role:         sfe_ingest_role
Private Key:  rsa_key.p8 (file you generated)

IMPORTANT: 
- Share rsa_key.p8 via secure channel (encrypted email, vault, etc.)
- NEVER commit private key to version control
- Private key file should be kept secure by data provider

Account Information:
  Account ID:   ' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '
  Account URL:  ' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '.snowflakecomputing.com

================================================================================
' AS credentials;

-- ============================================================================
-- DONE
-- ============================================================================
-- 
-- Next: Run @sql/deploy.sql to get API configuration for data provider
-- 
-- ============================================================================

