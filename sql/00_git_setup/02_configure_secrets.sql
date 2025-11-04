/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Configure Secrets for JWT Authentication
 * 
 * WARNING: NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create Snowflake secrets to securely store JWT authentication credentials
 *   for the RFID simulator notebook (notebooks/RFID_Simulator.ipynb).
 * 
 * WARNING:  ONLY NEEDED IF: You plan to run the simulator notebook!
 *   
 *   If you're just deploying the SQL pipeline and monitoring views, you can
 *   SKIP this script and go directly to sql/00_git_setup/03_deploy_from_git.sql
 * 
 * OBJECTS CREATED:
 *   - Secret: SFE_SS_ACCOUNT (Snowflake account identifier)
 *   - Secret: SFE_SS_USER (Username for JWT authentication)
 *   - Secret: SFE_SS_JWT_KEY (RSA private key in PEM format)
 * 
 * USED BY:
 *   - notebooks/RFID_Simulator.ipynb (reads these secrets for REST API auth)
 * 
 * DEPENDENCIES:
 *   - sql/00_git_setup/01_git_repository_setup.sql (must run first)
 *   - Git workspace created in Snowsight
 *   - RSA key pair generated (see config/jwt_keypair_setup.md)
 * 
 * WORKFLOW:
 *   1. Run queries to GET your account identifier and username (see below)
 *   2. Copy the values into the SECRET_STRING fields
 *   3. Generate RSA key pair (instructions provided)
 *   4. Copy private key into the secret
 *   5. Run the entire script to create all secrets
 * 
 * TIP: Run the SELECT queries first to see your values, then edit and run all!
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 2 minutes (includes key generation)
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

-- Create database and schema if they don't exist yet
-- (These may already exist if you created the Git workspace in the UI)
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO
  COMMENT = 'DEMO: sfe-simple-stream - Git repository and secrets';

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA DEMO_REPO;

-- ============================================================================
-- STEP 1: Find Your Account Identifier (Choose One Method)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- METHOD 1: Get from Snowsight UI (Easiest)
-- ---------------------------------------------------------------------------
-- 
-- 1. In Snowsight, click your username (top-right corner)
-- 2. Select "Account" from the dropdown
-- 3. Look for "Account identifier" in the popup
--    OR
-- 1. Go to Admin → Accounts
-- 2. Click "Connect a tool to Snowflake" 
-- 3. Copy the account identifier shown
-- 
-- Format: ORGNAME-ACCOUNTNAME (e.g., MYORG-DEMO123)
-- 

-- ---------------------------------------------------------------------------
-- METHOD 2: Get Programmatically (Run this query)
-- ---------------------------------------------------------------------------
-- 
-- Run this to extract your account identifier:

SELECT 
    CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS account_identifier,
    'Copy the value above and paste into SECRET_STRING below' AS instruction;
--

-- ============================================================================
-- STEP 2: Store Account Identifier as Secret
-- ============================================================================

CREATE OR REPLACE SECRET SFE_SS_ACCOUNT
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_ACCOUNT_IDENTIFIER'  -- WARNING: EDIT THIS: Paste the value from above
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake account identifier for REST API';

-- ============================================================================
-- STEP 3: Find Your Username (Choose One Method)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- METHOD 1: Get from Snowsight UI
-- ---------------------------------------------------------------------------
-- 
-- Look at the top-right corner of Snowsight - your username is displayed there
-- 

-- ---------------------------------------------------------------------------
-- METHOD 2: Get Programmatically (Run this query)
-- ---------------------------------------------------------------------------

SELECT 
    CURRENT_USER() AS username,
    'Copy the value above and paste into SECRET_STRING below' AS instruction;
--

-- ============================================================================
-- STEP 4: Store Username as Secret
-- ============================================================================

CREATE OR REPLACE SECRET SFE_SS_USER
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_USERNAME'  -- WARNING: EDIT THIS: Paste the value from above
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake user for JWT authentication';

-- ============================================================================
-- STEP 5: Store RSA Private Key
-- ============================================================================
-- 
--  How to get your private key:
--   1. If using OpenSSL (see config/jwt_keypair_setup.md):
--      cat config/rsa_key.p8
--   
--   2. If using Python cryptography library:
--      from cryptography.hazmat.primitives import serialization
--      from cryptography.hazmat.primitives.asymmetric import rsa
--      
--      private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
--      pem = private_key.private_bytes(
--          encoding=serialization.Encoding.PEM,
--          format=serialization.PrivateFormat.PKCS8,
--          encryption_algorithm=serialization.NoEncryption()
--      )
--      print(pem.decode())
--   
--   3. Copy the ENTIRE output including headers:
--      -----BEGIN PRIVATE KEY-----
--      MIIEvQIBADANBgkqhkiG9w0BAQ...
--      (multiple lines of base64-encoded data)
--      ...
--      -----END PRIVATE KEY-----
-- 
-- WARNING:  SECURITY NOTES:
--   - Never commit private keys to Git
--   - Keep the key secure (treat like a password)
--   - For production, use encrypted keys with passphrases
--   - Rotate keys periodically
-- 

CREATE OR REPLACE SECRET SFE_SS_JWT_KEY
  TYPE = GENERIC_STRING
  SECRET_STRING = '-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASC...
...PASTE YOUR FULL PRIVATE KEY HERE (REPLACE ALL THESE LINES)...
...INCLUDE ALL LINES FROM YOUR KEY FILE...
-----END PRIVATE KEY-----'  -- WARNING: EDIT THIS: Paste your complete private key
  COMMENT = 'DEMO: sfe-simple-stream - RSA private key (PKCS#8 format) for JWT token generation';

-- ============================================================================
-- STEP 4: Grant Permissions
-- ============================================================================

GRANT USAGE ON SECRET SFE_SS_ACCOUNT TO ROLE SYSADMIN;
GRANT USAGE ON SECRET SFE_SS_USER TO ROLE SYSADMIN;
GRANT USAGE ON SECRET SFE_SS_JWT_KEY TO ROLE SYSADMIN;

-- ============================================================================
-- VERIFICATION: Confirm secrets were created
-- ============================================================================

SHOW SECRETS IN SCHEMA DEMO_REPO;

-- Verify secrets exist (DESC shows metadata without revealing values)
DESC SECRET SFE_SS_ACCOUNT;
DESC SECRET SFE_SS_USER;
DESC SECRET SFE_SS_JWT_KEY;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
--  Secrets created: SFE_SS_ACCOUNT, SFE_SS_USER, SFE_SS_JWT_KEY
--  Permissions granted to SYSADMIN role
--  SHOW SECRETS displays all 3 secrets
--  DESC SECRET shows metadata (type, comment, created date)
-- 
-- NOTE: Secret values are never displayed in SQL queries (security feature)
-- 
-- To test if secrets work, you need to:
-- 1. Run the Jupyter Notebook (notebooks/RFID_Simulator.ipynb)
-- 2. Cell 2 will attempt to load secrets using _snowflake.get_generic_secret_string()
-- 3. If secrets load successfully, you'll see account/user displayed
-- 
-- WARNING:  Common Issues:
-- 
-- If secrets don't work in notebook:
--   - Verify you replaced ALL placeholder values (YOUR_ACCOUNT_IDENTIFIER, etc.)
--   - Check SECRET_STRING is enclosed in single quotes
--   - For multi-line JWT key, all lines must be within the quotes
--   - JWT key should be ~1600-1700 characters for 2048-bit RSA key
--   - Ensure you included -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
-- 
-- If you need to update a secret:
--   - Re-run the CREATE OR REPLACE SECRET command with corrected value
--   - Secrets are immutable but can be replaced entirely
-- 
-- ============================================================================
-- NEXT STEPS
-- ============================================================================
-- 
--  Secrets configured! Now you can:
-- 
-- 1. Deploy the SQL pipeline:
--    → Run: sql/00_git_setup/03_deploy_from_git.sql
-- 
-- 2. Run the RFID Simulator notebook:
--    → Open: notebooks/RFID_Simulator.ipynb (in your Git workspace)
--    → The notebook will use these secrets for JWT authentication
--    → Sends simulated badge events via Snowpipe Streaming REST API
-- 
-- WARNING:  Remember: These secrets are ONLY needed for the simulator notebook!
--     The SQL pipeline deployment (step 1) does not require them.
-- 
-- ============================================================================
