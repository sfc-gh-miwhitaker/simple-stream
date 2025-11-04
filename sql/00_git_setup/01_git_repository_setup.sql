/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Git Repository Setup
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Configure Snowflake Git integration for the demo repository.
 * OBJECTS: SFE_GIT_API_INTEGRATION, SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE API INTEGRATION SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/')
  ENABLED = TRUE
  COMMENT = 'DEMO: simple-stream - GitHub integration for public repository access';

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS DEMO_REPO
  COMMENT = 'DEMO: simple-stream - Git repository and deployment automation';

USE SCHEMA DEMO_REPO;

CREATE OR REPLACE GIT REPOSITORY sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream'
  COMMENT = 'DEMO: sfe-simple-stream - Public repo for Snowpipe Streaming REST API example';

ALTER GIT REPOSITORY sfe_simple_stream_repo FETCH;
