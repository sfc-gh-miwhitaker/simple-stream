/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Pipeline Tasks
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Orchestrate CDC pipeline from RAW to ANALYTICS.
 * OBJECTS: sfe_raw_to_staging_task, sfe_process_badge_events, sfe_staging_to_analytics_task
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

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

CREATE OR REPLACE TASK sfe_staging_to_analytics_task
    AFTER sfe_raw_to_staging_task
    COMMENT = 'DEMO: sfe-simple-stream - STAGING to ANALYTICS task'
AS
    CALL sfe_process_badge_events();

ALTER TASK sfe_staging_to_analytics_task RESUME;
ALTER TASK SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_raw_to_staging_task RESUME;
