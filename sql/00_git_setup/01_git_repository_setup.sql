/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Git Repository Setup for Snowflake Workspaces
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Connect public GitHub repository to Snowflake for native Git integration.
 *   Demonstrates browser-only deployment pattern with zero local setup.
 * 
 * IMPORTANT: This is a PUBLIC repository!
 *   - No authentication required (Snowflake clones via HTTPS)
 *   - Read-only access (you cannot push changes back to GitHub)
 *   - You can fetch latest updates with: ALTER GIT REPOSITORY ... FETCH;
 *   - Perfect for demos, examples, and reference implementations
 * 
 * OBJECTS CREATED:
 *   - SFE_GIT_API_INTEGRATION (API Integration) - GitHub access
 *   - SNOWFLAKE_EXAMPLE (Database) - Demo artifacts container
 *   - SNOWFLAKE_EXAMPLE.DEMO_REPO (Schema) - Git repository objects
 *   - sfe_simple_stream_repo (Git Repository) - Code repository
 * 
 * PREREQUISITES:
 *   - Snowflake account with ACCOUNTADMIN or CREATE DATABASE privileges
 *   - Network connectivity to github.com (for HTTPS clone)
 * 
 * USAGE:
 *   1. Open this file in Snowsight Workspaces (Projects → Workspaces → + SQL File)
 *   2. Execute all statements (no modifications needed!)
 *   3. Verify git repository with: SHOW GIT REPOSITORIES LIKE 'sfe_%';
 *   4. Proceed to sql/00_git_setup/02_configure_secrets.sql
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 * 
 * ESTIMATED TIME: < 1 minute
 ******************************************************************************/

-- Set role context for administrative operations
USE ROLE ACCOUNTADMIN;

-- Create API integration for GitHub (required for Git repositories)
-- This allows Snowflake to communicate with github.com over HTTPS
-- For PUBLIC repositories: No ALLOWED_AUTHENTICATION_SECRETS needed
-- SFE_ prefix prevents collision with production Git integrations
CREATE OR REPLACE API INTEGRATION SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/')
  ENABLED = TRUE
  COMMENT = 'DEMO: simple-stream - GitHub integration for public repository access';

-- Create the SNOWFLAKE_EXAMPLE database if it doesn't exist
-- This database is reserved for demo/example projects only
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Create a schema to house the Git repository object
-- Renamed from GIT_REPOS to DEMO_REPO for clarity
CREATE SCHEMA IF NOT EXISTS DEMO_REPO
  COMMENT = 'DEMO: simple-stream - Git repository and deployment automation';

USE SCHEMA DEMO_REPO;

-- Create Git repository object pointing to the public GitHub repo
-- Since this is a PUBLIC repository:
--   - No authentication required (HTTPS clone)
--   - Read-only access (cannot push changes)
--   - Can fetch latest updates anytime
-- sfe_ prefix identifies this as demo repository
CREATE OR REPLACE GIT REPOSITORY sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream'
  COMMENT = 'DEMO: sfe-simple-stream - Public repo for Snowpipe Streaming REST API example';

-- Verify repository was created successfully
SHOW GIT REPOSITORIES IN SCHEMA DEMO_REPO;

-- Fetch latest commits from origin/main
-- This ensures we have the most recent code
ALTER GIT REPOSITORY sfe_simple_stream_repo FETCH;

-- List files in the repository to verify clone succeeded
-- Using the LIST command (can also use LS shorthand)
LIST @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main;

/*******************************************************************************
 * SUCCESS CHECKPOINT
 * 
 * You should see:
 *   - API Integration: SFE_GIT_API_INTEGRATION
 *   - Database: SNOWFLAKE_EXAMPLE
 *   - Schema: DEMO_REPO
 *   - Repository: sfe_simple_stream_repo
 *   - File listing showing: sql/, python/, notebooks/, etc.
 * 
 * NEXT STEPS:
 *   → Execute sql/00_git_setup/02_configure_secrets.sql
 *     (Create Snowflake secrets for JWT authentication)
 * 
 *   → Execute sql/00_git_setup/03_deploy_from_git.sql
 *     (Deploy pipeline objects from repository files)
 ******************************************************************************/
