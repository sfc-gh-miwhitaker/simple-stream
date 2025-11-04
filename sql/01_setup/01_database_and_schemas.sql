/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Database and Schema Setup
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Provision demo database and layer schemas.
 * OBJECTS: SNOWFLAKE_EXAMPLE, RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS RAW_INGESTION
    COMMENT = 'DEMO: sfe-simple-stream - Raw landing tables and PIPE objects';
CREATE SCHEMA IF NOT EXISTS STAGING_LAYER
    COMMENT = 'DEMO: sfe-simple-stream - Staging tables for cleaning and deduplication';
CREATE SCHEMA IF NOT EXISTS ANALYTICS_LAYER
    COMMENT = 'DEMO: sfe-simple-stream - Dimensional model for the demo';

USE SCHEMA RAW_INGESTION;
