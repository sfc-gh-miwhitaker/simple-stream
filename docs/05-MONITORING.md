# 05 - Monitoring & Troubleshooting

**Goal:** Monitor pipeline health and troubleshoot issues.

**Time:** Ongoing

**Previous:** [`04-RUNNING.md`](04-RUNNING.md)

---

## Overview

Learn how to monitor the RFID badge tracking pipeline, identify bottlenecks, and troubleshoot common issues.

---

## Quick Health Check

```sql
USE DATABASE SNOWFLAKE_EXAMPLE;

-- 1. Row counts across all layers
SELECT 'RAW' AS layer, COUNT(*) FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING', COUNT(*) FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS', COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;

-- 2. Stream status
SELECT SYSTEM$STREAM_HAS_DATA('STAGE_BADGE_TRACKING.raw_badge_events_stream') AS has_pending_data;

-- 3. Recent task runs
SELECT name, state, scheduled_time, completed_time
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC
LIMIT 5;
```

---

## Monitoring Views

### Data Freshness

```sql
USE SCHEMA STAGE_BADGE_TRACKING;

-- View all monitoring views
SHOW VIEWS;

-- Data freshness by layer
SELECT * FROM V_DATA_FRESHNESS;

-- Expected output:
-- layer       | latest_timestamp        | age_minutes
-- RAW         | 2025-11-03 10:05:00   | 2
-- STAGING     | 2025-11-03 10:04:00   | 3
-- ANALYTICS   | 2025-11-03 10:03:30   | 3.5
```

### End-to-End Latency

```sql
SELECT * FROM V_END_TO_END_LATENCY
ORDER BY event_timestamp DESC
LIMIT 10;

-- Shows time from RAW → ANALYTICS for recent events
```

### Task Execution History

```sql
SELECT * FROM V_TASK_EXECUTION_HISTORY
ORDER BY scheduled_time DESC
LIMIT 20;

-- Monitor:
-- - Execution times
-- - Success/failure rates
-- - Error messages
```

### Channel Status

```sql
SELECT * FROM V_CHANNEL_STATUS;

-- Shows:
-- - Rows inserted
-- - Error count
-- - Last error message
-- - Processing latency
```

---

## Key Metrics to Watch

### 1. Data Latency

**Acceptable:**
- RAW → STAGING: < 2 minutes
- STAGING → ANALYTICS: < 2 minutes
- End-to-end: < 5 minutes

**If higher:** Check task execution history for delays

### 2. Task Success Rate

```sql
SELECT 
    name,
    COUNT(*) as total_runs,
    COUNT(CASE WHEN state = 'SUCCEEDED' THEN 1 END) as successful,
    COUNT(CASE WHEN state = 'FAILED' THEN 1 END) as failed
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
  AND scheduled_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY name;
```

**Target:** > 99% success rate

### 3. Row Count Consistency

```sql
-- Should be equal (or STAGING/ANALYTICS slightly behind during processing)
WITH counts AS (
    SELECT 'RAW' as layer, COUNT(*) as cnt FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
    UNION ALL
    SELECT 'STAGING', COUNT(*) FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
    UNION ALL
    SELECT 'ANALYTICS', COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
)
SELECT *, LAG(cnt) OVER (ORDER BY layer) - cnt as difference
FROM counts;
```

### 4. Error Rate

```sql
-- Check for rejected rows
SELECT 
    channel_name,
    rows_parsed,
    rows_inserted,
    rows_error_count,
    last_error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE pipe_name = 'BADGE_EVENTS_PIPE'
  AND start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

**Target:** Error rate < 0.1%

---

## Common Issues & Solutions

### Issue: Tasks Not Running

**Symptoms:**
- STAGING/ANALYTICS counts not increasing
- Stream has data but not consumed

**Diagnosis:**
```sql
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;
-- Check 'state' column should be 'started'
```

**Solution:**
```sql
-- Resume tasks
ALTER TASK SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_to_staging_task RESUME;
ALTER TASK SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.staging_to_analytics_task RESUME;
```

### Issue: High Latency

**Symptoms:**
- End-to-end latency > 5 minutes
- Tasks taking long to complete

**Diagnosis:**
```sql
-- Check task execution times
SELECT name, 
       DATEDIFF('second', scheduled_time, completed_time) as duration_sec
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC
LIMIT 10;
```

**Solution:**
```sql
-- Increase warehouse size
ALTER WAREHOUSE etl_wh SET WAREHOUSE_SIZE = 'SMALL';
```

### Issue: Row Count Mismatch

**Symptoms:**
- RAW count > STAGING count
- STAGING count > ANALYTICS count

**Diagnosis:**
```sql
-- Check for missing dimension keys
SELECT s.user_id, COUNT(*) as orphaned_records
FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS s
LEFT JOIN ANALYTICS_BADGE_TRACKING.DIM_USERS u 
    ON s.user_id = u.user_id AND u.is_current = TRUE
WHERE u.user_key IS NULL
GROUP BY s.user_id;
```

**Solution:**
- Wait for dimension maintenance (auto-creates users)
- Or manually insert missing dimensions

### Issue: Stream Not Advancing

**Symptoms:**
- `SYSTEM$STREAM_HAS_DATA` always returns TRUE
- RAW table growing but STAGING not

**Diagnosis:**
```sql
-- Check stream offset
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.STREAMS
WHERE stream_name = 'RAW_BADGE_EVENTS_STREAM';
```

**Solution:**
- Check task is actually running
- Verify no errors in task history
- May need to recreate stream if corrupted

---

## Performance Optimization

### Warehouse Sizing

**Current:** XSMALL (default)

**Increase if:**
- Task execution > 30 seconds consistently
- High data volumes (> 10K events/minute)

```sql
ALTER WAREHOUSE etl_wh SET WAREHOUSE_SIZE = 'SMALL';
```

### Task Schedule Tuning

**Current:** 1 minute

**Adjust based on latency requirements:**

```sql
-- Less frequent (lower cost, higher latency)
ALTER TASK raw_to_staging_task SET SCHEDULE = '5 MINUTE';

-- More frequent (higher cost, lower latency)
ALTER TASK raw_to_staging_task SET SCHEDULE = '30 SECOND';
```

### Clustering Maintenance

```sql
-- Check clustering health
SELECT SYSTEM$CLUSTERING_INFORMATION('ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS');

-- If clustering_depth > 4, consider reclustering
ALTER TABLE ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS RECLUSTER;
```

---

## Cost Monitoring

### Warehouse Credit Usage

```sql
SELECT 
    warehouse_name,
    SUM(credits_used) as total_credits,
    COUNT(*) as execution_count
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'ETL_WH'
  AND start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name;
```

### Snowpipe Streaming Costs

```sql
SELECT 
    pipe_name,
    SUM(bytes_received) / POWER(1024, 3) as gb_ingested,
    SUM(rows_inserted) as total_rows
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE pipe_name = 'BADGE_EVENTS_PIPE'
  AND start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY pipe_name;
```

---

## Alerting Setup

### Create Resource Monitor

```sql
CREATE RESOURCE MONITOR badge_tracking_monitor
WITH CREDIT_QUOTA = 100  -- Monthly budget
FREQUENCY = MONTHLY
START_TIMESTAMP = IMMEDIATELY
TRIGGERS
  ON 75 PERCENT DO NOTIFY
  ON 90 PERCENT DO NOTIFY
  ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE etl_wh SET RESOURCE_MONITOR = badge_tracking_monitor;
```

### Email Notifications

Configure in Snowflake UI:
1. Admin → Account → Notification Settings
2. Add email for resource monitor alerts

---

## Cleanup

### Suspend Pipeline

```bash
# Run teardown script
snow sql -f sql/99_cleanup/teardown_tasks_only.sql
```

### Full Cleanup

```bash
# Remove all objects
snow sql -f sql/99_cleanup/teardown_all.sql
```

---

## Additional Resources

- **Architecture:** [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **Data Dictionary:** [`DATA_DICTIONARY.md`](DATA_DICTIONARY.md)
- **Platform Guide:** [`PLATFORM_GUIDE.md`](PLATFORM_GUIDE.md)
- **Validation Guide:** [`VALIDATION_GUIDE.md`](VALIDATION_GUIDE.md)

---

**Guide:** 05-MONITORING | ← [04-RUNNING](04-RUNNING.md)

🎉 **You've completed the full walkthrough!**

