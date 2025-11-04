/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Git Repository Setup
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Configure Snowflake Git integration to access the demo project repository
 *   from GitHub. This enables SQL-based deployment and code updates.
 * 
 * OBJECTS CREATED:
 *   - API Integration: SFE_GIT_API_INTEGRATION (account-level, public HTTPS)
 *   - Database: SNOWFLAKE_EXAMPLE (if not exists)
 *   - Schema: DEMO_REPO (for Git objects and automation)
 *   - Git Repository: sfe_simple_stream_repo (public GitHub repo)
 * 
 * DEPENDENCIES:
 *   - None (first script to run)
 *   - Requires ACCOUNTADMIN role
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_all.sql
 * 
 * ESTIMATED TIME: 10 seconds
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- STEP 1: Create API Integration for GitHub Access
-- ============================================================================

CREATE OR REPLACE API INTEGRATION SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/')
  ENABLED = TRUE
  COMMENT = 'DEMO: simple-stream - GitHub integration for public repository access';

-- ============================================================================
-- STEP 2: Create Database and Schema
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS DEMO_REPO
  COMMENT = 'DEMO: simple-stream - Git repository and deployment automation';

USE SCHEMA DEMO_REPO;

-- ============================================================================
-- STEP 3: Create Git Repository Object
-- ============================================================================

CREATE OR REPLACE GIT REPOSITORY sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream'
  COMMENT = 'DEMO: sfe-simple-stream - Public repo for Snowpipe Streaming REST API example';

-- ============================================================================
-- STEP 4: Fetch Repository Contents
-- ============================================================================

ALTER GIT REPOSITORY sfe_simple_stream_repo FETCH;

-- ============================================================================
-- VERIFICATION: Confirm setup succeeded
-- ============================================================================

-- Verify API integration exists and is enabled
SHOW API INTEGRATIONS LIKE 'SFE_GIT%';

-- Verify database and schema created
SHOW DATABASES LIKE 'SNOWFLAKE_EXAMPLE';
SHOW SCHEMAS LIKE 'DEMO_REPO' IN DATABASE SNOWFLAKE_EXAMPLE;

-- Verify Git repository exists
SHOW GIT REPOSITORIES IN SCHEMA DEMO_REPO;

-- List repository contents to confirm fetch worked
LS @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main;

-- Test reading a file from the repository
SELECT 
    'README.md Preview' AS file_name,
    SUBSTRING(file_content, 1, 200) AS preview
FROM TABLE(
    READ_GIT_FILE(
        repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
        file_path => 'README.md',
        ref => 'main'
    )
);

-- Verify key directories exist in repo
SELECT 
    relative_path,
    size,
    last_modified
FROM DIRECTORY(@SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main)
WHERE relative_path IN ('sql/', 'notebooks/', 'examples/', 'README.md')
ORDER BY relative_path;

-- ============================================================================
-- EXPECTED OUTPUT
-- ============================================================================
-- 
-- ✅ API Integration created: SFE_GIT_API_INTEGRATION (enabled)
-- ✅ Database created: SNOWFLAKE_EXAMPLE
-- ✅ Schema created: DEMO_REPO
-- ✅ Git repository created: sfe_simple_stream_repo
-- ✅ Repository fetched successfully
-- ✅ Files visible: sql/, notebooks/, examples/, README.md
-- 
-- If you see errors:
--   - "API integration already exists": This is OK (using CREATE OR REPLACE)
--   - "Authentication failed": Check GitHub URL is public
--   - "Directory not found": Repository may not have fetched; re-run FETCH
-- 
-- Next step: Run sql/00_git_setup/02_configure_secrets.sql
-- ============================================================================
