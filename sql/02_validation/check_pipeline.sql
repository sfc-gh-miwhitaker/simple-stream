-- ============================================================================
-- RFID Badge Tracking: Pipeline Validation Checks
-- ============================================================================
-- Purpose: Comprehensive validation queries to verify data flow through
--          the entire streaming pipeline after batch ingestion.
--
-- Expected Flow: RAW → STREAM → STG → DIM/FACT
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- CHECK 1: Raw Table Row Count
-- ============================================================================
SELECT 'RAW_BADGE_EVENTS' AS table_name, COUNT(*) AS row_count 
FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS;

-- ============================================================================
-- CHECK 2: Stream Status (Should have data if tasks haven't processed yet)
-- ============================================================================
SELECT 
    'raw_badge_events_stream' AS stream_name,
    SYSTEM$STREAM_HAS_DATA('STAGE_BADGE_TRACKING.raw_badge_events_stream') AS has_data;

-- Query the stream to see pending records
SELECT 'Stream Pending Records' AS check_type, COUNT(*) AS pending_count
FROM STAGE_BADGE_TRACKING.raw_badge_events_stream;

-- ============================================================================
-- CHECK 3: Staging Table Row Count
-- ============================================================================
SELECT 'STG_BADGE_EVENTS' AS table_name, COUNT(*) AS row_count 
FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS;

-- ============================================================================
-- CHECK 4: Dimension Tables - Check for new users
-- ============================================================================
-- Initial seed was 5 users, check if new users were added
SELECT 
    'DIM_USERS' AS dimension_name,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN user_name = 'UNKNOWN' THEN 1 END) AS auto_created_users,
    COUNT(CASE WHEN user_name != 'UNKNOWN' THEN 1 END) AS seed_users
FROM ANALYTICS_BADGE_TRACKING.DIM_USERS
WHERE is_current = TRUE;

-- Show sample of auto-created users
SELECT 
    'Sample Auto-Created Users' AS check_type,
    user_id, 
    user_name, 
    clearance_level,
    created_timestamp
FROM ANALYTICS_BADGE_TRACKING.DIM_USERS
WHERE user_name = 'UNKNOWN'
  AND is_current = TRUE
LIMIT 5;

-- ============================================================================
-- CHECK 5: Fact Table Row Count and Date Range
-- ============================================================================
SELECT 
    'FCT_ACCESS_EVENTS' AS table_name,
    COUNT(*) AS total_events,
    MIN(event_date) AS earliest_date,
    MAX(event_date) AS latest_date,
    MIN(event_timestamp) AS earliest_timestamp,
    MAX(event_timestamp) AS latest_timestamp
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;

-- ============================================================================
-- CHECK 6: Event Distribution by Date
-- ============================================================================
SELECT 
    event_date,
    COUNT(*) AS event_count,
    COUNT(DISTINCT badge_id) AS unique_badges,
    COUNT(DISTINCT zone_key) AS unique_zones
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
GROUP BY event_date
ORDER BY event_date DESC
LIMIT 10;

-- ============================================================================
-- CHECK 7: Event Direction Distribution
-- ============================================================================
SELECT 
    direction,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
GROUP BY direction
ORDER BY event_count DESC;

-- ============================================================================
-- CHECK 8: Signal Quality Distribution
-- ============================================================================
SELECT 
    signal_quality,
    COUNT(*) AS event_count,
    ROUND(AVG(signal_strength), 2) AS avg_signal_strength
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
GROUP BY signal_quality
ORDER BY event_count DESC;

-- ============================================================================
-- CHECK 9: After-Hours and Weekend Events
-- ============================================================================
SELECT 
    'After-Hours Events' AS category,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS), 2) AS percentage
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
WHERE is_after_hours = TRUE

UNION ALL

SELECT 
    'Weekend Events' AS category,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS), 2) AS percentage
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
WHERE is_weekend = TRUE

UNION ALL

SELECT 
    'Restricted Access Events' AS category,
    COUNT(*) AS event_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS), 2) AS percentage
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
WHERE is_restricted_access = TRUE;

-- ============================================================================
-- CHECK 10: Top 5 Most Active Zones
-- ============================================================================
SELECT 
    z.zone_name,
    z.zone_type,
    COUNT(*) AS access_count
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS f
JOIN ANALYTICS_BADGE_TRACKING.DIM_ZONES z ON f.zone_key = z.zone_key
GROUP BY z.zone_name, z.zone_type
ORDER BY access_count DESC
LIMIT 5;

-- ============================================================================
-- CHECK 11: Top 5 Most Active Badges
-- ============================================================================
SELECT 
    f.badge_id,
    u.user_name,
    u.user_type,
    COUNT(*) AS access_count
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS f
JOIN ANALYTICS_BADGE_TRACKING.DIM_USERS u ON f.user_key = u.user_key
GROUP BY f.badge_id, u.user_name, u.user_type
ORDER BY access_count DESC
LIMIT 5;

-- ============================================================================
-- CHECK 12: Data Completeness - Check for NULLs
-- ============================================================================
SELECT 
    'Completeness Check' AS check_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN badge_id IS NULL THEN 1 END) AS null_badge_id,
    COUNT(CASE WHEN user_key IS NULL THEN 1 END) AS null_user_key,
    COUNT(CASE WHEN zone_key IS NULL THEN 1 END) AS null_zone_key,
    COUNT(CASE WHEN event_timestamp IS NULL THEN 1 END) AS null_timestamp,
    COUNT(CASE WHEN direction IS NULL THEN 1 END) AS null_direction
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;

-- ============================================================================
-- CHECK 13: Task Execution History
-- ============================================================================
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

-- ============================================================================
-- CHECK 14: Warehouse Credit Usage for Tasks
-- ============================================================================
SELECT 
    warehouse_name,
    SUM(credits_used) AS total_credits,
    COUNT(*) AS execution_count,
    ROUND(AVG(credits_used), 4) AS avg_credits_per_run
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'ETL_WH'
  AND start_time >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
GROUP BY warehouse_name;

-- ============================================================================
-- CHECK 15: Compare Row Counts Across All Layers
-- ============================================================================
SELECT 'Pipeline Row Count Summary' AS summary;

SELECT 
    'RAW_BADGE_EVENTS' AS layer,
    COUNT(*) AS row_count
FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS

UNION ALL

SELECT 
    'STG_BADGE_EVENTS' AS layer,
    COUNT(*) AS row_count
FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS

UNION ALL

SELECT 
    'FCT_ACCESS_EVENTS' AS layer,
    COUNT(*) AS row_count
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS

ORDER BY row_count DESC;

-- ============================================================================
-- CHECK 16: Ingestion Latency Analysis
-- ============================================================================
SELECT 
    'Ingestion Latency' AS metric,
    MIN(DATEDIFF('second', ingestion_time, fact_load_time)) AS min_latency_sec,
    MAX(DATEDIFF('second', ingestion_time, fact_load_time)) AS max_latency_sec,
    AVG(DATEDIFF('second', ingestion_time, fact_load_time)) AS avg_latency_sec,
    MEDIAN(DATEDIFF('second', ingestion_time, fact_load_time)) AS median_latency_sec
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
WHERE fact_load_time IS NOT NULL;

-- ============================================================================
-- SUMMARY: Expected Results for 3000 Rows
-- ============================================================================
-- 
-- If all 3000 rows processed successfully:
--   - RAW_BADGE_EVENTS: 3000+ rows
--   - Stream: Should be empty (False) if tasks processed all data
--   - STG_BADGE_EVENTS: 3000+ rows (may have more if duplicates were removed)
--   - FCT_ACCESS_EVENTS: Should match STG count after deduplication
--   - DIM_USERS: 5 seed users + any new users found in the data
--   - Task History: Should show successful executions
--   - Latency: Should be < 120 seconds (given 1-minute task schedule)
-- 
-- Troubleshooting:
--   - If stream has data: Tasks may still be processing
--   - If STG count < RAW count: Tasks haven't finished processing
--   - If FACT count < STG count: Check for missing dimension keys
-- ============================================================================

