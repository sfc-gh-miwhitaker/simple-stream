/*******************************************************************************
 * Git Repository Setup for Snowflake Workspaces
 * 
 * PURPOSE:
 *   Connect this public GitHub repository to Snowflake for native Git integration
 *   Enables running the entire project from Snowsight with zero local setup
 * 
 * IMPORTANT: This is a PUBLIC repository!
 *   - No authentication required (Snowflake clones via HTTPS)
 *   - Read-only access (you cannot push changes back to GitHub)
 *   - You can fetch latest updates with: ALTER GIT REPOSITORY ... FETCH;
 *   - Perfect for demos, examples, and reference implementations
 * 
 * PREREQUISITES:
 *   - Snowflake account with ACCOUNTADMIN or CREATE DATABASE privileges
 *   - Network connectivity to github.com (for HTTPS clone)
 * 
 * USAGE:
 *   1. Open this file in a Snowflake worksheet (Snowsight UI)
 *   2. Execute all statements (no modifications needed!)
 *   3. Verify git repository with: SHOW GIT REPOSITORIES;
 *   4. Proceed to sql/00_git_setup/02_configure_secrets.sql
 * 
 * ESTIMATED TIME: < 1 minute
 ******************************************************************************/

-- Set role context for administrative operations
USE ROLE ACCOUNTADMIN;

-- Create API integration for GitHub (required for Git repositories)
-- This allows Snowflake to communicate with github.com over HTTPS
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE
  COMMENT = 'GitHub integration for Streaming-Ingest repository';

-- Create the SNOWFLAKE_EXAMPLE database if it doesn't exist
-- This serves as the container for both the repository and the pipeline objects
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'RFID Badge Tracking - Snowpipe Streaming REST API Demo';

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Create a schema to house the Git repository object
CREATE SCHEMA IF NOT EXISTS GIT_REPOS
  COMMENT = 'Git repository integrations';

USE SCHEMA GIT_REPOS;

-- Create Git repository object pointing to the public GitHub repo
-- Since this is a PUBLIC repository:
--   - No authentication required (HTTPS clone)
--   - Read-only access (cannot push changes)
--   - Can fetch latest updates anytime
CREATE OR REPLACE GIT REPOSITORY simple_stream_repo
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/simple-stream'
  COMMENT = 'Simple Stream - Snowflake-native Snowpipe Streaming REST API demo (public read-only)';

-- Verify repository was created successfully
SHOW GIT REPOSITORIES IN SCHEMA GIT_REPOS;

-- Fetch latest commits from origin/main
-- This ensures we have the most recent code
ALTER GIT REPOSITORY simple_stream_repo FETCH;

-- List files in the repository to verify clone succeeded
SELECT * FROM TABLE(
  LIST_GIT_REPOSITORY_FILES(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    ref => 'main'
  )
)
ORDER BY file_path
LIMIT 20;

/*******************************************************************************
 * SUCCESS CHECKPOINT
 * 
 * You should see:
 *   - API Integration: GIT_API_INTEGRATION
 *   - Database: SNOWFLAKE_EXAMPLE
 *   - Schema: GIT_REPOS
 *   - Repository: SIMPLE_STREAM_REPO
 *   - File listing showing: sql/, python/, notebooks/, etc.
 * 
 * NEXT STEPS:
 *   → Execute sql/00_git_setup/02_configure_secrets.sql
 *     (Create Snowflake secrets for JWT authentication)
 * 
 *   → Execute sql/00_git_setup/03_deploy_from_git.sql
 *     (Deploy pipeline objects from repository files)
 ******************************************************************************/

