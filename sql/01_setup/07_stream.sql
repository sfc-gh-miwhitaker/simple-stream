/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Stream for Change Data Capture (CDC)
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create a Stream on the raw table to capture INSERT operations for
 *   incremental processing. The Stream tracks changes without adding
 *   overhead to the source table.
 * 
 * OBJECTS CREATED:
 *   - sfe_badge_events_stream (Stream) - CDC stream for badge events
 * 
 * KEY FEATURES:
 *   - Captures only INSERT operations (badge events are append-only)
 *   - Adds metadata columns (METADATA$ACTION, METADATA$ISUPDATE, etc.)
 *   - Enables event-driven task execution
 *   - Consumed when downstream task commits successfully
 * 
 * SOURCE:
 *   SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
 * 
 * CONSUMER:
 *   sfe_raw_to_staging_task
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

-- Create stream on raw table
-- sfe_ prefix prevents collision with production streams
CREATE OR REPLACE STREAM sfe_badge_events_stream
ON TABLE RAW_BADGE_EVENTS
COMMENT = 'DEMO: sfe-simple-stream - CDC stream for capturing new badge events from RAW_BADGE_EVENTS';

-- Verify stream creation
SHOW STREAMS LIKE 'sfe_%' IN SCHEMA RAW_INGESTION;

-- Display stream details
DESC STREAM sfe_badge_events_stream;

-- Check initial stream status (should be empty)
SELECT SYSTEM$STREAM_HAS_DATA('sfe_badge_events_stream') AS has_data;

/*******************************************************************************
 * STREAM BEHAVIOR NOTES
 * 
 * How Streams Work:
 *   1. Stream is created at current table version (offset)
 *   2. All subsequent DML operations (INSERT, UPDATE, DELETE) are tracked
 *   3. Stream adds metadata columns:
 *      - METADATA$ACTION: 'INSERT', 'DELETE'
 *      - METADATA$ISUPDATE: TRUE if row was updated
 *      - METADATA$ROW_ID: Unique identifier for the row
 *   4. When Task consumes stream data (in a transaction), offset advances
 *   5. Stream is "consumed" after successful commit
 * 
 * Querying the Stream:
 *   SELECT * FROM sfe_badge_events_stream;
 *   -- Returns only new/changed rows since last consumption
 * 
 * Checking Stream Status:
 *   SELECT SYSTEM$STREAM_HAS_DATA('sfe_badge_events_stream');
 *   -- Returns TRUE if stream has pending data, FALSE if empty
 * 
 * Best Practices:
 *   - Use WHEN SYSTEM$STREAM_HAS_DATA() in Task definition
 *   - Query stream within same transaction as consuming INSERT/MERGE
 *   - Monitor stream lag with: SELECT SYSTEM$STREAM_GET_TABLE_TIMESTAMP()
 ******************************************************************************/
