-- ============================================================================
-- RFID Badge Tracking: Tasks for CDC-based Transformation Pipeline
-- ============================================================================
-- Purpose: Create scheduled tasks that process badge events through the
--          pipeline using stream-based CDC triggers.
--
-- Task Chain:
--   1. raw_to_staging_task: RAW → STG (deduplication with QUALIFY)
--   2. staging_to_analytics_task: STG → ANALYTICS (MERGE, SCD updates)
--
-- Key Features:
--   - Event-driven execution (SYSTEM$STREAM_HAS_DATA)
--   - 1-minute schedule for near-real-time processing
--   - QUALIFY for efficient deduplication
--   - Type 2 SCD maintenance
--   - Automatic warehouse management
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- Create warehouse for task execution (if not exists)
-- ============================================================================

CREATE WAREHOUSE IF NOT EXISTS etl_wh
WITH WAREHOUSE_SIZE = 'XSMALL'
     AUTO_SUSPEND = 60  -- Suspend after 1 minute of inactivity
     AUTO_RESUME = TRUE
     INITIALLY_SUSPENDED = TRUE;

COMMENT ON WAREHOUSE etl_wh IS 'Warehouse for ETL task execution';

-- ============================================================================
-- Task 1: Raw to Staging (Deduplication)
-- ============================================================================

USE SCHEMA STAGE_BADGE_TRACKING;

CREATE OR REPLACE TASK raw_to_staging_task
    WAREHOUSE = etl_wh
    SCHEDULE = '1 MINUTE'
WHEN
    SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream')
AS
    INSERT INTO SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS (
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
    FROM raw_badge_events_stream
    WHERE METADATA$ACTION = 'INSERT'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY badge_id, event_timestamp 
        ORDER BY ingestion_time DESC
    ) = 1;

-- ============================================================================
-- Task 2: Staging to Analytics (Dimension and Fact Updates)
-- ============================================================================
-- Note: Must be in same schema as predecessor task (STAGE_BADGE_TRACKING)

USE SCHEMA STAGE_BADGE_TRACKING;

-- Stored procedure encapsulating multi-step processing for reuse in tasks
CREATE OR REPLACE PROCEDURE process_badge_events()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    -- ========================================================================
    -- Step 1: Update DIM_USERS if new users appear (simplified - no SCD for now)
    -- ========================================================================
    MERGE INTO SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS d
    USING (
        SELECT DISTINCT 
            user_id,
            'UNKNOWN' AS user_name,
            'UNKNOWN' AS user_type,
            'UNKNOWN' AS department,
            'PUBLIC' AS clearance_level
        FROM STG_BADGE_EVENTS
        WHERE user_id NOT IN (
            SELECT user_id FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS
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
    INSERT INTO SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS (
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
    FROM STG_BADGE_EVENTS s
    INNER JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS u
        ON s.user_id = u.user_id AND u.is_current = TRUE
    INNER JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_ZONES z
        ON s.zone_id = z.zone_id
    LEFT JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS f
        ON s.badge_id = f.badge_id 
        AND s.event_timestamp = f.event_timestamp
    WHERE f.event_key IS NULL;  -- Prevent duplicates

    RETURN 'PROCESS_BADGE_EVENTS_COMPLETED';
END;
$$;

CREATE OR REPLACE TASK staging_to_analytics_task
    WAREHOUSE = etl_wh
    AFTER raw_to_staging_task
AS
    CALL process_badge_events();

-- ============================================================================
-- Resume tasks to activate them
-- ============================================================================

-- Resume tasks in reverse dependency order (child first, parent second)
ALTER TASK staging_to_analytics_task RESUME;
ALTER TASK SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_to_staging_task RESUME;

-- Verify task configuration
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- TASK MONITORING
-- ============================================================================
-- 
-- Check task status:
--   SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;
-- 
-- View task execution history:
--   SELECT *
--   FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
--       SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
--       RESULT_LIMIT => 100
--   ))
--   ORDER BY SCHEDULED_TIME DESC;
-- 
-- Check specific task runs:
--   SELECT 
--       name,
--       state,
--       scheduled_time,
--       completed_time,
--       DATEDIFF('second', scheduled_time, completed_time) AS duration_sec,
--       error_code,
--       error_message
--   FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
--   WHERE name = 'RAW_TO_STAGING_TASK'
--   ORDER BY scheduled_time DESC
--   LIMIT 10;
-- 
-- Suspend tasks (for maintenance):
--   ALTER TASK raw_to_staging_task SUSPEND;
--   ALTER TASK staging_to_analytics_task SUSPEND;
-- 
-- Resume tasks:
--   ALTER TASK staging_to_analytics_task RESUME;
--   ALTER TASK raw_to_staging_task RESUME;
-- ============================================================================

-- ============================================================================
-- PERFORMANCE TUNING
-- ============================================================================
-- 
-- If tasks are running slowly:
--   1. Increase warehouse size:
--      ALTER WAREHOUSE etl_wh SET WAREHOUSE_SIZE = 'SMALL';
--   
--   2. Adjust auto-suspend to keep warehouse warm:
--      ALTER WAREHOUSE etl_wh SET AUTO_SUSPEND = 300;  -- 5 minutes
--   
--   3. Consider batch processing (5-minute schedule instead of 1-minute):
--      ALTER TASK raw_to_staging_task SET SCHEDULE = '5 MINUTE';
--   
--   4. Monitor warehouse usage:
--      SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
--      WHERE WAREHOUSE_NAME = 'ETL_WH'
--      ORDER BY START_TIME DESC;
-- ============================================================================

