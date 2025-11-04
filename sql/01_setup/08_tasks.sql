/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Tasks for CDC-based Transformation Pipeline
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create scheduled tasks that process badge events through the pipeline using
 *   stream-based CDC triggers. Demonstrates event-driven ETL pattern.
 * 
 * OBJECTS CREATED:
 *   - sfe_raw_to_staging_task (Serverless Task) - RAW → STAGING with deduplication
 *   - sfe_process_badge_events (Procedure) - Analytics layer processing
 *   - sfe_staging_to_analytics_task (Serverless Task) - STAGING → ANALYTICS
 * 
 * TASK CHAIN:
 *   1. sfe_raw_to_staging_task: RAW → STG (deduplication with QUALIFY)
 *   2. sfe_staging_to_analytics_task: STG → ANALYTICS (MERGE, SCD updates)
 * 
 * KEY FEATURES:
 *   - Serverless compute (no warehouse management needed)
 *   - Event-driven execution (SYSTEM$STREAM_HAS_DATA)
 *   - 1-minute schedule for near-real-time processing
 *   - QUALIFY for efficient deduplication
 *   - Type 2 SCD maintenance
 *   - Automatic scaling and cost optimization
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * Task 1: Raw to Staging (Deduplication) - SERVERLESS
 * 
 * Uses Snowflake-managed serverless compute (no warehouse needed)
 * Reads from sfe_badge_events_stream and deduplicates using QUALIFY
 * 
 * SERVERLESS BENEFITS:
 *   - No warehouse sizing decisions
 *   - Automatic scaling based on workload
 *   - Pay only for actual compute used
 *   - Snowflake optimizes compute size from task history
 ******************************************************************************/

USE SCHEMA RAW_INGESTION;

CREATE OR REPLACE TASK sfe_raw_to_staging_task
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'  -- Initial size hint for first runs
    SCHEDULE = '1 MINUTE'
    COMMENT = 'DEMO: sfe-simple-stream - Serverless task: RAW → STAGING with deduplication'
WHEN
    SYSTEM$STREAM_HAS_DATA('sfe_badge_events_stream')
AS
    INSERT INTO SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS (
        badge_id,
        user_id,
        zone_id,
        reader_id,
        event_timestamp,
        signal_strength,
        signal_quality,
        direction,
        ingestion_time
    )
    SELECT 
        badge_id,
        user_id,
        zone_id,
        reader_id,
        event_timestamp,
        signal_strength,
        signal_quality,
        direction,
        ingestion_time
    FROM sfe_badge_events_stream
    WHERE METADATA$ACTION = 'INSERT'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY badge_id, event_timestamp 
        ORDER BY ingestion_time DESC
    ) = 1;

/*******************************************************************************
 * Stored Procedure: Process Badge Events to Analytics
 * 
 * Encapsulates multi-step processing for reuse in tasks.
 * SFE_ prefix prevents collision with production procedures.
 ******************************************************************************/

USE SCHEMA STAGING_LAYER;

CREATE OR REPLACE PROCEDURE sfe_process_badge_events()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
COMMENT = 'DEMO: sfe-simple-stream - Process staging data into analytics layer (dimensions + facts)'
AS
$$
BEGIN
    -- ========================================================================
    -- Step 1: Update DIM_USERS if new users appear (simplified - no SCD for now)
    -- ========================================================================
    MERGE INTO SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS d
    USING (
        SELECT DISTINCT 
            user_id,
            'UNKNOWN' AS user_name,
            'UNKNOWN' AS user_type,
            'UNKNOWN' AS department,
            'PUBLIC' AS clearance_level
        FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS
        WHERE user_id NOT IN (
            SELECT user_id FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS
            WHERE is_current = TRUE
        )
    ) s
    ON d.user_id = s.user_id AND d.is_current = TRUE
    WHEN NOT MATCHED THEN
        INSERT (
            user_id, user_name, user_type, department, clearance_level,
            is_active, is_current, effective_start_date
        )
        VALUES (
            s.user_id, s.user_name, s.user_type, s.department, s.clearance_level,
            TRUE, TRUE, CURRENT_TIMESTAMP()
        );

    -- ========================================================================
    -- Step 2: Insert into Fact Table
    -- ========================================================================
    INSERT INTO SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS (
        user_key,
        zone_key,
        badge_id,
        reader_id,
        event_timestamp,
        event_date,
        event_hour,
        event_day_of_week,
        direction,
        signal_strength,
        signal_quality,
        is_restricted_access,
        is_after_hours,
        is_weekend,
        ingestion_time
    )
    SELECT 
        u.user_key,
        z.zone_key,
        s.badge_id,
        s.reader_id,
        s.event_timestamp,
        DATE(s.event_timestamp) AS event_date,
        HOUR(s.event_timestamp) AS event_hour,
        DAYOFWEEK(s.event_timestamp) AS event_day_of_week,
        s.direction,
        s.signal_strength,
        s.signal_quality,
        z.is_restricted AS is_restricted_access,
        CASE 
            WHEN HOUR(s.event_timestamp) < 6 OR HOUR(s.event_timestamp) >= 22 
            THEN TRUE 
            ELSE FALSE 
        END AS is_after_hours,
        CASE 
            WHEN DAYOFWEEK(s.event_timestamp) IN (0, 6) 
            THEN TRUE 
            ELSE FALSE 
        END AS is_weekend,
        s.ingestion_time
    FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS s
    INNER JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS u
        ON s.user_id = u.user_id AND u.is_current = TRUE
    INNER JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_ZONES z
        ON s.zone_id = z.zone_id
    LEFT JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS f
        ON s.badge_id = f.badge_id 
        AND s.event_timestamp = f.event_timestamp
    WHERE f.event_key IS NULL;  -- Prevent duplicates

    RETURN 'PROCESS_BADGE_EVENTS_COMPLETED';
END;
$$;

/*******************************************************************************
 * Task 2: Staging to Analytics (Dimension and Fact Updates) - SERVERLESS
 * 
 * Runs after sfe_raw_to_staging_task completes
 * Uses serverless compute for automatic scaling
 ******************************************************************************/

CREATE OR REPLACE TASK sfe_staging_to_analytics_task
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'  -- Initial size hint for first runs
    AFTER sfe_raw_to_staging_task
    COMMENT = 'DEMO: sfe-simple-stream - Serverless task: STAGING → ANALYTICS'
AS
    CALL sfe_process_badge_events();

/*******************************************************************************
 * Resume Tasks to Activate Them
 * 
 * Resume in reverse dependency order (child first, parent second)
 ******************************************************************************/

ALTER TASK sfe_staging_to_analytics_task RESUME;
ALTER TASK SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_raw_to_staging_task RESUME;

-- Verify task configuration
SHOW TASKS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * TASK MONITORING
 * 
 * Check task status:
 *   SHOW TASKS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;
 * 
 * View task execution history:
 *   SELECT *
 *   FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
 *       SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
 *       RESULT_LIMIT => 100
 *   ))
 *   WHERE NAME LIKE 'sfe_%'
 *   ORDER BY SCHEDULED_TIME DESC;
 * 
 * Check specific task runs:
 *   SELECT 
 *       name,
 *       state,
 *       scheduled_time,
 *       completed_time,
 *       DATEDIFF('second', scheduled_time, completed_time) AS duration_sec,
 *       error_code,
 *       error_message
 *   FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
 *   WHERE name = 'sfe_raw_to_staging_task'
 *   ORDER BY scheduled_time DESC
 *   LIMIT 10;
 * 
 * Suspend tasks (for maintenance):
 *   ALTER TASK sfe_raw_to_staging_task SUSPEND;
 *   ALTER TASK sfe_staging_to_analytics_task SUSPEND;
 * 
 * Resume tasks:
 *   ALTER TASK sfe_staging_to_analytics_task RESUME;
 *   ALTER TASK sfe_raw_to_staging_task RESUME;
 ******************************************************************************/

/*******************************************************************************
 * PERFORMANCE TUNING (SERVERLESS TASKS)
 * 
 * Serverless tasks automatically scale, but you can optimize:
 * 
 * 1. Snowflake learns optimal size from task history
 *    - First runs use USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE
 *    - Subsequent runs are auto-optimized based on actual workload
 * 
 * 2. Adjust initial size hint if needed:
 *    ALTER TASK sfe_raw_to_staging_task SET 
 *      USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'SMALL';
 * 
 * 3. Consider batch processing (reduce frequency):
 *    ALTER TASK sfe_raw_to_staging_task SET SCHEDULE = '5 MINUTE';
 * 
 * 4. Monitor serverless task costs:
 *    SELECT 
 *      task_name,
 *      SUM(credits_used) as total_credits,
 *      COUNT(*) as execution_count,
 *      AVG(credits_used) as avg_credits_per_run
 *    FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
 *    WHERE task_name LIKE 'sfe_%'
 *    GROUP BY task_name
 *    ORDER BY total_credits DESC;
 * 
 * WHY SERVERLESS?
 *   ✅ No warehouse sizing decisions
 *   ✅ Automatic scaling based on workload
 *   ✅ Pay only for actual execution time
 *   ✅ Snowflake optimizes compute from task history
 *   ✅ No idle warehouse costs
 ******************************************************************************/
