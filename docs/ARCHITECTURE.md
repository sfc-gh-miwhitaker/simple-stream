# Architecture Guide

## Overview

This reference implementation demonstrates a production-grade RFID badge tracking system using Snowflake's native Snowpipe Streaming REST API with **zero external infrastructure**.

### Key Design Principles

1. **Native Snowflake**: 100% in Snowflake - no external services to deploy
2. **In-Flight Transformations**: Clean and enrich data during ingestion in PIPE object
3. **CDC-Based Pipeline**: Stream + Task pattern for near-real-time processing
4. **Dimensional Modeling**: Star schema with Type 2 SCD dimensions
5. **Query Optimization**: Clustering and pruning for time-series queries

## System Architecture

```
┌─────────────────────┐
│   RFID Vendor       │
│  System/Simulator   │
└──────────┬──────────┘
           │ HTTP POST (JWT auth)
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Snowflake Platform                       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Snowpipe Streaming REST API                         │  │
│  │  (Native Endpoint - No External Infrastructure)      │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     ▼                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  PIPE Object: badge_events_pipe                      │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  In-Flight Transformations:                    │  │  │
│  │  │  - Type casting (TRY_TO_TIMESTAMP_NTZ)         │  │  │
│  │  │  - Default handling (COALESCE)                 │  │  │
│  │  │  - Standardization (UPPER, TRIM)               │  │  │
│  │  │  - Enrichment (signal_quality CASE)            │  │  │
│  │  │  - Validation (WHERE filters)                  │  │  │
│  │  │  - Audit trail (CURRENT_TIMESTAMP, raw JSON)   │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     ▼                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         RAW Layer (STAGE_BADGE_TRACKING)             │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  RAW_BADGE_EVENTS (Permanent Table)            │  │  │
│  │  │  - Append-only landing zone                    │  │  │
│  │  │  - Full audit trail with raw JSON              │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     │ CDC: Stream captures changes          │
│                     ▼                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  raw_badge_events_stream                             │  │
│  │  (Tracks INSERT operations, adds METADATA$ columns)  │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     │ Triggered every 1 minute when data    │
│                     ▼ available (SYSTEM$STREAM_HAS_DATA)   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Task 1: raw_to_staging_task                         │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  Processing:                                   │  │  │
│  │  │  - Consume stream (METADATA$ACTION = INSERT)   │  │  │
│  │  │  - Deduplicate with QUALIFY                    │  │  │
│  │  │    (ROW_NUMBER partitioned by badge + time)    │  │  │
│  │  │  - Insert into staging                         │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     ▼                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     TRANSFORM Layer (TRANSFORM_BADGE_TRACKING)       │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  STG_BADGE_EVENTS (Transient Table)            │  │  │
│  │  │  - Deduplicated, clean data                    │  │  │
│  │  │  - No Fail-safe (cost optimization)            │  │  │
│  │  │  - 1-day retention                             │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     │ After Task 1 completes               │
│                     ▼                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Task 2: staging_to_analytics_task                   │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  Processing:                                   │  │  │
│  │  │  1. MERGE new users into DIM_USERS             │  │  │
│  │  │     (Type 2 SCD updates)                       │  │  │
│  │  │  2. INSERT into FCT_ACCESS_EVENTS              │  │  │
│  │  │     (with dimension lookups)                   │  │  │
│  │  │  3. Calculate derived attributes               │  │  │
│  │  │     (is_after_hours, is_weekend, etc.)         │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     ▼                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     ANALYTICS Layer (ANALYTICS_BADGE_TRACKING)       │  │
│  │                                                      │  │
│  │  ┌────────────────────────┐  ┌──────────────────┐  │  │
│  │  │  DIM_USERS              │  │  DIM_ZONES       │  │  │
│  │  │  - Type 2 SCD           │  │  - Property      │  │  │
│  │  │  - Effective dates      │  │    layout        │  │  │
│  │  │  - is_current flag      │  │  - Readers       │  │  │
│  │  └────────────────────────┘  └──────────────────┘  │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  FCT_ACCESS_EVENTS (Clustered on event_date)  │  │  │
│  │  │  - Foreign keys to dimensions                  │  │  │
│  │  │  - Measures (signal strength, quality)         │  │  │
│  │  │  - Derived flags (after hours, weekend)        │  │  │
│  │  │  - Optimized for time-series queries           │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Monitoring Views (V_CHANNEL_STATUS, V_METRICS, etc) │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Layers

### 1. Ingestion Layer (PIPE Object)

**Purpose**: Centralize ingestion logic with in-flight transformations

**Key Features**:
- Server-side schema validation
- Type casting with error handling (TRY_TO_TIMESTAMP_NTZ)
- Default value handling (COALESCE for nulls)
- Data standardization (UPPER for direction)
- Business logic enrichment (signal_quality calculation)
- Audit trail preservation (ingestion_time, raw_json)

**Benefits**:
- Reduces client-side complexity
- Ensures consistent data quality at entry point
- Single point of maintenance for ingestion logic

### 2. Raw Layer (RAW_BADGE_EVENTS)

**Purpose**: Immutable, append-only landing zone

**Table Type**: Permanent (with Time Travel and Fail-safe)

**Key Features**:
- Complete audit trail
- Raw JSON preserved for replay/debugging
- No transformations after PIPE
- Source for Stream-based CDC

**Retention**: Default 1-day Time Travel

### 3. Transform Layer (STG_BADGE_EVENTS)

**Purpose**: Deduplicated, validated staging area

**Table Type**: Transient (no Fail-safe = cost savings)

**Key Features**:
- Deduplication using QUALIFY
- Additional validation
- Optimized for rebuild from source

**Retention**: 1-day (can be 0 for high-volume scenarios)

### 4. Analytics Layer (Star Schema)

**Purpose**: Optimized dimensional model for analytics

**Components**:

**DIM_USERS** (Type 2 SCD):
- Tracks user attribute changes over time
- `effective_start_date`, `effective_end_date`
- `is_current` flag for active records

**DIM_ZONES**:
- Property layout hierarchy
- Reader information
- Zone attributes (capacity, security requirements)

**FCT_ACCESS_EVENTS** (Clustered):
- Grain: One row per badge scan
- Foreign keys to dimensions
- Measures: signal_strength, etc.
- Derived attributes: is_after_hours, is_weekend
- **Clustering**: `CLUSTER BY (TO_DATE(event_timestamp))`

## CDC Pipeline Pattern

### Stream-Based Change Capture

```sql
CREATE STREAM raw_badge_events_stream 
ON TABLE RAW_BADGE_EVENTS;
```

**How it works**:
1. Stream tracks all DML operations on source table
2. Adds metadata columns: `METADATA$ACTION`, `METADATA$ISUPDATE`, `METADATA$ROW_ID`
3. Task queries stream for unconsumed changes
4. Upon successful commit, stream offset advances

### Event-Driven Task Execution

```sql
CREATE TASK raw_to_staging_task
  SCHEDULE = '1 MINUTE'
WHEN SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream')
AS ...
```

**Benefits**:
- Tasks only run when data available (cost optimization)
- Near-real-time processing (1-minute schedule)
- Guaranteed exactly-once processing (transaction commits)

## Clustering Strategy

### Why Cluster on DATE (not TIMESTAMP)?

```sql
ALTER TABLE FCT_ACCESS_EVENTS 
CLUSTER BY (TO_DATE(event_timestamp));
```

**Rationale**:
1. **Lower Cardinality**: DATE has fewer distinct values than TIMESTAMP
2. **Query Patterns**: Most queries filter by date ranges
3. **Pruning Efficiency**: Better micro-partition pruning
4. **Cost**: Lower clustering maintenance costs

### Monitoring Clustering Health

```sql
SELECT SYSTEM$CLUSTERING_INFORMATION('FCT_ACCESS_EVENTS');
```

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| **Ingestion Throughput** | Up to 10 GB/sec per table | Snowpipe Streaming REST API limit |
| **Ingest-to-Query Latency** | <10 seconds | Typical with high-performance architecture |
| **Task Execution Frequency** | 1 minute | Configurable based on requirements |
| **Deduplication Method** | QUALIFY (single-pass) | More efficient than subquery/CTE |
| **Clustering Overhead** | Automatic | Managed by Snowflake |

## Cost Optimization

### Table Type Strategy

| Layer | Table Type | Rationale |
|-------|------------|-----------|
| Raw | Permanent | Audit trail, disaster recovery |
| Staging | Transient | Rebuildable, no Fail-safe needed |
| Analytics | Permanent | Core business data |

### Storage Savings

- **Transient Tables**: No 7-day Fail-safe = ~20% storage savings
- **Time Travel**: 1-day default (vs 90-day) = significant savings
- **Clustering**: Reduces scan volume = compute savings

### Compute Optimization

- **Warehouse Auto-Suspend**: 60 seconds (aggressive for cost)
- **Stream-Triggered Tasks**: Only run when data available
- **Batch Processing**: 1-minute schedule balances latency and efficiency

## Scalability Considerations

### Horizontal Scaling

- **Multiple Channels**: Open parallel channels for higher throughput
- **Partition by Zone**: Separate pipes per building/floor
- **Multi-Cluster Warehouses**: Scale out task execution for high concurrency

### Vertical Scaling

- **Warehouse Size**: Increase for faster task execution
- **Batch Size**: Tune based on network and API limits (max 16 MB)

## Security Architecture

### Authentication

- **JWT with Key-Pair**: RSA 2048-bit minimum
- **Token Expiration**: 59 minutes (max 60)
- **Scoped Tokens**: Channel-specific tokens from open-channel response

### Authorization

- **RBAC**: Role-based access to database objects
- **PIPE Permissions**: `USAGE` on pipe for ingestion
- **API Keys**: Optional for additional authentication layer

### Data Protection

- **Encryption**: All data encrypted at rest and in transit (TLS 1.2+)
- **PII Masking**: Can apply dynamic masking policies to dimensions
- **Row-Level Security**: Can implement RLS on analytics tables

## Monitoring and Observability

### Key Metrics

1. **Ingestion Health**: `V_CHANNEL_STATUS`
2. **Throughput**: `V_INGESTION_METRICS`
3. **Latency**: `V_END_TO_END_LATENCY`
4. **Data Quality**: Data quality check queries
5. **Task Performance**: `V_TASK_EXECUTION_HISTORY`

### Alerting Strategy

- **Ingestion Stopped**: No data for >5 minutes
- **High Latency**: End-to-end >5 minutes
- **Task Failures**: Any task failure
- **Data Quality**: Validation failures >5%

## Disaster Recovery

### Recovery Time Objective (RTO)

- **Stream Replay**: Resume from last committed offset
- **Time Travel**: Query historical data (up to 90 days)
- **Task Resume**: Automatic retry on failure

### Recovery Point Objective (RPO)

- **Near-Zero**: Stream-based CDC ensures minimal data loss
- **Fail-safe**: 7-day Fail-safe for permanent tables

## Next Steps

- **Tuning Guide**: See `TUNING_GUIDE.md` for performance optimization
- **REST API Guide**: See `REST_API_GUIDE.md` for complete API reference
- **Data Dictionary**: See `DATA_DICTIONARY.md` for schema details

