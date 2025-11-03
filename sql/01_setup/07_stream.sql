-- ============================================================================
-- RFID Badge Tracking: Stream for Change Data Capture (CDC)
-- ============================================================================
-- Purpose: Create a Stream on the raw table to capture INSERT operations
--          for incremental processing. The Stream tracks changes without
--          adding overhead to the source table.
--
-- Key Features:
--   - Captures only INSERT operations (badge events are append-only)
--   - Adds metadata columns (METADATA$ACTION, METADATA$ISUPDATE, etc.)
--   - Enables event-driven task execution
--   - Consumed when downstream task commits successfully
--
-- Source: SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
-- Consumer: raw_to_staging_task
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- Create stream on raw table
CREATE OR REPLACE STREAM raw_badge_events_stream
ON TABLE RAW_BADGE_EVENTS
COMMENT = 'CDC stream for capturing new badge events from RAW_BADGE_EVENTS';

-- Verify stream creation
SHOW STREAMS IN SCHEMA STAGE_BADGE_TRACKING;

-- Display stream details
DESC STREAM raw_badge_events_stream;

-- Check initial stream status (should be empty)
SELECT SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream') AS has_data;

-- ============================================================================
-- STREAM BEHAVIOR NOTES
-- ============================================================================
-- 
-- How Streams Work:
--   1. Stream is created at current table version (offset)
--   2. All subsequent DML operations (INSERT, UPDATE, DELETE) are tracked
--   3. Stream adds metadata columns:
--      - METADATA$ACTION: 'INSERT', 'DELETE'
--      - METADATA$ISUPDATE: TRUE if row was updated
--      - METADATA$ROW_ID: Unique identifier for the row
--   4. When Task consumes stream data (in a transaction), offset advances
--   5. Stream is "consumed" after successful commit
-- 
-- Querying the Stream:
--   SELECT * FROM raw_badge_events_stream;
--   -- Returns all changes since last consumption
-- 
-- Checking if Stream Has Data:
--   SELECT SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream');
--   -- Returns TRUE if stream has unconsumed changes
-- 
-- Stream Types:
--   - Standard Stream (default): Tracks all DML operations
--   - Append-only Stream: Only tracks INSERTs (lighter weight)
--   - Insert-only Stream: Only captures INSERT operations
-- 
-- For this use case, we use a standard stream since badge events are
-- append-only (no UPDATEs or DELETEs expected).
-- ============================================================================

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================
-- 
-- If stream appears stuck or not advancing:
--   1. Check if task is running:
--      SHOW TASKS LIKE 'raw_to_staging_task';
--   2. Check task history:
--      SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
--      WHERE NAME = 'RAW_TO_STAGING_TASK'
--      ORDER BY SCHEDULED_TIME DESC;
--   3. Manually query stream:
--      SELECT COUNT(*) FROM raw_badge_events_stream;
--   4. Check stream metadata:
--      SHOW STREAMS LIKE 'raw_badge_events_stream';
-- 
-- To reset stream (start from current table version):
--   DROP STREAM raw_badge_events_stream;
--   CREATE STREAM raw_badge_events_stream ON TABLE RAW_BADGE_EVENTS;
-- ============================================================================

