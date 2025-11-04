/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Suspend Tasks (Preserve Data)
 * 
 * WARNING:  NON-DESTRUCTIVE - Pauses pipeline, preserves all data
 * 
 * PURPOSE:
 *   Stop all tasks to pause the data pipeline while preserving all data
 *   and structures. Useful for:
 *   - Maintenance windows
 *   - Debugging pipeline issues
 *   - Cost control (prevent credit consumption)
 *   - Making schema changes
 * 
 * USAGE:
 *   Execute in Snowsight Workspaces (Projects → Workspaces → + SQL File)
 * 
 * ESTIMATED TIME: 5 seconds
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE ROLE SYSADMIN;

/*******************************************************************************
 * Suspend All Tasks
 * 
 * Must suspend child tasks first, then parent (reverse dependency order)
 ******************************************************************************/

-- Suspend child task first
ALTER TASK IF EXISTS STAGING_LAYER.sfe_staging_to_analytics_task SUSPEND;

-- Suspend parent task
ALTER TASK IF EXISTS RAW_INGESTION.sfe_raw_to_staging_task SUSPEND;

-- Verify tasks are suspended
SHOW TASKS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * Verification
 * 
 * Expected output: state = 'suspended' for both tasks
 ******************************************************************************/

SELECT 
    name,
    state,
    warehouse,
    schedule,
    CASE 
        WHEN state = 'suspended' THEN ' Suspended successfully'
        ELSE ' Still active'
    END AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

/*******************************************************************************
 * TO RESUME THE PIPELINE
 * 
 * Resume tasks in reverse order (parent first, then child):
 * 
 *   USE ROLE SYSADMIN;
 *   USE DATABASE SNOWFLAKE_EXAMPLE;
 *   
 *   -- Resume parent task first
 *   ALTER TASK RAW_INGESTION.sfe_raw_to_staging_task RESUME;
 *   
 *   -- Resume child task
 *   ALTER TASK STAGING_LAYER.sfe_staging_to_analytics_task RESUME;
 *   
 *   -- Verify tasks are running
 *   SHOW TASKS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;
 * 
 * ALTERNATIVE: Use stored procedure (if it exists):
 *   CALL SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_DEPLOY_PIPELINE();
 ******************************************************************************/

/*******************************************************************************
 * WHAT HAPPENS WHEN TASKS ARE SUSPENDED?
 * 
 *  Pipeline stops processing new data
 *  All data remains intact (no data loss)
 *  Warehouse will not be charged (no task executions)
 *  Streams continue tracking changes (offsets preserved)
 *  Pipe continues accepting data via REST API
 * 
 * WARNING:  New data will accumulate in:
 *     - RAW_INGESTION.RAW_BADGE_EVENTS (from pipe)
 *     - Stream sfe_badge_events_stream (tracks raw inserts)
 * 
 *  When resumed, tasks will process ALL accumulated data since suspension
 ******************************************************************************/

/*******************************************************************************
 * MONITORING SUSPENDED STATE
 * 
 * Check how much data has accumulated:
 *   
 *   -- Check stream backlog
 *   SELECT SYSTEM$STREAM_HAS_DATA('RAW_INGESTION.sfe_badge_events_stream');
 *   
 *   -- Count raw events not yet processed
 *   SELECT 
 *     COUNT(*) AS raw_events,
 *     MIN(ingestion_time) AS oldest_event,
 *     MAX(ingestion_time) AS newest_event
 *   FROM RAW_INGESTION.RAW_BADGE_EVENTS;
 *   
 *   -- Count staged events
 *   SELECT 
 *     COUNT(*) AS staged_events
 *   FROM STAGING_LAYER.STG_BADGE_EVENTS;
 ******************************************************************************/
