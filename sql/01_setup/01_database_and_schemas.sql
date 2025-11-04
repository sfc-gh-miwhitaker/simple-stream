/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Database and Schema Setup
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create foundational database and schemas for RFID badge tracking demo.
 *   Demonstrates layered architecture pattern (Raw → Staging → Analytics).
 * 
 * OBJECTS CREATED:
 *   - SNOWFLAKE_EXAMPLE (Database) - Demo artifacts container
 *   - RAW_INGESTION (Schema) - Raw landing tables and PIPE objects
 *   - STAGING_LAYER (Schema) - Cleaning and transformation layer
 *   - ANALYTICS_LAYER (Schema) - Dimensional model (dims and facts)
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

-- Create the database (reserved for demo/example projects)
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Create schema for raw ingestion (landing zone)
-- Domain-specific name (badge events) doesn't need SFE_ prefix
CREATE SCHEMA IF NOT EXISTS RAW_INGESTION
    COMMENT = 'DEMO: sfe-simple-stream - Raw landing tables and PIPE objects for badge event ingestion';

-- Create schema for staging/transformation layer
CREATE SCHEMA IF NOT EXISTS STAGING_LAYER
    COMMENT = 'DEMO: sfe-simple-stream - Staging tables for cleaning, deduplication, and transformation';

-- Create schema for analytics layer
CREATE SCHEMA IF NOT EXISTS ANALYTICS_LAYER
    COMMENT = 'DEMO: sfe-simple-stream - Dimensional model: dimensions (Type 2 SCD) and fact tables';

-- Verify schema creation
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Set context for subsequent scripts
USE SCHEMA RAW_INGESTION;
