-- ============================================================================
-- RFID Badge Tracking: Monitoring Views
-- ============================================================================
-- Purpose: Create comprehensive monitoring views for tracking ingestion
--          health, performance, and data quality across the pipeline.
--
-- Views:
--   1. V_CHANNEL_STATUS: Real-time channel health
--   2. V_INGESTION_METRICS: Throughput and volume metrics
--   3. V_END_TO_END_LATENCY: Pipeline latency tracking
--   4. V_DATA_FRESHNESS: Last event timestamps
--   5. V_PARTITION_EFFICIENCY: Query performance metrics
--   6. V_STREAMING_COSTS: Cost tracking
--   7. V_TASK_EXECUTION_HISTORY: Task performance
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- ============================================================================
-- View 1: Channel Status
-- ============================================================================

CREATE OR REPLACE VIEW V_CHANNEL_STATUS AS
SELECT 
    channel_name,
    pipe_name,
    MAX(server_timestamp) AS last_ingestion_time,
    DATEDIFF('second', MAX(server_timestamp), CURRENT_TIMESTAMP()) AS seconds_since_last_ingestion,
    SUM(rows_inserted) AS total_rows_inserted,
    SUM(bytes_inserted) / POWER(1024, 3) AS total_gb_inserted,
    COUNT(DISTINCT DATE_TRUNC('minute', server_timestamp)) AS active_minutes_last_hour,
    AVG(rows_inserted) AS avg_rows_per_insert,
    MAX(rows_inserted) AS max_rows_per_insert
FROM TABLE(
    SNOWFLAKE.INFORMATION_SCHEMA.CHANNEL_HISTORY(
        PIPE_NAME => 'SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.BADGE_EVENTS_PIPE',
        TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
)
GROUP BY channel_name, pipe_name
COMMENT = 'Real-time Snowpipe Streaming channel health and status';

-- ============================================================================
-- View 2: Ingestion Metrics
-- ============================================================================

CREATE OR REPLACE VIEW V_INGESTION_METRICS AS
WITH hourly_stats AS (
    SELECT 
        DATE_TRUNC('hour', ingestion_time) AS ingestion_hour,
        COUNT(*) AS event_count,
        COUNT(DISTINCT badge_id) AS unique_badges,
        COUNT(DISTINCT zone_id) AS unique_zones,
        AVG(signal_strength) AS avg_signal_strength,
        SUM(CASE WHEN signal_quality = 'WEAK' THEN 1 ELSE 0 END) AS weak_signal_count,
        SUM(CASE WHEN direction = 'ENTRY' THEN 1 ELSE 0 END) AS entry_count,
        SUM(CASE WHEN direction = 'EXIT' THEN 1 ELSE 0 END) AS exit_count
    FROM RAW_BADGE_EVENTS
    WHERE ingestion_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    GROUP BY DATE_TRUNC('hour', ingestion_time)
)
SELECT 
    ingestion_hour,
    event_count,
    event_count / 3600.0 AS events_per_second,
    unique_badges,
    unique_zones,
    ROUND(avg_signal_strength, 2) AS avg_signal_strength,
    weak_signal_count,
    ROUND(100.0 * weak_signal_count / NULLIF(event_count, 0), 2) AS weak_signal_pct,
    entry_count,
    exit_count,
    entry_count - exit_count AS net_occupancy_change
FROM hourly_stats
ORDER BY ingestion_hour DESC
COMMENT = 'Hourly ingestion metrics for the last 24 hours';

-- ============================================================================
-- View 3: End-to-End Latency
-- ============================================================================

CREATE OR REPLACE VIEW V_END_TO_END_LATENCY AS
WITH latest_events AS (
    SELECT 
        'RAW' AS layer,
        MAX(ingestion_time) AS last_update,
        COUNT(*) AS row_count
    FROM RAW_BADGE_EVENTS
    WHERE ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    
    UNION ALL
    
    SELECT 
        'STAGING' AS layer,
        MAX(staging_time) AS last_update,
        COUNT(*) AS row_count
    FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
    WHERE staging_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    
    UNION ALL
    
    SELECT 
        'ANALYTICS' AS layer,
        MAX(fact_load_time) AS last_update,
        COUNT(*) AS row_count
    FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
    WHERE fact_load_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
)
SELECT 
    layer,
    last_update,
    DATEDIFF('second', last_update, CURRENT_TIMESTAMP()) AS seconds_since_update,
    row_count,
    CASE 
        WHEN DATEDIFF('second', last_update, CURRENT_TIMESTAMP()) > 300 THEN 'STALE'
        WHEN DATEDIFF('second', last_update, CURRENT_TIMESTAMP()) > 120 THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS health_status
FROM latest_events
ORDER BY 
    CASE layer
        WHEN 'RAW' THEN 1
        WHEN 'STAGING' THEN 2
        WHEN 'ANALYTICS' THEN 3
    END
COMMENT = 'End-to-end pipeline latency and health status';

-- ============================================================================
-- View 4: Data Freshness
-- ============================================================================

CREATE OR REPLACE VIEW V_DATA_FRESHNESS AS
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    MAX(event_timestamp) AS last_event_timestamp,
    MAX(ingestion_time) AS last_ingestion_timestamp,
    DATEDIFF('second', MAX(event_timestamp), CURRENT_TIMESTAMP()) AS event_age_seconds,
    DATEDIFF('second', MAX(ingestion_time), CURRENT_TIMESTAMP()) AS ingestion_age_seconds,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())) AS rows_last_hour
FROM RAW_BADGE_EVENTS

UNION ALL

SELECT 
    'FCT_ACCESS_EVENTS' AS table_name,
    MAX(event_timestamp) AS last_event_timestamp,
    MAX(fact_load_time) AS last_ingestion_timestamp,
    DATEDIFF('second', MAX(event_timestamp), CURRENT_TIMESTAMP()) AS event_age_seconds,
    DATEDIFF('second', MAX(fact_load_time), CURRENT_TIMESTAMP()) AS ingestion_age_seconds,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE fact_load_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())) AS rows_last_hour
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
COMMENT = 'Data freshness metrics across all layers';

-- ============================================================================
-- View 5: Partition Efficiency
-- ============================================================================

CREATE OR REPLACE VIEW V_PARTITION_EFFICIENCY AS
WITH table_scan_stats AS (
    SELECT 
        table_name,
        query_id,
        partitions_scanned,
        partitions_total,
        ROUND(100.0 * partitions_scanned / NULLIF(partitions_total, 0), 2) AS scan_ratio_pct,
        bytes_scanned / POWER(1024, 3) AS gb_scanned
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE table_name IN ('RAW_BADGE_EVENTS', 'FCT_ACCESS_EVENTS')
        AND start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
        AND partitions_total > 0
)
SELECT 
    table_name,
    COUNT(*) AS query_count,
    ROUND(AVG(scan_ratio_pct), 2) AS avg_scan_ratio_pct,
    ROUND(MIN(scan_ratio_pct), 2) AS best_scan_ratio_pct,
    ROUND(MAX(scan_ratio_pct), 2) AS worst_scan_ratio_pct,
    ROUND(AVG(gb_scanned), 2) AS avg_gb_scanned,
    CASE 
        WHEN AVG(scan_ratio_pct) < 20 THEN 'EXCELLENT'
        WHEN AVG(scan_ratio_pct) < 50 THEN 'GOOD'
        WHEN AVG(scan_ratio_pct) < 80 THEN 'FAIR'
        ELSE 'POOR'
    END AS pruning_efficiency
FROM table_scan_stats
GROUP BY table_name
COMMENT = 'Query pruning efficiency - lower scan ratio is better';

-- ============================================================================
-- View 6: Streaming Costs (Throughput-Based Pricing)
-- ============================================================================

CREATE OR REPLACE VIEW V_STREAMING_COSTS AS
WITH daily_throughput AS (
    SELECT 
        DATE(server_timestamp) AS ingestion_date,
        SUM(bytes_inserted) / POWER(1024, 3) AS gb_ingested_uncompressed,
        SUM(rows_inserted) AS rows_ingested
    FROM TABLE(
        SNOWFLAKE.INFORMATION_SCHEMA.CHANNEL_HISTORY(
            PIPE_NAME => 'SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.BADGE_EVENTS_PIPE',
            TIME_RANGE_START => DATEADD('day', -30, CURRENT_TIMESTAMP())
        )
    )
    GROUP BY DATE(server_timestamp)
)
SELECT 
    ingestion_date,
    gb_ingested_uncompressed,
    rows_ingested,
    gb_ingested_uncompressed * 0.01 AS estimated_credits_snowpipe_streaming,
    ROUND(rows_ingested / NULLIF(gb_ingested_uncompressed, 0), 0) AS rows_per_gb
FROM daily_throughput
ORDER BY ingestion_date DESC
COMMENT = 'Snowpipe Streaming cost tracking (est. $0.01 per GB uncompressed)';

-- ============================================================================
-- View 7: Task Execution History
-- ============================================================================

CREATE OR REPLACE VIEW V_TASK_EXECUTION_HISTORY AS
SELECT 
    name AS task_name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF('second', scheduled_time, completed_time) AS duration_seconds,
    error_code,
    error_message,
    CASE 
        WHEN state = 'SUCCEEDED' THEN 'SUCCESS'
        WHEN state = 'FAILED' THEN 'FAILED'
        WHEN state = 'SKIPPED' THEN 'SKIPPED'
        ELSE 'UNKNOWN'
    END AS execution_status
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
        RESULT_LIMIT => 1000
    )
)
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC
COMMENT = 'Task execution history for the last 24 hours';

-- ============================================================================
-- Verify view creation
-- ============================================================================

SHOW VIEWS IN SCHEMA STAGE_BADGE_TRACKING;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================
-- 
-- Check overall system health:
--   SELECT * FROM V_END_TO_END_LATENCY;
-- 
-- Monitor real-time ingestion:
--   SELECT * FROM V_CHANNEL_STATUS;
-- 
-- Review hourly ingestion patterns:
--   SELECT * FROM V_INGESTION_METRICS LIMIT 24;
-- 
-- Check data freshness:
--   SELECT * FROM V_DATA_FRESHNESS;
-- 
-- Verify query performance:
--   SELECT * FROM V_PARTITION_EFFICIENCY;
-- 
-- Track costs:
--   SELECT SUM(estimated_credits_snowpipe_streaming) AS total_credits_last_30_days
--   FROM V_STREAMING_COSTS;
-- 
-- Review task performance:
--   SELECT task_name, COUNT(*) AS executions, AVG(duration_seconds) AS avg_duration
--   FROM V_TASK_EXECUTION_HISTORY
--   WHERE execution_status = 'SUCCESS'
--   GROUP BY task_name;
-- ============================================================================

