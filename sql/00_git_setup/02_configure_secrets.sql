/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Configure Snowflake Secrets for JWT Authentication
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create Snowflake secrets to store JWT authentication credentials.
 *   Enables the simulator notebook to authenticate with Snowpipe Streaming API.
 *   Replaces need for local .env files - all credentials stored in Snowflake.
 * 
 * OBJECTS CREATED:
 *   - SFE_SS_ACCOUNT (Secret) - Snowflake account identifier
 *   - SFE_SS_USER (Secret) - Snowflake username
 *   - SFE_SS_JWT_KEY (Secret) - RSA private key for JWT
 * 
 * PREREQUISITES:
 *   - sql/00_git_setup/01_git_repository_setup.sql executed
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
 *   Secrets are encrypted at rest and access-controlled via RBAC.
 *   Use USAGE privilege to allow notebooks to read secrets without viewing them.
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 * 
 * ESTIMATED TIME: < 2 minutes
 ******************************************************************************/

-- Set context
USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA DEMO_REPO;  -- Store secrets alongside repository object

/*******************************************************************************
 * STEP 1: Create Secrets for JWT Authentication
 * 
 * SFE_SS_ prefix = SnowFlake Example Simple Stream
 * Prevents collision with production secrets
 ******************************************************************************/

-- Secret: Snowflake Account Identifier
-- This is your account locator (e.g., MYORG-ACCOUNT123)
-- Find it in: Admin → Accounts → <hover over account name>
CREATE OR REPLACE SECRET SFE_SS_ACCOUNT
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_ACCOUNT_IDENTIFIER'  -- TODO: Replace with your account identifier
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake account identifier for REST API authentication';

-- Secret: Snowflake Username
-- The user that owns the registered public key
CREATE OR REPLACE SECRET SFE_SS_USER
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_USERNAME'  -- TODO: Replace with your username (e.g., DEMO_USER)
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake user for JWT authentication';

-- Secret: RSA Private Key (PEM format)
-- The full private key content including headers
-- Example format:
--   -----BEGIN PRIVATE KEY-----
--   MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7...
--   ... (multiple lines of base64) ...
--   -----END PRIVATE KEY-----
CREATE OR REPLACE SECRET SFE_SS_JWT_KEY
  TYPE = GENERIC_STRING
  SECRET_STRING = '-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASC...
...PASTE YOUR FULL PRIVATE KEY HERE...
-----END PRIVATE KEY-----'  -- TODO: Replace with your private key content
  COMMENT = 'DEMO: sfe-simple-stream - RSA private key for JWT token generation';

/*******************************************************************************
 * STEP 2: Verify Secrets Were Created
 ******************************************************************************/

-- List secrets (shows metadata only, not values)
SHOW SECRETS IN SCHEMA DEMO_REPO;

-- Test secret retrieval (for your eyes only - validates syntax)
-- Comment these out after verification for security
-- SELECT SYSTEM$GET_SECRET('SFE_SS_ACCOUNT') AS account_test;
-- SELECT SYSTEM$GET_SECRET('SFE_SS_USER') AS user_test;
-- SELECT LEFT(SYSTEM$GET_SECRET('SFE_SS_JWT_KEY'), 50) AS key_preview;

/*******************************************************************************
 * STEP 3: Grant Access to Secrets
 * 
 * By default, only ACCOUNTADMIN can read secrets.
 * Grant USAGE to roles that need to run the simulator notebook.
 ******************************************************************************/

-- Grant to SYSADMIN for operational use
GRANT USAGE ON SECRET SFE_SS_ACCOUNT TO ROLE SYSADMIN;
GRANT USAGE ON SECRET SFE_SS_USER TO ROLE SYSADMIN;
GRANT USAGE ON SECRET SFE_SS_JWT_KEY TO ROLE SYSADMIN;

-- Grant to your working role (uncomment and update ROLE_NAME)
-- GRANT USAGE ON SECRET SFE_SS_ACCOUNT TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON SECRET SFE_SS_USER TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON SECRET SFE_SS_JWT_KEY TO ROLE <YOUR_ROLE>;

/*******************************************************************************
 * SUCCESS CHECKPOINT
 * 
 * You should see:
 *   - 3 secrets created: SFE_SS_ACCOUNT, SFE_SS_USER, SFE_SS_JWT_KEY
 *   - All secrets showing type = GENERIC_STRING
 *   - Access granted to appropriate roles
 * 
 * TESTING YOUR SETUP:
 *   1. Verify public key is registered with your user:
 *      DESC USER YOUR_USERNAME;
 *      -- Look for RSA_PUBLIC_KEY_FP (fingerprint) populated
 * 
 *   2. Test JWT secret retrieval:
 *      SELECT SYSTEM$GET_SECRET('SFE_SS_ACCOUNT') AS account;
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
