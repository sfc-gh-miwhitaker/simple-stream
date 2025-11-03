-- ============================================================================
-- RFID Badge Tracking: Suspend Tasks (Preserve Data)
-- ============================================================================
-- Purpose: Stop all tasks to pause the data pipeline while preserving
--          all data and structures. Useful for maintenance or debugging.
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Suspend tasks (must suspend child tasks first, then parent)
ALTER TASK IF EXISTS TRANSFORM_BADGE_TRACKING.staging_to_analytics_task SUSPEND;
ALTER TASK IF EXISTS STAGE_BADGE_TRACKING.raw_to_staging_task SUSPEND;

-- Verify tasks are suspended
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;

-- ============================================================================
-- TO RESUME TASKS
-- ============================================================================
-- 
-- To restart the pipeline, resume tasks in reverse order:
-- 
--   ALTER TASK staging_to_analytics_task RESUME;
--   ALTER TASK raw_to_staging_task RESUME;
-- 
-- ============================================================================

