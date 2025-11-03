-- ============================================================================
-- RFID Badge Tracking: Database and Schema Setup
-- ============================================================================
-- Purpose: Create the foundational database and schemas for the RFID badge
--          tracking streaming ingestion system.
-- 
-- Database: SNOWFLAKE_EXAMPLE
-- Schemas:
--   - STAGE_BADGE_TRACKING: Raw landing tables and PIPE objects
--   - TRANSFORM_BADGE_TRACKING: Staging and intermediate transformation
--   - ANALYTICS_BADGE_TRACKING: Dimensional model (dims and facts)
-- ============================================================================

-- Create the database
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'RFID Badge Tracking Streaming Ingestion Example';

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Create schema for raw staging (landing zone)
CREATE SCHEMA IF NOT EXISTS STAGE_BADGE_TRACKING
    COMMENT = 'Raw landing tables and PIPE objects for badge event ingestion';

-- Create schema for transformation layer
CREATE SCHEMA IF NOT EXISTS TRANSFORM_BADGE_TRACKING
    COMMENT = 'Staging tables for cleaning, deduplication, and transformation';

-- Create schema for analytics layer
CREATE SCHEMA IF NOT EXISTS ANALYTICS_BADGE_TRACKING
    COMMENT = 'Dimensional model: dimensions (Type 2 SCD) and fact tables';

-- Verify schema creation
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Set context for subsequent scripts
USE SCHEMA STAGE_BADGE_TRACKING;

