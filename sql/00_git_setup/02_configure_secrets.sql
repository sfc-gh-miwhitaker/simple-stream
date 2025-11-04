/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Configure Secrets for JWT Authentication
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create Snowflake secrets to securely store JWT authentication credentials
 *   for the RFID simulator and REST API client.
 * 
 * OBJECTS CREATED:
 *   - Secret: SFE_SS_ACCOUNT (Snowflake account identifier)
 *   - Secret: SFE_SS_USER (Username for JWT authentication)
 *   - Secret: SFE_SS_JWT_KEY (RSA private key in PEM format)
 * 
 * DEPENDENCIES:
 *   - sql/00_git_setup/01_git_repository_setup.sql (must run first)
 *   - RSA key pair generated (see config/jwt_keypair_setup.md)
 * 
 * ⚠️  IMPORTANT: This script requires manual editing with your credentials!
 * 
 * USAGE:
 *   1. Find your account identifier (see instructions below)
 *   2. Get your username from Snowsight
 *   3. Generate and copy your private key
 *   4. Update the SECRET_STRING values below
 *   5. Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 5 seconds (after manual edits)
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA DEMO_REPO;

-- ============================================================================
-- STEP 1: Store Account Identifier
-- ============================================================================
-- 
-- 📋 How to find your account identifier:
--   1. Look at your Snowsight URL: https://<ACCOUNT>.snowflakecomputing.com
--   2. Or run: SELECT CURRENT_ACCOUNT();
--   3. Format: ORGNAME-ACCOUNTNAME (e.g., MYORG-DEMO123)
--   4. Use UPPERCASE for consistency
-- 
-- Examples:
--   - 'ACME-PROD456'
--   - 'MYCOMPANY-DEV789'
--   - 'TESTORG-SANDBOX001'
-- 

CREATE OR REPLACE SECRET SFE_SS_ACCOUNT
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_ACCOUNT_IDENTIFIER'  -- ⚠️ EDIT THIS: e.g., 'MYORG-ACCOUNT123'
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake account identifier for REST API';

-- ============================================================================
-- STEP 2: Store Username
-- ============================================================================
-- 
-- 📋 How to find your username:
--   1. Look at top-right corner of Snowsight
--   2. Or run: SELECT CURRENT_USER();
--   3. Use the exact username (case-sensitive)
-- 
-- Examples:
--   - 'JSMITH'
--   - 'john.smith@company.com'
--   - 'DEMO_USER'
-- 

CREATE OR REPLACE SECRET SFE_SS_USER
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_USERNAME'  -- ⚠️ EDIT THIS: Your Snowflake username
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake user for JWT authentication';

-- ============================================================================
-- STEP 3: Store RSA Private Key
-- ============================================================================
-- 
-- 📋 How to get your private key:
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
-- ⚠️  SECURITY NOTES:
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
-----END PRIVATE KEY-----'  -- ⚠️ EDIT THIS: Paste your complete private key
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

-- Test that secrets can be retrieved (won't show actual values)
SELECT 
    'SFE_SS_ACCOUNT' AS secret_name,
    CASE 
        WHEN LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_ACCOUNT')) > 0 
        THEN '✅ Set (length: ' || LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_ACCOUNT')) || ' chars)'
        ELSE '❌ Empty or not set'
    END AS status
UNION ALL
SELECT 
    'SFE_SS_USER' AS secret_name,
    CASE 
        WHEN LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_USER')) > 0 
        THEN '✅ Set (length: ' || LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_USER')) || ' chars)'
        ELSE '❌ Empty or not set'
    END AS status
UNION ALL
SELECT 
    'SFE_SS_JWT_KEY' AS secret_name,
    CASE 
        WHEN LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_JWT_KEY')) > 1000 
        THEN '✅ Set (length: ' || LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_JWT_KEY')) || ' chars - looks valid)'
        WHEN LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_JWT_KEY')) > 0
        THEN '⚠️  Set but seems too short (' || LENGTH(GET_GENERIC_SECRET_STRING('SFE_SS_JWT_KEY')) || ' chars - check key)'
        ELSE '❌ Empty or not set'
    END AS status;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- ✅ Secrets created: SFE_SS_ACCOUNT, SFE_SS_USER, SFE_SS_JWT_KEY
-- ✅ Permissions granted to SYSADMIN role
-- ✅ All secrets show as "Set" with appropriate lengths
-- 
-- ⚠️  If you see "Empty or not set":
--   - Check that you replaced the placeholder values
--   - Ensure SECRET_STRING is enclosed in single quotes
--   - For multi-line keys, all lines must be within the quotes
-- 
-- ⚠️  If JWT key shows "too short":
--   - You may have only pasted part of the key
--   - A valid PKCS#8 2048-bit key is ~1600-1700 characters
--   - Re-paste the complete key including headers/footers
-- 
-- Next step: Run sql/00_git_setup/03_deploy_from_git.sql
-- ============================================================================
