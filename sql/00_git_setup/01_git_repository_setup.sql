/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Git Repository Setup
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
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
-- Create API Integration for GitHub Access
-- ============================================================================
-- 
-- This is the ONLY SQL you need to run. The workspace UI will handle the rest!
--

CREATE OR REPLACE API INTEGRATION SFE_GIT_API_INTEGRATION
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
-- ✅ API Integration created: SFE_GIT_API_INTEGRATION (enabled = true)
-- 
-- ============================================================================
-- NEXT STEP: Create Git Workspace in Snowsight
-- ============================================================================
-- 
-- Now create your persistent Git workspace in the Snowsight UI:
-- 
-- 1. In Snowsight, go to: Projects → Workspaces
-- 
-- 2. Click: "+ Workspace" → "From Git repository"
-- 
-- 3. Fill in the form:
--    • Repository URL:    https://github.com/sfc-gh-miwhitaker/sfe-simple-stream
--    • Workspace Name:    sfe-simple-stream
--    • API Integration:   SFE_GIT_API_INTEGRATION  ← Created by this script!
--    • Authentication:    No authentication (public repo)
--    • Branch:            main
-- 
-- 4. Click "Create"
-- 
-- ✅ Done! Your workspace will:
--    - Appear in Projects → Workspaces (persists across sessions)
--    - Show all SQL files, notebooks, and docs in the file explorer
--    - Allow you to run scripts directly from the Git repository
-- 
-- ============================================================================
-- AFTER WORKSPACE CREATION: Configure Secrets
-- ============================================================================
-- 
-- Next, open and run: sql/00_git_setup/02_configure_secrets.sql
-- (You can find it in your new Git workspace file explorer!)
-- ============================================================================
