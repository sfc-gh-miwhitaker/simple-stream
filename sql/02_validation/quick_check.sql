-- ============================================================================
-- Quick Pipeline Validation - Simple Row Count Check
-- ============================================================================
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Row counts across all layers
SELECT 'RAW Layer' AS layer, COUNT(*) AS row_count 
FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING Layer' AS layer, COUNT(*) AS row_count 
FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS Layer' AS layer, COUNT(*) AS row_count 
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;

-- Stream status
SELECT 
    'Stream Has Data?' AS check_type,
    SYSTEM$STREAM_HAS_DATA('STAGE_BADGE_TRACKING.raw_badge_events_stream') AS status;

-- Recent task runs
SELECT 
    name,
    state,
    scheduled_time,
    completed_time
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 5
))
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC;

