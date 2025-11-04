# 02 - Pipeline Deployment

**Goal:** Deploy the complete RFID badge tracking pipeline to Snowflake.

**Time:** ~10 minutes

**Previous:** [`01-SETUP.md`](01-SETUP.md) | **Next:** [`03-CONFIGURATION.md`](03-CONFIGURATION.md)

---

## Overview

This guide deploys the full data pipeline:
- **Core infrastructure**: Database, schemas, raw table, Snowpipe, CDC stream
- **Analytics layer**: Staging table, dimension tables, fact table
- **Automation**: Tasks for incremental processing
- **Monitoring**: Views for pipeline health checks

---

## Prerequisites

- ✅ Completed [01-SETUP.md](01-SETUP.md) (Git repository connected)
- ✅ `SYSADMIN` role or equivalent
- ✅ Warehouse available (e.g., `COMPUTE_WH`)

---

## Deployment Options

### Option A: Automated Deployment (Recommended)

**Single command deployment** from Git repository:

```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Execute deployment script from Git
@sql/00_git_setup/03_deploy_from_git.sql
```

**Or use stored procedure:**
```sql
CALL SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_DEPLOY_PIPELINE();
```

**This will:**
1. Create core infrastructure (10 sec)
2. Create analytics layer (15 sec)
3. Enable task automation (5 sec)
4. Create monitoring views (10 sec)

**Total: ~40 seconds**

---

### Option B: Manual Step-by-Step Deployment

If you prefer to understand each component, run scripts individually:

#### Step 1: Core Infrastructure

```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

-- Run core setup script
@sql/01_setup/01_core_setup.sql
```

**Creates:**
- Database: `SNOWFLAKE_EXAMPLE`
- Schemas: `RAW_INGESTION`, `STAGING_LAYER`, `ANALYTICS_LAYER`
- Table: `RAW_BADGE_EVENTS` (target for Snowpipe Streaming)
- Pipe: `sfe_badge_events_pipe` (with transformation logic)
- Stream: `sfe_badge_events_stream` (CDC for incremental processing)

**Expected output:**
```
✅ Database created: SNOWFLAKE_EXAMPLE
✅ Schemas created: RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER
✅ Table created: RAW_BADGE_EVENTS (10 columns)
✅ Pipe created: sfe_badge_events_pipe
✅ Stream created: sfe_badge_events_stream
```

---

#### Step 2: Analytics Layer

```sql
-- Run analytics layer setup
@sql/01_setup/02_analytics_layer.sql
```

**Creates:**
- Staging: `STG_BADGE_EVENTS` (transient table for deduplication)
- Dimensions:
  - `DIM_USERS` (Type 2 SCD, seeded with 5 sample users)
  - `DIM_ZONES` (seeded with 5 sample zones)
  - `DIM_READERS` (badge reader metadata)
- Fact: `FCT_ACCESS_EVENTS` (clustered by event_date)

**Expected output:**
```
✅ Staging table created: STG_BADGE_EVENTS (transient, 1-day retention)
✅ Dimension tables created: DIM_USERS, DIM_ZONES, DIM_READERS
✅ Seed data loaded: 5 users, 5 zones
✅ Fact table created: FCT_ACCESS_EVENTS (clustered by event_date)
```

---

#### Step 3: Task Automation

```sql
-- Run task setup
@sql/01_setup/03_enable_tasks.sql
```

**Creates:**
- Task: `sfe_raw_to_staging_task` (RAW → STAGING, every 1 minute)
- Procedure: `sfe_process_badge_events()` (business logic)
- Task: `sfe_staging_to_analytics_task` (STAGING → ANALYTICS, dependent)

**⚠️ Important:** This script **resumes tasks**, starting automated processing!

**Expected output:**
```
✅ Task created: sfe_raw_to_staging_task (1-minute schedule)
✅ Procedure created: sfe_process_badge_events()
✅ Task created: sfe_staging_to_analytics_task (dependent)
✅ Tasks resumed: Automation active
```

---

#### Step 4: Monitoring Views

```sql
-- Run monitoring views setup
@sql/03_monitoring/monitoring_views.sql
```

**Creates views:**
- `V_INGESTION_MONITORING` - Real-time ingestion metrics
- `V_PIPELINE_HEALTH` - Overall pipeline status
- `V_TASK_EXECUTION_HISTORY` - Task run history

**Expected output:**
```
✅ Monitoring views created: 3 views in ANALYTICS_LAYER
```

---

## Verification

### Quick Health Check

```sql
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Verify schemas exist
SHOW SCHEMAS;

-- Check core infrastructure
SHOW TABLES IN SCHEMA RAW_INGESTION;
SHOW PIPES IN SCHEMA RAW_INGESTION;
SHOW STREAMS IN SCHEMA RAW_INGESTION;

-- Check analytics layer
SHOW TABLES IN SCHEMA ANALYTICS_LAYER;

-- Check seed data
SELECT COUNT(*) AS users FROM ANALYTICS_LAYER.DIM_USERS WHERE is_current = TRUE;
SELECT COUNT(*) AS zones FROM ANALYTICS_LAYER.DIM_ZONES;

-- Check tasks
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;
```

---

### Validate Deployment Status

Use the validation stored procedure:

```sql
CALL SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_VALIDATE_PIPELINE();
```

**Expected output (no data yet):**
```json
{
  "timestamp": "2024-11-04 10:30:00",
  "raw_rows": 0,
  "staging_rows": 0,
  "fact_rows": 0,
  "stream_has_data": "false",
  "tasks_running": 2,
  "dim_users": 5,
  "dim_zones": 5
}
```

**Or run comprehensive validation:**
```sql
@sql/02_validation/validate_pipeline.sql
```

---

## Pipeline Architecture

### Data Flow

```
                    ┌─────────────────────────────────────┐
                    │   REST API (Snowpipe Streaming)    │
                    └─────────────────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │  RAW_INGESTION.RAW_BADGE_EVENTS                            │
    │  - badge_id, user_id, zone_id, reader_id                   │
    │  - event_timestamp, signal_strength, direction             │
    │  - PIPE: sfe_badge_events_pipe (transforms on insert)      │
    └────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │  RAW_INGESTION.sfe_badge_events_stream                     │
    │  - CDC stream tracks all changes                           │
    │  - Consumed by tasks every 1 minute                        │
    └────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │  TASK: sfe_raw_to_staging_task (1 min schedule)            │
    │  - Deduplicates events using QUALIFY ROW_NUMBER()          │
    │  - Inserts into staging layer                              │
    └────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │  STAGING_LAYER.STG_BADGE_EVENTS                            │
    │  - Deduplicated, clean events                              │
    │  - Primary key: (badge_id, event_timestamp)                │
    │  - Transient table (1-day retention)                       │
    └────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │  TASK: sfe_staging_to_analytics_task (dependent)           │
    │  - Joins with dimensions (DIM_USERS, DIM_ZONES)            │
    │  - Enriches with business logic (after-hours, weekend)     │
    │  - Inserts into fact table                                 │
    └────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │  ANALYTICS_LAYER.FCT_ACCESS_EVENTS                         │
    │  - Fully enriched access events                            │
    │  - Clustered by event_date for query performance           │
    │  - Ready for dashboards and analytics                      │
    └────────────────────────────────────────────────────────────┘
```

---

## Key Objects Reference

### Tables

| Table | Schema | Type | Purpose |
|-------|--------|------|---------|
| `RAW_BADGE_EVENTS` | RAW_INGESTION | Permanent | Snowpipe Streaming target |
| `STG_BADGE_EVENTS` | STAGING_LAYER | Transient | Deduplicated staging |
| `DIM_USERS` | ANALYTICS_LAYER | Permanent | User dimension (Type 2 SCD) |
| `DIM_ZONES` | ANALYTICS_LAYER | Permanent | Zone/location dimension |
| `DIM_READERS` | ANALYTICS_LAYER | Permanent | RFID reader metadata |
| `FCT_ACCESS_EVENTS` | ANALYTICS_LAYER | Permanent | Access events fact table |

### Pipes

| Pipe | Schema | Target Table | Transformation |
|------|--------|--------------|----------------|
| `sfe_badge_events_pipe` | RAW_INGESTION | RAW_BADGE_EVENTS | Type casting, signal quality logic |

### Streams

| Stream | Source Table | Consumers |
|--------|--------------|-----------|
| `sfe_badge_events_stream` | RAW_BADGE_EVENTS | sfe_raw_to_staging_task |

### Tasks

| Task | Schedule | Condition | Action |
|------|----------|-----------|--------|
| `sfe_raw_to_staging_task` | 1 minute | SYSTEM$STREAM_HAS_DATA | Dedupe & insert to staging |
| `sfe_staging_to_analytics_task` | Dependent | After first task | Enrich & insert to fact |

---

## Troubleshooting

### "Task creation failed: Insufficient privileges"

**Solution:** Ensure you're using `SYSADMIN` or a role with task creation privileges:
```sql
USE ROLE SYSADMIN;
-- Re-run deployment
```

### "Table already exists"

**This is OK!** All scripts use `CREATE OR REPLACE`, so they're idempotent and safe to re-run.

### "Tasks not starting"

**Check task state:**
```sql
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;
```

**If state is "suspended", manually resume:**
```sql
ALTER TASK SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_raw_to_staging_task RESUME;
ALTER TASK SNOWFLAKE_EXAMPLE.STAGING_LAYER.sfe_staging_to_analytics_task RESUME;
```

### "Stream shows as invalid"

**Solution:** Recreate the stream:
```sql
@sql/01_setup/01_core_setup.sql
-- This will recreate the stream
```

---

## What's Next?

✅ **Pipeline deployed!** All infrastructure is now in place.

**Next steps:**
1. **Configure JWT authentication** → Continue to [`03-CONFIGURATION.md`](03-CONFIGURATION.md)
2. **Run the simulator** → See [`04-RUNNING.md`](04-RUNNING.md)
3. **Monitor pipeline health** → See [`05-MONITORING.md`](05-MONITORING.md)

---

## Cleanup (Optional)

To remove all deployed objects:

```sql
-- Teardown entire pipeline
@sql/99_cleanup/teardown_all.sql

-- Or just suspend tasks (keep data)
@sql/99_cleanup/teardown_tasks_only.sql
```

**Note:** This follows the cleanup rule - drops schema-level objects but leaves `SNOWFLAKE_EXAMPLE` database in place for audit/reuse.

---

## Additional Resources

- [Snowflake Streams Documentation](https://docs.snowflake.com/en/user-guide/streams-intro)
- [Snowflake Tasks Documentation](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Snowpipe Streaming API](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)
- [`ARCHITECTURE.md`](ARCHITECTURE.md) - Detailed design decisions
- [`DATA_DICTIONARY.md`](DATA_DICTIONARY.md) - Complete table schemas

