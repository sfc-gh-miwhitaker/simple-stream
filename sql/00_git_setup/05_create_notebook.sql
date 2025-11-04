/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Create Notebook from Git Repository
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create the RFID_Simulator notebook programmatically from the Git repository.
 *   This eliminates the need for manual UI steps to upload the notebook.
 * 
 * OBJECTS CREATED:
 *   - Notebook: RFID_SIMULATOR (in SNOWFLAKE_EXAMPLE.DEMO_REPO)
 * 
 * DEPENDENCIES:
 *   - sql/00_git_setup/01_git_repository_setup.sql (Git repo must exist)
 *   - notebooks/RFID_Simulator.ipynb (must exist in Git repo)
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → Open this file → Run All
 *   OR: Run from automated deployment script
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
-- STEP 1: Create Notebook from Git Repository
-- ============================================================================
--
-- Creates a notebook object from the .ipynb file in the Git repository.
-- The notebook will be accessible via Projects → Notebooks in Snowsight.
--
-- Note: After creation, we need to add a live version before the notebook
--       can be executed programmatically via EXECUTE NOTEBOOK command.
--

CREATE OR REPLACE NOTEBOOK SNOWFLAKE_EXAMPLE.DEMO_REPO.RFID_SIMULATOR
  FROM '@SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/notebooks/'
  MAIN_FILE = 'RFID_Simulator.ipynb'
  QUERY_WAREHOUSE = COMPUTE_WH
  COMMENT = 'DEMO: sfe-simple-stream - RFID badge event simulator using Snowpipe Streaming REST API';

-- ============================================================================
-- STEP 2: Add Live Version for Programmatic Execution
-- ============================================================================
--
-- A "live version" is required to execute the notebook via SQL commands.
-- This creates the live version from the last-created version.
--

ALTER NOTEBOOK SNOWFLAKE_EXAMPLE.DEMO_REPO.RFID_SIMULATOR 
  ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- STEP 3: Associate Secrets with Notebook
-- ============================================================================
--
-- Notebooks access secrets via st.secrets, which requires associating
-- the secrets with the notebook using ALTER NOTEBOOK SET SECRETS.
--

USE ROLE ACCOUNTADMIN;

ALTER NOTEBOOK SNOWFLAKE_EXAMPLE.DEMO_REPO.RFID_SIMULATOR
  SET SECRETS = (
    'jwt_key' = SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_SS_JWT_KEY,
    'account' = SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_SS_ACCOUNT,
    'user' = SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_SS_USER
  );

-- ============================================================================
-- VERIFICATION: Confirm Notebook Was Created
-- ============================================================================

SHOW NOTEBOOKS IN SCHEMA SNOWFLAKE_EXAMPLE.DEMO_REPO;

SELECT
    'Notebook' AS object_type,
    COUNT(*) AS actual_count,
    1 AS expected_count,
    IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'RFID_SIMULATOR';

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- Notebook: RFID_SIMULATOR
-- Status: PASS (1 notebook created)
-- 
-- ============================================================================
-- NEXT STEPS: How to Use the Notebook
-- ============================================================================
-- 
-- Option 1: Open in Snowsight UI
--   1. Go to: Projects → Notebooks
--   2. Find: RFID_SIMULATOR
--   3. Click to open and run interactively
-- 
-- Option 2: Execute Programmatically (Advanced)
--   EXECUTE NOTEBOOK SNOWFLAKE_EXAMPLE.DEMO_REPO.RFID_SIMULATOR();
--   
--   Note: This runs the entire notebook and returns results.
--         Requires live version (already configured above).
-- 
-- Option 3: Execute from Stored Procedure
--   See sql/00_git_setup/04_stored_procedures.sql for wrapper examples
-- 
-- ============================================================================
-- PREREQUISITES FOR NOTEBOOK EXECUTION
-- ============================================================================
-- 
-- The notebook requires secrets to be configured. Run this first:
--   sql/00_git_setup/02_configure_secrets.sql
-- 
-- The notebook needs:
--   - Secret: SFE_SS_JWT_KEY (JWT private key)
--   - Secret: SFE_SS_ACCOUNT (account identifier)
--   - Secret: SFE_SS_USER (username)
-- 
-- Without these, the notebook will fail when trying to authenticate.
-- 
-- ============================================================================

