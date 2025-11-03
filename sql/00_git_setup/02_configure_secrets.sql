/*******************************************************************************
 * Configure Snowflake Secrets for JWT Authentication
 * 
 * PURPOSE:
 *   Create Snowflake secrets to store JWT authentication credentials
 *   Enables the simulator notebook to authenticate with Snowpipe Streaming API
 *   Replaces need for local .env files - all credentials stored in Snowflake
 * 
 * PREREQUISITES:
 *   - RSA key pair generated (see config/jwt_keypair_setup.md in repository)
 *   - Public key registered: ALTER USER <username> SET RSA_PUBLIC_KEY='...';
 *   - Private key content ready to paste
 * 
 * USAGE:
 *   1. Generate RSA key pair if not already done
 *   2. Register public key with your Snowflake user
 *   3. Update the placeholder values below with your actual credentials
 *   4. Execute all statements
 * 
 * SECURITY NOTE:
 *   Secrets are encrypted at rest and access-controlled via RBAC
 *   Use USAGE privilege to allow notebooks to read secrets without viewing them
 * 
 * ESTIMATED TIME: < 2 minutes
 ******************************************************************************/

-- Set context
USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA GIT_REPOS;  -- Store secrets alongside repository object

/*******************************************************************************
 * STEP 1: Create Secrets for JWT Authentication
 ******************************************************************************/

-- Secret: Snowflake Account Identifier
-- This is your account locator (e.g., MYORG-ACCOUNT123)
-- Find it in: Admin → Accounts → <hover over account name>
CREATE OR REPLACE SECRET RFID_ACCOUNT
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_ACCOUNT_IDENTIFIER'  -- TODO: Replace with your account identifier
  COMMENT = 'Snowflake account identifier for REST API authentication';

-- Secret: Snowflake Username
-- The user that owns the registered public key
CREATE OR REPLACE SECRET RFID_USER
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_USERNAME'  -- TODO: Replace with your username (e.g., DEMO_USER)
  COMMENT = 'Snowflake user for JWT authentication';

-- Secret: RSA Private Key (PEM format)
-- The full private key content including headers
-- Example format:
--   -----BEGIN PRIVATE KEY-----
--   MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7...
--   ... (multiple lines of base64) ...
--   -----END PRIVATE KEY-----
CREATE OR REPLACE SECRET RFID_JWT_PRIVATE_KEY
  TYPE = GENERIC_STRING
  SECRET_STRING = '-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASC...
...PASTE YOUR FULL PRIVATE KEY HERE...
-----END PRIVATE KEY-----'  -- TODO: Replace with your private key content
  COMMENT = 'RSA private key for JWT token generation';

/*******************************************************************************
 * STEP 2: Verify Secrets Were Created
 ******************************************************************************/

-- List secrets (shows metadata only, not values)
SHOW SECRETS IN SCHEMA GIT_REPOS;

-- Test secret retrieval (for your eyes only - validates syntax)
-- Comment these out after verification for security
-- SELECT SYSTEM$GET_SECRET('RFID_ACCOUNT') AS account_test;
-- SELECT SYSTEM$GET_SECRET('RFID_USER') AS user_test;
-- SELECT LEFT(SYSTEM$GET_SECRET('RFID_JWT_PRIVATE_KEY'), 50) AS key_preview;

/*******************************************************************************
 * STEP 3: Grant Access to Secrets
 * 
 * By default, only ACCOUNTADMIN can read secrets
 * Grant USAGE to roles that need to run the simulator notebook
 ******************************************************************************/

-- Grant to SYSADMIN for operational use
GRANT USAGE ON SECRET RFID_ACCOUNT TO ROLE SYSADMIN;
GRANT USAGE ON SECRET RFID_USER TO ROLE SYSADMIN;
GRANT USAGE ON SECRET RFID_JWT_PRIVATE_KEY TO ROLE SYSADMIN;

-- Grant to your working role (update ROLE_NAME)
-- GRANT USAGE ON SECRET RFID_ACCOUNT TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON SECRET RFID_USER TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON SECRET RFID_JWT_PRIVATE_KEY TO ROLE <YOUR_ROLE>;

/*******************************************************************************
 * SUCCESS CHECKPOINT
 * 
 * You should see:
 *   - 3 secrets created: RFID_ACCOUNT, RFID_USER, RFID_JWT_PRIVATE_KEY
 *   - All secrets showing type = GENERIC_STRING
 *   - Access granted to appropriate roles
 * 
 * TESTING YOUR SETUP:
 *   1. Verify public key is registered with your user:
 *      DESC USER YOUR_USERNAME;
 *      -- Look for RSA_PUBLIC_KEY_FP (fingerprint) populated
 * 
 *   2. Test JWT generation in a worksheet:
 *      SELECT SYSTEM$GET_SECRET('RFID_ACCOUNT') AS account;
 *      -- Should return your account identifier (not 'YOUR_ACCOUNT_IDENTIFIER')
 * 
 * NEXT STEPS:
 *   → Execute sql/00_git_setup/03_deploy_from_git.sql
 *     (Deploy pipeline objects: database, schemas, tables, streams, tasks)
 * 
 *   → Open notebooks/RFID_Simulator.ipynb in Snowsight
 *     (Run the simulator to send events via REST API)
 * 
 * SECURITY REMINDERS:
 *   - Never commit private keys to Git
 *   - Rotate keys every 90 days (see config/jwt_keypair_setup.md)
 *   - Audit secret access: SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.SECRETS_HISTORY;
 ******************************************************************************/

