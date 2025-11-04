/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Quick Pipeline Validation
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Simple row count check across all layers to quickly verify data flow.
 *   Use this for rapid health checks during development/testing.
 * 
 * USAGE:
 *   Execute in Snowsight Workspaces (Projects → Workspaces → + SQL File)
 * 
 * ESTIMATED TIME: 5 seconds
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Row counts across all layers
SELECT 'RAW Layer' AS layer, COUNT(*) AS row_count 
FROM RAW_INGESTION.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING Layer' AS layer, COUNT(*) AS row_count 
FROM STAGING_LAYER.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS Layer' AS layer, COUNT(*) AS row_count 
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS;

-- Stream status
SELECT 
    'Stream Has Data?' AS check_type,
    SYSTEM$STREAM_HAS_DATA('RAW_INGESTION.sfe_badge_events_stream') AS status;

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
