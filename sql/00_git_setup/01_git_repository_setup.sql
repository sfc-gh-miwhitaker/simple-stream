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

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- Create API Integration for GitHub Access (Idempotent)
-- ============================================================================
-- 
-- This is the ONLY SQL you need to run. The workspace UI will handle the rest!
-- 
-- Uses CREATE IF NOT EXISTS to safely skip if integration already exists.
-- Safe to run multiple times - won't affect existing Git workspaces.
--

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE
  COMMENT = 'DEMO: simple-stream - GitHub integration for public repository access';

-- ============================================================================
-- VERIFICATION: Confirm API integration was created
-- ============================================================================

SHOW API INTEGRATIONS LIKE 'SFE_GIT%';

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- API Integration: SFE_GIT_API_INTEGRATION (enabled = true)
-- 
-- ============================================================================
-- NEXT STEP: Create Git Workspace in Snowsight UI
-- ============================================================================
-- 
-- Now create your Git workspace to access all project files:
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
-- This creates both:
--    - A workspace UI (file explorer, notebooks, SQL editor)
--    - A Git repository object (Snowflake stage for EXECUTE IMMEDIATE FROM)
-- 
-- ============================================================================
-- AFTER WORKSPACE CREATION: Configure Secrets
-- ============================================================================
-- 
-- Open your new workspace and run: sql/00_git_setup/02_configure_secrets.sql
-- ============================================================================

