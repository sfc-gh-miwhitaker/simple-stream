-- ============================================================================
-- RFID Badge Tracking: Modern Data Quality with Data Metric Functions (DMF)
-- ============================================================================
-- Purpose: Automated data quality monitoring using Snowflake's DMF framework
--          (GA 2024). Combines system DMFs with custom metrics for comprehensive
--          data quality validation.
--
-- Features:
--   - Automated scheduling (cron, interval, or trigger-based)
--   - System DMFs for common metrics (NULL counts, freshness, duplicates)
--   - Custom DMFs for business logic validation
--   - Expectations with automatic violation detection
--   - Centralized event table for monitoring results
--   - OpenTelemetry format for observability integration
--
-- Reference: https://docs.snowflake.com/en/user-guide/data-quality-intro
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- ============================================================================
-- Step 0: Prerequisites
-- ============================================================================
-- This script is designed to run ONCE during initial setup
-- To re-run after making changes:
--   1. Drop existing DMFs manually, or
--   2. Use MODIFY DATA METRIC FUNCTION to update schedules/expectations
--
-- Quick cleanup command (run in SnowSQL if needed):
--   See cleanup examples at end of this file

-- ============================================================================
-- Step 1: Create Event Table for DMF Results
-- ============================================================================
-- All DMF measurements are automatically logged to this centralized table

CREATE EVENT TABLE IF NOT EXISTS SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.DATA_QUALITY_EVENTS;

-- Set this as the event table at DATABASE level (not account-wide)
-- This limits scope to SNOWFLAKE_EXAMPLE database only, avoiding interference
-- with other databases or features in the account that may have their own event tables
--
-- WARNING: To use account-wide event collection (impacts ALL features):
--          ALTER ACCOUNT SET EVENT_TABLE = ... (requires ACCOUNTADMIN)
ALTER DATABASE SNOWFLAKE_EXAMPLE 
  SET EVENT_TABLE = SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.DATA_QUALITY_EVENTS;

-- ============================================================================
-- Step 2: Define Custom Data Metric Functions
-- ============================================================================

-- Custom DMF: Check for duplicate badge events (same badge + timestamp)
CREATE OR REPLACE DATA METRIC FUNCTION duplicate_events(
  arg_t TABLE(badge_id VARCHAR, event_timestamp TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*) 
  FROM (
    SELECT badge_id, event_timestamp, COUNT(*) as cnt
    FROM arg_t
    GROUP BY badge_id, event_timestamp
    HAVING COUNT(*) > 1
  )
$$;

-- Custom DMF: Check for invalid signal strength values
CREATE OR REPLACE DATA METRIC FUNCTION invalid_signal_strength(
  arg_t TABLE(signal_strength NUMBER)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*) 
  FROM arg_t
  WHERE signal_strength NOT BETWEEN -100 AND 0
    AND signal_strength <> -999  -- -999 is allowed as "unknown"
$$;

-- Custom DMF: Check for future timestamps
-- Note: DMFs cannot use CURRENT_TIMESTAMP(), so we check for timestamps > 2099
CREATE OR REPLACE DATA METRIC FUNCTION future_timestamps(
  arg_t TABLE(event_timestamp TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*) 
  FROM arg_t
  WHERE event_timestamp > '2099-12-31'::TIMESTAMP_NTZ
$$;

-- Custom DMF: Check for invalid direction values
CREATE OR REPLACE DATA METRIC FUNCTION invalid_direction(
  arg_t TABLE(direction VARCHAR)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*) 
  FROM arg_t
  WHERE direction NOT IN ('ENTRY', 'EXIT') 
    AND direction IS NOT NULL
$$;

-- Custom DMF: Check for abnormally high user activity (> 100 events/hour)
-- Note: Checks most recent hour of data in the table
CREATE OR REPLACE DATA METRIC FUNCTION abnormal_user_activity(
  arg_t TABLE(user_id VARCHAR, event_timestamp TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
  WITH max_time AS (
    SELECT MAX(event_timestamp) as latest FROM arg_t
  )
  SELECT COUNT(DISTINCT user_id)
  FROM (
    SELECT 
      a.user_id,
      DATE_TRUNC('hour', a.event_timestamp) AS hour,
      COUNT(*) AS event_count
    FROM arg_t a
    CROSS JOIN max_time m
    WHERE a.event_timestamp >= DATEADD('hour', -1, m.latest)
    GROUP BY a.user_id, DATE_TRUNC('hour', a.event_timestamp)
    HAVING COUNT(*) > 100
  )
$$;

-- Custom DMF: Referential integrity check for fact table (requires 2 tables)
CREATE OR REPLACE DATA METRIC FUNCTION orphaned_fact_records(
  fact_table TABLE(user_key NUMBER, zone_key NUMBER),
  dim_table TABLE(dim_key NUMBER)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*) 
  FROM fact_table f
  WHERE f.user_key NOT IN (SELECT dim_key FROM dim_table)
     OR f.zone_key NOT IN (SELECT dim_key FROM dim_table)
$$;

-- ============================================================================
-- Step 3: Set DMF Schedules on Tables
-- ============================================================================

-- RAW_BADGE_EVENTS: Run checks every 15 minutes
ALTER TABLE RAW_BADGE_EVENTS SET
  DATA_METRIC_SCHEDULE = '15 MINUTE';

-- STG_BADGE_EVENTS: Run checks on DML changes (trigger-based)
ALTER TABLE SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS SET
  DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- FCT_ACCESS_EVENTS: Run checks hourly at :00
ALTER TABLE SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS SET
  DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-- ============================================================================
-- Step 4: Associate System DMFs with RAW_BADGE_EVENTS
-- ============================================================================

-- Check for NULL badge_id (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (badge_id)
  EXPECTATION no_nulls (VALUE = 0);

-- Check for NULL user_id (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (user_id)
  EXPECTATION no_nulls (VALUE = 0);

-- Check for NULL zone_id (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (zone_id)
  EXPECTATION no_nulls (VALUE = 0);

-- Check for NULL event_timestamp (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (event_timestamp)
  EXPECTATION no_nulls (VALUE = 0);

-- Check for blank badge_id values (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (badge_id)
  EXPECTATION no_blanks (VALUE = 0);

-- Monitor row count (expect steady growth)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
  EXPECTATION growing (VALUE >= 1000);

-- Monitor data freshness (expect data within last 5 minutes)
-- Freshness: Check based on last DML operation (not column-based, since we use TIMESTAMP_NTZ)
-- FRESHNESS DMF requires TIMESTAMP_LTZ/TZ, so we use DML-based freshness instead
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON ()
  EXPECTATION fresh_data (VALUE <= 300); -- Alert if no DML in 5+ minutes (300 seconds)

-- ============================================================================
-- Step 5: Associate Custom DMFs with RAW_BADGE_EVENTS
-- ============================================================================

-- Check for duplicate events (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION duplicate_events ON (badge_id, event_timestamp)
  EXPECTATION no_duplicates (VALUE = 0);

-- Check for invalid signal strength (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION invalid_signal_strength ON (signal_strength)
  EXPECTATION valid_signals (VALUE = 0);

-- Check for future timestamps (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION future_timestamps ON (event_timestamp)
  EXPECTATION no_future (VALUE = 0);

-- Check for invalid direction values (expect 0)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION invalid_direction ON (direction)
  EXPECTATION valid_directions (VALUE = 0);

-- Check for abnormal user activity (expect < 5 users)
ALTER TABLE RAW_BADGE_EVENTS
  ADD DATA METRIC FUNCTION abnormal_user_activity ON (user_id, event_timestamp)
  EXPECTATION normal_activity (VALUE < 5);

-- ============================================================================
-- Step 6: Associate DMFs with STAGING Table
-- ============================================================================

-- Staging row count should match or exceed raw (after processing)
ALTER TABLE SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
  EXPECTATION data_exists (VALUE > 0);

-- NULL checks on critical staging fields
ALTER TABLE SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (signal_quality)
  EXPECTATION quality_populated (VALUE = 0);

-- ============================================================================
-- Step 7: Associate DMFs with ANALYTICS Fact Table
-- ============================================================================

-- Monitor fact table row count growth
ALTER TABLE SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();

-- Check for NULL surrogate keys (expect 0)
ALTER TABLE SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (user_key)
  EXPECTATION valid_user_key (VALUE = 0);

ALTER TABLE SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (zone_key)
  EXPECTATION valid_zone_key (VALUE = 0);

-- Check fact table freshness (expect data within last hour)
ALTER TABLE SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (event_timestamp)
  EXPECTATION recent_data (VALUE <= 60);

-- ============================================================================
-- Step 8: Query DMF Results
-- ============================================================================

-- View all data quality measurements
CREATE OR REPLACE VIEW V_DATA_QUALITY_DASHBOARD AS
SELECT
  measurement_time,
  table_database,
  table_schema,
  table_name,
  data_metric_name,
  value AS measurement_value,
  expectation_violations,
  schedule_type,
  status
FROM SNOWFLAKE.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = 'SNOWFLAKE_EXAMPLE'
ORDER BY measurement_time DESC;

-- View only failed expectations (violations)
CREATE OR REPLACE VIEW V_DATA_QUALITY_VIOLATIONS AS
SELECT
  measurement_time,
  table_database || '.' || table_schema || '.' || table_name AS full_table_name,
  data_metric_name,
  value AS measurement_value,
  ARRAY_SIZE(expectation_violations) AS violation_count,
  expectation_violations
FROM SNOWFLAKE.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = 'SNOWFLAKE_EXAMPLE'
  AND ARRAY_SIZE(expectation_violations) > 0
ORDER BY measurement_time DESC;

-- Aggregate quality score by table (% of checks passing)
CREATE OR REPLACE VIEW V_TABLE_QUALITY_SCORES AS
SELECT
  table_database || '.' || table_schema || '.' || table_name AS full_table_name,
  COUNT(*) AS total_measurements,
  SUM(CASE WHEN ARRAY_SIZE(expectation_violations) = 0 THEN 1 ELSE 0 END) AS passed_checks,
  ROUND(100.0 * SUM(CASE WHEN ARRAY_SIZE(expectation_violations) = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS quality_score_pct,
  MAX(measurement_time) AS last_measured
FROM SNOWFLAKE.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = 'SNOWFLAKE_EXAMPLE'
  AND measurement_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY table_database, table_schema, table_name
ORDER BY quality_score_pct ASC;

-- Recent violation trends
CREATE OR REPLACE VIEW V_VIOLATION_TRENDS AS
SELECT
  DATE_TRUNC('hour', measurement_time) AS measurement_hour,
  table_name,
  data_metric_name,
  COUNT(*) AS violation_count
FROM SNOWFLAKE.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = 'SNOWFLAKE_EXAMPLE'
  AND ARRAY_SIZE(expectation_violations) > 0
  AND measurement_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY DATE_TRUNC('hour', measurement_time), table_name, data_metric_name
ORDER BY measurement_hour DESC, violation_count DESC;

-- ============================================================================
-- Step 9: Create Alerting Task (Optional)
-- ============================================================================

-- Task to check for violations and send alerts
CREATE OR REPLACE TASK ALERT_ON_DATA_QUALITY_VIOLATIONS
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
WHEN
  SYSTEM$STREAM_HAS_DATA('CHECK_FOR_VIOLATIONS_STREAM')
AS
BEGIN
  -- This would integrate with your alerting system (email, Slack, PagerDuty, etc.)
  -- Example: Log critical violations
  INSERT INTO DQ_VIOLATION_LOG
  SELECT
    CURRENT_TIMESTAMP() AS alert_time,
    table_name,
    data_metric_name,
    value,
    expectation_violations
  FROM V_DATA_QUALITY_VIOLATIONS
  WHERE measurement_time >= DATEADD('minute', -5, CURRENT_TIMESTAMP());
END;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Example 1: View recent quality measurements
SELECT * FROM V_DATA_QUALITY_DASHBOARD LIMIT 50;

-- Example 2: Check current violations
SELECT * FROM V_DATA_QUALITY_VIOLATIONS;

-- Example 3: Get quality scores for all tables
SELECT * FROM V_TABLE_QUALITY_SCORES;

-- Example 4: Manually trigger a specific DMF (for testing)
SELECT duplicate_events(
  SELECT badge_id, event_timestamp 
  FROM RAW_BADGE_EVENTS 
  WHERE ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
);

-- Example 5: View DMF schedules
SHOW PARAMETERS LIKE 'DATA_METRIC_SCHEDULE' IN TABLE RAW_BADGE_EVENTS;

-- Example 6: List all DMFs associated with a table
SHOW DATA METRIC FUNCTIONS IN TABLE RAW_BADGE_EVENTS;

-- Example 7: Remove a specific DMF
-- ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION invalid_direction ON (direction);

-- Example 8: Pause DMF execution (keep associations but stop scheduling)
-- ALTER TABLE RAW_BADGE_EVENTS UNSET DATA_METRIC_SCHEDULE;

-- ============================================================================
-- MONITORING BEST PRACTICES
-- ============================================================================
-- 
-- 1. Schedule Recommendations:
--    - RAW tables: 5-15 minute intervals for near-real-time monitoring
--    - STAGING tables: TRIGGER_ON_CHANGES for immediate validation
--    - ANALYTICS tables: Hourly or daily based on SLA requirements
--    - Data quality tables: Daily for cost/performance balance
--
-- 2. Expectation Thresholds:
--    - Start conservative (strict thresholds), relax as you understand patterns
--    - Use percentage-based thresholds for scalability (e.g., < 1% duplicates)
--    - Document business justification for each threshold
--
-- 3. Cost Management:
--    - DMFs consume compute credits when executed
--    - Balance monitoring frequency with cost (use cron for off-peak hours)
--    - Use TRIGGER_ON_CHANGES sparingly (only for critical validations)
--    - Monitor DMF costs: SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY;
--
-- 4. Alerting Strategy:
--    - CRITICAL: Immediate alert (NULL in PK, referential integrity failures)
--    - WARNING: Log and review daily (elevated duplicate rates, freshness delays)
--    - INFO: Track trends only (row counts, statistics)
--
-- 5. Integration:
--    - Event table data is OpenTelemetry format - integrate with:
--      * Datadog, New Relic, Splunk (observability platforms)
--      * Snowsight dashboards (native visualization)
--      * Custom alerting (email, Slack, PagerDuty via stored procedures)
--
-- 6. Troubleshooting:
--    - Query SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS for history
--    - Check DMF execution errors in EVENT_TABLE
--    - Verify schedules: SHOW PARAMETERS LIKE 'DATA_METRIC_SCHEDULE'
--    - Test DMFs manually before associating: SELECT my_dmf(SELECT * FROM my_table);
--
-- ============================================================================
-- APPENDIX: Cleanup Commands (for re-deployment during development)
-- ============================================================================
-- 
-- To remove all DMF associations from RAW_BADGE_EVENTS:
/*
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (badge_id);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (user_id);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (zone_id);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (event_timestamp);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (badge_id);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION duplicate_events ON (badge_id, event_timestamp);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION invalid_signal_strength ON (signal_strength);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION future_timestamps ON (event_timestamp);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION invalid_direction ON (direction);
ALTER TABLE RAW_BADGE_EVENTS DROP DATA METRIC FUNCTION abnormal_user_activity ON (user_id, event_timestamp);
*/

-- To remove all custom DMF definitions:
/*
DROP FUNCTION IF EXISTS duplicate_events(TABLE(VARCHAR, TIMESTAMP_NTZ));
DROP FUNCTION IF EXISTS invalid_signal_strength(TABLE(NUMBER));
DROP FUNCTION IF EXISTS future_timestamps(TABLE(TIMESTAMP_NTZ));
DROP FUNCTION IF EXISTS invalid_direction(TABLE(VARCHAR));
DROP FUNCTION IF EXISTS abnormal_user_activity(TABLE(VARCHAR, TIMESTAMP_NTZ));
DROP FUNCTION IF EXISTS orphaned_fact_records(TABLE(NUMBER, NUMBER), TABLE(NUMBER));
*/
--
-- ============================================================================

