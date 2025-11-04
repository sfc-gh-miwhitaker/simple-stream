/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Git Repository Setup
 * 
 * WARNING:  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create API integration for GitHub access. This is the ONLY thing you need
 *   to run manually - the workspace UI will create the rest for you!
 * 
 * SETUP STEPS (IN ORDER):
 *   1. Run this script (creates API integration only)
 *   2. Create Git workspace in Snowsight UI (see instructions below)
 *   3. Done! Workspace persists and all SQL files are accessible
 * 
 * OBJECTS CREATED BY THIS SCRIPT:
 *   - API Integration: SFE_GIT_API_INTEGRATION (required for workspace creation)
 * 
 * OBJECTS CREATED BY WORKSPACE UI:
 *   - Git Repository object (auto-created when you add the workspace)
 *   - Persistent workspace (appears in Projects → Workspaces)
 * 
 * DEPENDENCIES:
 *   - None (first script to run)
 *   - Requires ACCOUNTADMIN role (for API integration)
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 5 seconds (script) + 30 seconds (workspace creation in UI)
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Create Database and Schema (as SYSADMIN)
-- ============================================================================
-- Database and schema owned by SYSADMIN for proper permission management

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO
  COMMENT = 'DEMO: sfe-simple-stream - Git repository and secrets';

-- ============================================================================
-- STEP 2: Create API Integration for GitHub Access (Requires ACCOUNTADMIN)
-- ============================================================================
-- 
-- This is the ONLY operation that requires ACCOUNTADMIN.
-- Uses CREATE IF NOT EXISTS to safely skip if integration already exists.
-- Safe to run multiple times - won't affect existing Git workspaces.
--

USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE
  COMMENT = 'DEMO: simple-stream - GitHub integration for public repository access';

-- Grant USAGE on integration to SYSADMIN
GRANT USAGE ON INTEGRATION SFE_GIT_API_INTEGRATION TO ROLE SYSADMIN;

-- ============================================================================
-- STEP 3: Create Git Repository Object (as SYSADMIN)
-- ============================================================================
--
-- Create the Git repository object that enables EXECUTE IMMEDIATE FROM syntax.
-- This is separate from (and in addition to) the workspace you'll create in the UI.
--

USE ROLE SYSADMIN;

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream'
  COMMENT = 'DEMO: sfe-simple-stream - Git repository object for automated deployment';

-- ============================================================================
-- STEP 4: VERIFICATION - Confirm objects were created
-- ============================================================================

USE ROLE SYSADMIN;

SHOW GIT REPOSITORIES IN SCHEMA SNOWFLAKE_EXAMPLE.DEMO_REPO;

SELECT
    'Git Repository' AS object_type,
    COUNT(*) AS actual_count,
    1 AS expected_count,
    IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- API Integration: SFE_GIT_API_INTEGRATION (enabled = true)
-- Git Repository:  SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo (created)
-- Database:        SNOWFLAKE_EXAMPLE
-- Schema:          DEMO_REPO
-- 
-- ============================================================================
-- NEXT STEP: Create Git Workspace in Snowsight UI (OPTIONAL but RECOMMENDED)
-- ============================================================================
-- 
-- For the best development experience, create a Git workspace:
-- 
-- 1. In Snowsight, go to: Projects → Workspaces
-- 2. Click: "+ Workspace" → "From Git repository"
-- 3. Fill in the form:
--    - Repository URL:    https://github.com/sfc-gh-miwhitaker/sfe-simple-stream
--    - Workspace Name:    sfe-simple-stream
--    - API Integration:   SFE_GIT_API_INTEGRATION
--    - Authentication:    No authentication (public repo)
--    - Branch:            main
-- 4. Click "Create"
-- 
-- Benefits:
--    - File explorer for browsing all SQL scripts and notebooks
--    - Syntax highlighting and code completion
--    - Easy navigation and file management
-- 
-- NOTE: The workspace is separate from the Git repository object created above.
--       The Git repo object (sfe_simple_stream_repo) is used by deployment scripts.
--       The workspace is used for interactive development.
-- 
-- ============================================================================
-- NEXT STEP: Configure Secrets OR Deploy Pipeline
-- ============================================================================
-- 
-- Option A: Configure secrets first (needed for simulator):
--   Run: sql/00_git_setup/02_configure_secrets.sql
-- 
-- Option B: Skip to automated deployment (secrets optional):
--   Run: sql/00_git_setup/03_deploy_from_git.sql
-- ============================================================================

