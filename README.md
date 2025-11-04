# Simple Stream

High-speed data ingestion with Snowpipe Streaming, deployed from Git in one command.

## What You Get

A complete streaming pipeline with:
- Snowpipe Streaming REST API endpoint
- Automated CDC tasks (deduplication, enrichment)
- Dimensional model (users, zones, facts)
- Real-time monitoring views

## Deploy (45 seconds)

### Step 1: Deploy Pipeline

```sql
@sql/deploy.sql
```

**Time:** ~45 seconds  
**Result:**
- Database: `SNOWFLAKE_EXAMPLE`
- Pipe: `RAW_INGESTION.SFE_BADGE_EVENTS_PIPE`
- Tasks: Auto-running every 1 minute
- Views: 7 monitoring views
- **API configuration output** (copy and share with data provider)

### Step 2: Configure Authentication

```sql
@sql/configure_auth.sql
```

**Time:** ~5 minutes  
**What it does:**
- Creates service account (`sfe_ingest_user`)
- Grants pipe INSERT privileges
- Guides you through key pair generation
- Registers public key with Snowflake
- Outputs credentials for data provider

## What It Creates

**Data Flow:**
```
REST API → Raw Table → Stream → Tasks → Analytics
```

## Monitor

```sql
-- Live metrics
SELECT * FROM RAW_INGESTION.V_INGESTION_METRICS;

-- Pipeline health
SELECT * FROM RAW_INGESTION.V_END_TO_END_LATENCY;

-- Cost tracking
SELECT * FROM RAW_INGESTION.V_STREAMING_COSTS;
```

## Validate

```sql
@sql/validate.sql
```

Runs comprehensive checks on all pipeline components.

## Cleanup

```sql
@sql/cleanup.sql
```

Removes everything (keeps database for audit).

## How It Works

**The Git Integration Magic:**

1. Script creates Git repository object pointing to this repo
2. Uses `EXECUTE IMMEDIATE FROM @repo/branches/main/sql/...`
3. Snowflake pulls scripts directly from GitHub
4. Deploys complete pipeline

**The Pipeline:**

1. **Ingest**: Snowpipe Streaming writes JSON to `RAW_BADGE_EVENTS`
2. **CDC**: Stream tracks all changes
3. **Dedupe**: Task 1 cleans RAW → STAGING (every minute)
4. **Enrich**: Task 2 joins with dimensions, loads FACT table
5. **Monitor**: Views show metrics, costs, performance

## Architecture

```
┌─────────────────┐
│  REST API Call  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ RAW_BADGE_EVENTS│ ← Pipe transforms JSON
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ sfe_badge_      │ ← Stream tracks changes
│ events_stream   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Task 1          │ ← Runs every 1 min
│ (Dedupe)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ STG_BADGE_EVENTS│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Task 2          │ ← Runs after Task 1
│ (Enrich)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ DIM_USERS       │
│ DIM_ZONES       │
│ FCT_ACCESS      │ ← Analytics ready
│   _EVENTS       │
└─────────────────┘
```

## Files

```
sql/
├── deploy.sql        ← Run this (everything)
├── 01_core.sql       ← Raw table, pipe, stream
├── 02_analytics.sql  ← Dimensions, facts
├── 03_tasks.sql      ← CDC automation
├── 04_monitoring.sql ← Monitoring views
├── validate.sql      ← Comprehensive checks
├── cleanup.sql       ← Remove everything
└── optional/         ← Advanced features
```

## Key Features Demonstrated

1. **Snowpipe Streaming REST API**
   - High-speed ingestion (millions of rows/sec)
   - JSON transformation in pipe
   - Server-side processing

2. **Git-Based Deployment**
   - `EXECUTE IMMEDIATE FROM @repo/...`
   - Version controlled pipeline
   - No manual file uploads

3. **CDC with Streams & Tasks**
   - Automatic change tracking
   - Incremental processing
   - Task DAG (dependent execution)

4. **Dimensional Modeling**
   - Type 2 SCD (slowly changing dimensions)
   - Clustered fact table
   - Seed data for testing

5. **Built-in Monitoring**
   - Ingestion metrics
   - Cost tracking
   - Performance views

## Requirements

- Snowflake account
- ACCOUNTADMIN (for API integration)
- SYSADMIN (for objects)

## Time Investment

- Deploy: 45 seconds
- Learn: 10 minutes (read the 5 SQL files)
- Test: 5 minutes (send data, check views)

Total: 15 minutes to fully understand Snowpipe Streaming.

## What Makes This Different

Most streaming examples are complex. This one is deliberately simple:
- One command deployment
- Minimal objects (only what's needed)
- Clear data flow
- Self-validating
- Easy cleanup

Perfect for learning, demos, and as a template for production pipelines.
