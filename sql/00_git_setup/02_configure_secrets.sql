/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Configure Secrets
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Provision JWT authentication secrets for the simulator.
 * OBJECTS: SFE_SS_ACCOUNT, SFE_SS_USER, SFE_SS_JWT_KEY
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA DEMO_REPO;

CREATE OR REPLACE SECRET SFE_SS_ACCOUNT
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_ACCOUNT_IDENTIFIER'
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake account identifier';

CREATE OR REPLACE SECRET SFE_SS_USER
  TYPE = GENERIC_STRING
  SECRET_STRING = 'YOUR_USERNAME'
  COMMENT = 'DEMO: sfe-simple-stream - Snowflake user for JWT auth';

CREATE OR REPLACE SECRET SFE_SS_JWT_KEY
  TYPE = GENERIC_STRING
  SECRET_STRING = '-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASC...
...PASTE YOUR FULL PRIVATE KEY HERE...
-----END PRIVATE KEY-----'
  COMMENT = 'DEMO: sfe-simple-stream - RSA private key for JWT tokens';

GRANT USAGE ON SECRET SFE_SS_ACCOUNT TO ROLE SYSADMIN;
GRANT USAGE ON SECRET SFE_SS_USER TO ROLE SYSADMIN;
GRANT USAGE ON SECRET SFE_SS_JWT_KEY TO ROLE SYSADMIN;
