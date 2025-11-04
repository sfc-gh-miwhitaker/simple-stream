/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Pipeline Validation
 * 
 * WARNING:  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Comprehensive validation queries to verify data flow through the entire
 *   streaming pipeline after event ingestion. Includes quick health checks
 *   and detailed analytics.
 * 
 * EXPECTED FLOW: RAW → STREAM → STG → DIM/FACT
 * 
 * SECTIONS:
 *   - Quick Checks: Simple row counts and task status (5 seconds)
 *   - Detailed Analysis: Full pipeline validation (30 seconds)
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File
 *   - Run first 3 queries for quick validation
 *   - Run all queries for comprehensive analysis
 * 
 * ESTIMATED TIME: 
 *   - Quick checks: 5 seconds
 *   - Full validation: 35 seconds
 ******************************************************************************/

-- ============================================================================
-- PREREQUISITE: Pipeline must be deployed
-- ============================================================================
-- This script assumes the pipeline is deployed and running

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- QUICK CHECKS (Run these first for rapid validation)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Quick Check 1: Row Counts Across All Layers
-- ----------------------------------------------------------------------------
SELECT 'RAW Layer' AS layer, COUNT(*) AS row_count 
FROM RAW_INGESTION.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING Layer' AS layer, COUNT(*) AS row_count 
FROM STAGING_LAYER.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS Layer' AS layer, COUNT(*) AS row_count 
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS;

-- ----------------------------------------------------------------------------
-- Quick Check 2: Stream Status
-- ----------------------------------------------------------------------------
SELECT 
    'Stream Has Data?' AS check_type,
    SYSTEM$STREAM_HAS_DATA('RAW_INGESTION.sfe_badge_events_stream') AS status,
    CASE 
        WHEN SYSTEM$STREAM_HAS_DATA('RAW_INGESTION.sfe_badge_events_stream') = 'true'
        THEN 'WARNING:  Data pending (tasks still processing)'
        ELSE ' Stream consumed (pipeline caught up)'
    END AS interpretation;

-- ----------------------------------------------------------------------------
-- Quick Check 3: Recent Task Execution Status
-- ----------------------------------------------------------------------------
SELECT 
    name AS task_name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF('second', scheduled_time, completed_time) AS duration_sec
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 5
))
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC;

-- ============================================================================
-- DETAILED VALIDATION (Run for comprehensive analysis)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CHECK 1: Raw Table Statistics
-- ----------------------------------------------------------------------------
SELECT 
    'RAW_BADGE_EVENTS' AS table_name, 
    COUNT(*) AS row_count,
    COUNT(DISTINCT badge_id) AS unique_badges,
    COUNT(DISTINCT zone_id) AS unique_zones,
    MIN(event_timestamp) AS earliest_event,
    MAX(event_timestamp) AS latest_event,
    MIN(ingestion_time) AS first_ingestion,
    MAX(ingestion_time) AS last_ingestion
FROM RAW_INGESTION.RAW_BADGE_EVENTS;

-- ----------------------------------------------------------------------------
-- CHECK 2: Stream Pending Records
-- ----------------------------------------------------------------------------
SELECT 'Stream Pending Records' AS check_type, COUNT(*) AS pending_count
FROM RAW_INGESTION.sfe_badge_events_stream;

-- ----------------------------------------------------------------------------
-- CHECK 3: Staging Table Statistics
-- ----------------------------------------------------------------------------
SELECT 
    'STG_BADGE_EVENTS' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT badge_id) AS unique_badges,
    MIN(event_timestamp) AS earliest_event,
    MAX(event_timestamp) AS latest_event
FROM STAGING_LAYER.STG_BADGE_EVENTS;

-- ----------------------------------------------------------------------------
-- CHECK 4: Dimension Tables - User Auto-Creation
-- ----------------------------------------------------------------------------
-- Initial seed was 5 users, check if new users were added
SELECT 
    'DIM_USERS' AS dimension_name,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN user_name = 'UNKNOWN' THEN 1 END) AS auto_created_users,
    COUNT(CASE WHEN user_name != 'UNKNOWN' THEN 1 END) AS seed_users
FROM ANALYTICS_LAYER.DIM_USERS
WHERE is_current = TRUE;

-- Sample of auto-created users
SELECT 
    'Sample Auto-Created Users' AS check_type,
    user_id, 
    user_name, 
    clearance_level,
    created_timestamp
FROM ANALYTICS_LAYER.DIM_USERS
WHERE user_name = 'UNKNOWN'
  AND is_current = TRUE
LIMIT 5;

-- ----------------------------------------------------------------------------
-- CHECK 5: Fact Table Statistics
-- ----------------------------------------------------------------------------
SELECT 
    'FCT_ACCESS_EVENTS' AS table_name,
    COUNT(*) AS total_events,
    COUNT(DISTINCT badge_id) AS unique_badges,
    COUNT(DISTINCT zone_key) AS unique_zones,
    MIN(event_date) AS earliest_date,
    MAX(event_date) AS latest_date,
    MIN(event_timestamp) AS earliest_timestamp,
    MAX(event_timestamp) AS latest_timestamp
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS;

-- ----------------------------------------------------------------------------
-- CHECK 6: Event Distribution by Date
-- ----------------------------------------------------------------------------
SELECT 
    event_date,
    COUNT(*) AS event_count,
    COUNT(DISTINCT badge_id) AS unique_badges,
    COUNT(DISTINCT zone_key) AS unique_zones
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
GROUP BY event_date
ORDER BY event_date DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- CHECK 7: Event Direction Distribution
-- ----------------------------------------------------------------------------
SELECT 
    direction,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
GROUP BY direction
ORDER BY event_count DESC;

-- ----------------------------------------------------------------------------
-- CHECK 8: Signal Quality Distribution
-- ----------------------------------------------------------------------------
SELECT 
    signal_quality,
    COUNT(*) AS event_count,
    ROUND(AVG(signal_strength), 2) AS avg_signal_strength,
    MIN(signal_strength) AS min_signal,
    MAX(signal_strength) AS max_signal
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
GROUP BY signal_quality
ORDER BY event_count DESC;

-- ----------------------------------------------------------------------------
-- CHECK 9: After-Hours, Weekend, and Restricted Access Events
-- ----------------------------------------------------------------------------
SELECT 
    'After-Hours Events' AS category,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS), 2) AS percentage
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
WHERE is_after_hours = TRUE

UNION ALL

SELECT 
    'Weekend Events' AS category,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS), 2) AS percentage
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
WHERE is_weekend = TRUE

UNION ALL

SELECT 
    'Restricted Access Events' AS category,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS), 2) AS percentage
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
WHERE is_restricted_access = TRUE;

-- ----------------------------------------------------------------------------
-- CHECK 10: Top 5 Most Active Zones
-- ----------------------------------------------------------------------------
SELECT 
    z.zone_name,
    z.zone_type,
    z.building_name,
    COUNT(*) AS access_count
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS f
JOIN ANALYTICS_LAYER.DIM_ZONES z ON f.zone_key = z.zone_key
GROUP BY z.zone_name, z.zone_type, z.building_name
ORDER BY access_count DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- CHECK 11: Top 5 Most Active Badges
-- ----------------------------------------------------------------------------
SELECT 
    f.badge_id,
    u.user_name,
    u.user_type,
    u.department,
    COUNT(*) AS access_count
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS f
JOIN ANALYTICS_LAYER.DIM_USERS u ON f.user_key = u.user_key
GROUP BY f.badge_id, u.user_name, u.user_type, u.department
ORDER BY access_count DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- CHECK 12: Data Completeness - NULL Check
-- ----------------------------------------------------------------------------
SELECT 
    'Completeness Check' AS check_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN badge_id IS NULL THEN 1 END) AS null_badge_id,
    COUNT(CASE WHEN user_key IS NULL THEN 1 END) AS null_user_key,
    COUNT(CASE WHEN zone_key IS NULL THEN 1 END) AS null_zone_key,
    COUNT(CASE WHEN event_timestamp IS NULL THEN 1 END) AS null_timestamp,
    COUNT(CASE WHEN direction IS NULL THEN 1 END) AS null_direction
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS;

-- ----------------------------------------------------------------------------
-- CHECK 13: Task Execution History (Last 2 Hours)
-- ----------------------------------------------------------------------------
SELECT 
    name AS task_name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF('second', scheduled_time, completed_time) AS duration_sec,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 20
))
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC;

-- ----------------------------------------------------------------------------
-- CHECK 14: Serverless Task Credit Usage
-- ----------------------------------------------------------------------------
SELECT 
    task_name,
    SUM(credits_used) AS total_credits,
    COUNT(*) AS execution_count,
    ROUND(AVG(credits_used), 4) AS avg_credits_per_run
FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
WHERE task_name LIKE 'sfe_%'
  AND start_time >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
GROUP BY task_name
ORDER BY total_credits DESC;

-- ----------------------------------------------------------------------------
-- CHECK 15: Ingestion Latency Analysis
-- ----------------------------------------------------------------------------
SELECT 
    'Ingestion Latency' AS metric,
    MIN(DATEDIFF('second', ingestion_time, fact_load_time)) AS min_latency_sec,
    MAX(DATEDIFF('second', ingestion_time, fact_load_time)) AS max_latency_sec,
    AVG(DATEDIFF('second', ingestion_time, fact_load_time)) AS avg_latency_sec,
    MEDIAN(DATEDIFF('second', ingestion_time, fact_load_time)) AS median_latency_sec
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
WHERE fact_load_time IS NOT NULL;

-- ----------------------------------------------------------------------------
-- CHECK 16: Pipeline Row Count Summary
-- ----------------------------------------------------------------------------
SELECT 'Pipeline Row Count Summary' AS summary;

SELECT 
    'RAW_BADGE_EVENTS' AS layer,
    COUNT(*) AS row_count
FROM RAW_INGESTION.RAW_BADGE_EVENTS

UNION ALL

SELECT 
    'STG_BADGE_EVENTS' AS layer,
    COUNT(*) AS row_count
FROM STAGING_LAYER.STG_BADGE_EVENTS

UNION ALL

SELECT 
    'FCT_ACCESS_EVENTS' AS layer,
    COUNT(*) AS row_count
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS

ORDER BY row_count DESC;

-- ============================================================================
-- EXPECTED RESULTS SUMMARY
-- ============================================================================
-- 
--  HEALTHY PIPELINE:
--   - RAW count ≈ STAGING count ≈ FACT count (after deduplication)
--   - Stream status: FALSE (all data consumed)
--   - Task state: SUCCEEDED
--   - Latency: < 120 seconds (given 1-minute task schedule)
--   - No NULL values in required fields
-- 
-- WARNING:  TROUBLESHOOTING:
--   - Stream has data (TRUE): Tasks still processing, wait 1-2 minutes
--   - STAGING < RAW: Tasks haven't finished, check task history
--   - FACT < STAGING: Missing dimension keys, check dimension tables
--   - Task state: FAILED: Check error_message in task history
-- 
-- 💡 NEXT STEPS:
--   - Monitor task execution: Run quick checks periodically
--   - View real-time metrics: sql/03_monitoring/monitoring_views.sql
--   - Check data quality: sql/04_data_quality/dq_checks.sql
-- ============================================================================

