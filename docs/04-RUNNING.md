# 04 - Running the Simulator

**Goal:** Send RFID badge events to Snowflake and validate data flow.

**Time:** ~10 minutes

**Previous:** [`03-CONFIGURATION.md`](03-CONFIGURATION.md) | **Next:** [`05-MONITORING.md`](05-MONITORING.md)

---

## Overview

This guide shows you how to:
- ✅ Run the Jupyter Notebook simulator to send events via REST API
- ✅ Validate data arrived in Snowflake
- ✅ Verify end-to-end pipeline processing
- ✅ Send test events via `curl` (optional)

---

## Prerequisites

- ✅ Completed [02-DEPLOYMENT.md](02-DEPLOYMENT.md) (pipeline deployed)
- ✅ Completed [03-CONFIGURATION.md](03-CONFIGURATION.md) (secrets configured)
- ✅ Warehouse available (e.g., `COMPUTE_WH`)

---

## Method 1: Jupyter Notebook (Recommended)

### Step 1: Open the Notebook

1. In Snowsight, navigate to **Projects** → **Notebooks**
2. Click **+ Notebook** → **From Git Repository**
3. Configure:
   - **Repository:** `SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo`
   - **Branch:** `main`
   - **File:** `notebooks/RFID_Simulator.ipynb`
4. Click **Create Notebook**

---

### Step 2: Configure Notebook

1. Select **Warehouse:** `COMPUTE_WH` (or your preferred warehouse)
2. Leave **Python** version as default (3.8 or higher)
3. Click **Start** to initialize the notebook environment

---

### Step 3: Run All Cells

Click **Run All** (▶▶ button at top) to execute all cells sequentially.

**Watch the progression:**

#### Cell 1: Import Libraries
```
✅ Libraries imported successfully
```

#### Cell 2: Load Configuration from Secrets
```
✅ Configuration loaded for account: YOUR_ACCOUNT
   User: YOUR_USER
   Target: SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_badge_events_pipe
```

#### Cell 3: Initialize JWT Authentication
```
✅ JWT authentication initialized
   Token preview: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Cell 4: Initialize Snowpipe Streaming Client
```
✅ Snowpipe Streaming client initialized
```

#### Cell 5: Initialize Event Generator
```
✅ Event generator initialized
   Sample event: {
     "badge_id": "BADGE-00042",
     "user_id": "USR-042",
     ...
   }
```

#### Cell 6: Run Simulation (THIS IS THE MAGIC!)
```
======================================================================
🚀 Starting RFID Badge Event Simulation
======================================================================

📡 Step 1: Getting control plane hostname...
   Control host: your-control-host.snowflakecomputing.com

🔓 Step 2: Opening streaming channel 'rfid_channel_1730750000'...
   ✅ Channel 'rfid_channel_1730750000' opened
   Ingest host: your-ingest-host.snowflakecomputing.com

📤 Step 3: Sending 1000 events via REST API...
   Batch 1/10: 100 events sent | Total: 100 | Rate: 1000 events/sec
   Batch 2/10: 100 events sent | Total: 200 | Rate: 950 events/sec
   Batch 3/10: 100 events sent | Total: 300 | Rate: 980 events/sec
   ...
   Batch 10/10: 100 events sent | Total: 1000 | Rate: 1050 events/sec

======================================================================
✅ Simulation Complete!
   Events sent: 1000
   Duration: 1.23 seconds
   Average rate: 813 events/sec
======================================================================
```

#### Cell 7: Validate Data Arrived
```
🔍 Validating data pipeline...
   Waiting 5 seconds for ingestion to complete...

📊 Pipeline Status:
   ==================================================================
   Layer                | Row Count  | Status
   ------------------------------------------------------------------
   RAW                  |      1,000 | ✅ Data received
   STAGING              |      1,000 | ✅ Processed
   ANALYTICS            |      1,000 | ✅ Transformed
   ==================================================================
   Stream Status: ✅ Empty (all processed)

   ✅ SUCCESS! REST API ingestion is working!
   Data flowed: REST API → Snowpipe → RAW table

   ✅ BONUS! Complete pipeline validated!
   Data flowed: RAW → Streams → Tasks → STAGING → ANALYTICS

📋 Sample Events (first 5):
  BADGE_ID      ZONE_ID         EVENT_TIMESTAMP      EVENT_TYPE
  BADGE-00042   ZONE-OFFICE-2   2024-11-04 10:30:15  ENTRY
  BADGE-00017   ZONE-LOBBY-1    2024-11-04 10:30:16  EXIT
  ...
```

---

### Understanding the Output

**What just happened:**

1. **JWT Token Generated**: Used RS256 algorithm with your private key
2. **Control Host Retrieved**: `GET /v2/streaming/hostname`
3. **Channel Opened**: `POST /v2/streaming/.../pipes/...:open-channel`
4. **Rows Inserted**: `POST /v2/streaming/.../channels/...:insert-rows` (10 batches)
5. **Data Processed**:
   - Snowpipe Streaming → RAW_BADGE_EVENTS (~1 second)
   - Stream captured changes
   - Task processed RAW → STAGING (~60 seconds max)
   - Dependent task processed STAGING → ANALYTICS

**Total latency: ~2-60 seconds** (depending on task schedule)

---

## Method 2: Direct REST API via curl (Advanced)

### Step 1: Generate JWT Token

Use the notebook cell 3 output or generate via SQL:

```sql
-- Note: This example shows the concept; actual JWT generation
-- requires implementing the signing algorithm
SELECT 'Use notebook Cell 3 for JWT generation' AS note;
```

### Step 2: Get Control Host

```bash
ACCOUNT="your-account"
JWT_TOKEN="<your_jwt_token_from_notebook>"

CONTROL_HOST=$(curl -s -X GET \
  "https://${ACCOUNT}.snowflakecomputing.com/v2/streaming/hostname" \
  -H "Authorization: Bearer ${JWT_TOKEN}")

echo "Control host: ${CONTROL_HOST}"
```

### Step 3: Open Channel

```bash
CHANNEL_NAME="test_channel_$(date +%s)"

CHANNEL_RESPONSE=$(curl -s -X POST \
  "https://${CONTROL_HOST}/v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/RAW_INGESTION/pipes/sfe_badge_events_pipe:open-channel" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"channel_name\": \"${CHANNEL_NAME}\"}")

INGEST_HOST=$(echo $CHANNEL_RESPONSE | jq -r '.ingest_host')
SCOPED_TOKEN=$(echo $CHANNEL_RESPONSE | jq -r '.scoped_token')
CONTINUATION_TOKEN=$(echo $CHANNEL_RESPONSE | jq -r '.continuation_token')

echo "Ingest host: ${INGEST_HOST}"
```

### Step 4: Insert Events

```bash
curl -X POST \
  "https://${INGEST_HOST}/v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/RAW_INGESTION/pipes/sfe_badge_events_pipe/channels/${CHANNEL_NAME}:insert-rows" \
  -H "Authorization: Bearer ${SCOPED_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Streaming-Continuation-Token: ${CONTINUATION_TOKEN}" \
  -d '{
    "rows": [
      {
        "badge_id": "BADGE-TEST-001",
        "user_id": "USR-001",
        "zone_id": "ZONE-LOBBY-1",
        "reader_id": "RDR-001",
        "event_timestamp": "2024-11-04T10:30:00.000Z",
        "signal_strength": -45,
        "direction": "ENTRY"
      }
    ]
  }'
```

**See [`REST_API_GUIDE.md`](REST_API_GUIDE.md) for complete API reference.**

---

## Validation Queries

### Quick Check: Row Counts

```sql
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Row counts across all layers
SELECT 'RAW' AS layer, COUNT(*) AS row_count 
FROM RAW_INGESTION.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING' AS layer, COUNT(*) AS row_count 
FROM STAGING_LAYER.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS' AS layer, COUNT(*) AS row_count 
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS;
```

**Expected:** All three layers should show the same count (after tasks complete).

---

### Check Stream Status

```sql
-- Is stream empty? (False = still processing, True = caught up)
SELECT SYSTEM$STREAM_HAS_DATA('RAW_INGESTION.sfe_badge_events_stream') AS has_pending_data;
```

**✅ Expected:** `false` (stream empty = all data processed)
**⏳ If `true`:** Wait 1-2 minutes for tasks to process

---

### View Recent Events

```sql
-- Recent events in analytics layer
SELECT 
    event_timestamp,
    badge_id,
    zone_id,
    direction,
    signal_quality,
    is_after_hours,
    is_weekend
FROM ANALYTICS_LAYER.FCT_ACCESS_EVENTS
ORDER BY event_timestamp DESC
LIMIT 10;
```

---

### Check Task Execution

```sql
-- Recent task runs
SELECT 
    name AS task_name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF('second', scheduled_time, completed_time) AS duration_sec
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 10
))
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC;
```

**Expected:** Tasks show `state = 'SUCCEEDED'`

---

## Comprehensive Validation

Run the full validation script:

```sql
@sql/02_validation/validate_pipeline.sql
```

This executes 16 validation checks including:
- ✅ Row counts across all layers
- ✅ Stream status
- ✅ Task execution history
- ✅ Data completeness (NULL checks)
- ✅ Signal quality distribution
- ✅ After-hours/weekend events
- ✅ Top active badges and zones
- ✅ Ingestion latency analysis

---

## Common Scenarios

### Scenario 1: No Data in RAW Table

**Possible causes:**
1. Notebook cell 6 didn't complete successfully
2. Secrets misconfigured (check cell 2 output)
3. JWT token invalid (check cell 3 output)
4. Pipe not created (re-run deployment)

**Debug:**
```sql
-- Verify pipe exists
SHOW PIPES IN SCHEMA RAW_INGESTION;

-- Check pipe status
DESC PIPE sfe_badge_events_pipe;
```

---

### Scenario 2: Data in RAW but Not STAGING

**Possible causes:**
1. Task not running (suspended)
2. Task schedule not triggered yet (wait 1 minute)
3. Stream has no data

**Debug:**
```sql
-- Check task state
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;

-- If suspended, resume
ALTER TASK RAW_INGESTION.sfe_raw_to_staging_task RESUME;

-- Check stream
SELECT COUNT(*) FROM RAW_INGESTION.sfe_badge_events_stream;
```

---

### Scenario 3: Data in STAGING but Not ANALYTICS

**Possible causes:**
1. Dependent task not running
2. Missing dimension keys (user_id or zone_id not in dimensions)

**Debug:**
```sql
-- Check for missing dimension keys
SELECT DISTINCT s.user_id
FROM STAGING_LAYER.STG_BADGE_EVENTS s
LEFT JOIN ANALYTICS_LAYER.DIM_USERS u 
    ON s.user_id = u.user_id AND u.is_current = TRUE
WHERE u.user_key IS NULL
LIMIT 10;

-- The MERGE logic should auto-create missing users
-- If not, check task execution history for errors
```

---

## Performance Tuning

### Adjust Simulation Parameters

Edit the notebook Cell 6 to customize:

```python
# Default: 1000 events, 100 per batch
events_sent = run_simulation(num_events=1000, batch_size=100)

# Larger volume
events_sent = run_simulation(num_events=10000, batch_size=500)

# Slower rate for debugging
events_sent = run_simulation(num_events=100, batch_size=10)
```

---

### Task Schedule Tuning

```sql
-- Change task to run every 30 seconds instead of 1 minute
ALTER TASK RAW_INGESTION.sfe_raw_to_staging_task 
SET SCHEDULE = '30 SECOND';

-- Or run immediately (for testing)
EXECUTE TASK RAW_INGESTION.sfe_raw_to_staging_task;
```

---

## What's Next?

✅ **Data is flowing!** You've successfully sent events via REST API and validated the pipeline.

**Next steps:**
1. **Monitor pipeline health** → Continue to [`05-MONITORING.md`](05-MONITORING.md)
2. **Create dashboards** → Query `FCT_ACCESS_EVENTS` in Snowsight
3. **Customize the schema** → Edit `sql/01_setup/01_core_setup.sql`
4. **Add data quality checks** → Review `sql/04_data_quality/dq_checks.sql`

---

## Additional Resources

- [`REST_API_GUIDE.md`](REST_API_GUIDE.md) - Complete REST API reference
- [`05-MONITORING.md`](05-MONITORING.md) - Monitoring and troubleshooting
- [`DATA_DICTIONARY.md`](DATA_DICTIONARY.md) - Table schemas and definitions
- [Snowpipe Streaming API Documentation](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)

