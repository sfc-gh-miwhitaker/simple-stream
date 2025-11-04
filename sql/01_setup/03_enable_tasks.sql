/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Enable Automated Pipeline Tasks
 * 
 * WARNING:  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create and ENABLE automated tasks that orchestrate the CDC pipeline:
 *   - RAW → STAGING deduplication task (runs every 1 minute)
 *   - Stored procedure to process staging events into analytics layer
 *   - STAGING → ANALYTICS enrichment task (dependent on first task)
 * 
 * OBJECTS CREATED:
 *   - Task: sfe_raw_to_staging_task (with RESUME)
 *   - Procedure: sfe_process_badge_events()
 *   - Task: sfe_staging_to_analytics_task (with RESUME)
 * 
 * DEPENDENCIES:
 *   - sql/01_setup/01_core_setup.sql (must run first)
 *   - sql/01_setup/02_analytics_layer.sql (must run first)
 * 
 * WARNING:  WARNING: This script RESUMES tasks, starting automated execution!
 * 
 * USAGE:
 *   Execute in Snowsight: Projects → Workspaces → + SQL File → Run All
 * 
 * CLEANUP:
 *   sql/99_cleanup/teardown_tasks_only.sql (suspend tasks)
 *   sql/99_cleanup/teardown_all.sql (remove everything)
 * 
 * ESTIMATED TIME: 5 seconds
 ******************************************************************************/

-- ============================================================================
-- PREREQUISITE: Analytics layer must be complete
-- ============================================================================
-- Run sql/01_setup/02_analytics_layer.sql first

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

-- ============================================================================
-- IMPORTANT: Suspend root task first if re-running this script
-- ============================================================================
-- When re-running, the root task may already be started. We must suspend it
-- before creating/modifying any child tasks in the DAG.

ALTER TASK IF EXISTS sfe_raw_to_staging_task SUSPEND;
CALL SYSTEM$WAIT(2);

CREATE OR REPLACE TASK sfe_raw_to_staging_task
    SCHEDULE = '1 MINUTE'
    COMMENT = 'DEMO: sfe-simple-stream - RAW to STAGING dedupe task'
WHEN SYSTEM$STREAM_HAS_DATA('sfe_badge_events_stream')
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
    QUALIFY ROW_NUMBER() OVER (PARTITION BY badge_id, event_timestamp ORDER BY ingestion_time DESC) = 1;

USE SCHEMA STAGING_LAYER;

CREATE OR REPLACE PROCEDURE sfe_process_badge_events()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - Transform staging events into analytics layer'
EXECUTE AS OWNER
AS
$$
BEGIN
    MERGE INTO SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS d
    USING (
        SELECT DISTINCT user_id
        FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS
    ) s
    ON d.user_id = s.user_id AND d.is_current = TRUE
    WHEN NOT MATCHED THEN
        INSERT (
            user_id,
            user_name,
            user_type,
            department,
            clearance_level,
            is_active,
            is_current,
            effective_start_date
        )
        VALUES (
            s.user_id,
            'UNKNOWN',
            'UNKNOWN',
            'UNKNOWN',
            'PUBLIC',
            TRUE,
            TRUE,
            CURRENT_TIMESTAMP()
        );

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
        DATE(s.event_timestamp),
        HOUR(s.event_timestamp),
        DAYOFWEEK(s.event_timestamp),
        s.direction,
        s.signal_strength,
        s.signal_quality,
        z.is_restricted,
        IFF(HOUR(s.event_timestamp) < 6 OR HOUR(s.event_timestamp) >= 22, TRUE, FALSE),
        IFF(DAYOFWEEK(s.event_timestamp) IN (0, 6), TRUE, FALSE),
        s.ingestion_time
    FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS s
    JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS u
        ON s.user_id = u.user_id AND u.is_current = TRUE
    JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_ZONES z
        ON s.zone_id = z.zone_id
    LEFT JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS f
        ON s.badge_id = f.badge_id
        AND s.event_timestamp = f.event_timestamp
    WHERE f.event_key IS NULL;

    RETURN 'PROCESS_BADGE_EVENTS_COMPLETED';
END;
$$;

-- ============================================================================
-- STEP 3: Create Child Task (Must be in Same Schema as Parent)
-- ============================================================================
-- Note: Snowflake requires child tasks to be in the same schema as parent tasks

USE SCHEMA RAW_INGESTION;

CREATE OR REPLACE TASK sfe_staging_to_analytics_task
    COMMENT = 'DEMO: sfe-simple-stream - STAGING to ANALYTICS task'
    AFTER sfe_raw_to_staging_task
AS
    CALL SNOWFLAKE_EXAMPLE.STAGING_LAYER.sfe_process_badge_events();

-- ============================================================================
-- STEP 4: Ensure Tasks Are Suspended, Then Resume in Correct Order
-- ============================================================================
-- Per Snowflake docs: "Before resuming the root task, resume all child tasks"
-- If re-running this script, tasks may already be started, so suspend them first

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

-- Ensure both tasks are suspended (safe for new or existing tasks)
ALTER TASK IF EXISTS sfe_staging_to_analytics_task SUSPEND;
ALTER TASK IF EXISTS sfe_raw_to_staging_task SUSPEND;

-- Wait for any running executions to complete
CALL SYSTEM$WAIT(2);

-- Resume child task first (while root is still suspended)
ALTER TASK sfe_staging_to_analytics_task RESUME;

-- Resume root/parent task LAST (this activates the entire DAG)
ALTER TASK sfe_raw_to_staging_task RESUME;
