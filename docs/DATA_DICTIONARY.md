# Data Dictionary

Complete schema documentation for the RFID Badge Tracking system.

## Database: SNOWFLAKE_EXAMPLE

### Schema: STAGE_BADGE_TRACKING

Raw landing zone for badge events ingested via Snowpipe Streaming REST API.

#### Table: RAW_BADGE_EVENTS

**Purpose**: Immutable landing table for all badge scan events

**Table Type**: Permanent  
**Retention**: 1-day Time Travel, 7-day Fail-safe

| Column Name | Data Type | Nullable | Description |
|-------------|-----------|----------|-------------|
| `badge_id` | VARCHAR(50) | NOT NULL | Unique badge identifier (e.g., BADGE-12345) |
| `user_id` | VARCHAR(50) | NOT NULL | User associated with badge (e.g., USR-001) |
| `zone_id` | VARCHAR(50) | NOT NULL | Zone where event occurred (e.g., ZONE-LOBBY-1) |
| `reader_id` | VARCHAR(50) | NOT NULL | Badge reader that captured event (e.g., RDR-101) |
| `event_timestamp` | TIMESTAMP_NTZ | NOT NULL | When badge was scanned (timezone-naive UTC) |
| `signal_strength` | NUMBER(5,2) | NULL | RFID signal strength in dBm (-100 to 0, or -999 for unknown) |
| `signal_quality` | VARCHAR(10) | NULL | Calculated quality: WEAK (<-80), MEDIUM (-80 to -60), STRONG (>-60) |
| `direction` | VARCHAR(10) | NULL | Movement direction: ENTRY, EXIT, or NULL |
| `ingestion_time` | TIMESTAMP_NTZ | NOT NULL | When record was ingested into Snowflake |
| `raw_json` | VARIANT | NULL | Original JSON payload for debugging and replay |

**Primary Key**: None (append-only table)  
**Natural Key**: (`badge_id`, `event_timestamp`)

**Sample Query**:
```sql
SELECT 
    badge_id,
    user_id,
    zone_id,
    event_timestamp,
    signal_quality
FROM RAW_BADGE_EVENTS
WHERE event_timestamp >= CURRENT_DATE()
ORDER BY event_timestamp DESC
LIMIT 100;
```

#### Object: BADGE_EVENTS_PIPE

**Purpose**: PIPE object with in-flight transformations

**Transformations Applied**:
1. Type casting: `TRY_TO_TIMESTAMP_NTZ` for error-tolerant parsing
2. Default handling: `COALESCE(signal_strength, -999)` for nulls
3. Standardization: `UPPER(TRIM(direction))` for consistency
4. Enrichment: `signal_quality` calculated from `signal_strength`
5. Audit: `CURRENT_TIMESTAMP()` for `ingestion_time`
6. Preservation: `PARSE_JSON($1)` for `raw_json`

#### Object: RAW_BADGE_EVENTS_STREAM

**Purpose**: CDC stream for incremental processing

**Type**: Standard Stream  
**Source**: RAW_BADGE_EVENTS  
**Consumer**: raw_to_staging_task

**Metadata Columns**:
- `METADATA$ACTION`: INSERT, UPDATE, DELETE
- `METADATA$ISUPDATE`: Boolean
- `METADATA$ROW_ID`: Unique row identifier

---

### Schema: TRANSFORM_BADGE_TRACKING

Staging layer for deduplication and transformation.

#### Table: STG_BADGE_EVENTS

**Purpose**: Deduplicated staging area

**Table Type**: Transient (no Fail-safe)  
**Retention**: 1-day Time Travel

| Column Name | Data Type | Nullable | Description |
|-------------|-----------|----------|-------------|
| `badge_id` | VARCHAR(50) | NOT NULL | Badge identifier |
| `user_id` | VARCHAR(50) | NOT NULL | User identifier |
| `zone_id` | VARCHAR(50) | NOT NULL | Zone identifier |
| `reader_id` | VARCHAR(50) | NOT NULL | Reader identifier |
| `event_timestamp` | TIMESTAMP_NTZ | NOT NULL | Event timestamp |
| `signal_strength` | NUMBER(5,2) | NULL | Signal strength in dBm |
| `signal_quality` | VARCHAR(10) | NULL | WEAK, MEDIUM, STRONG |
| `direction` | VARCHAR(10) | NULL | ENTRY, EXIT, or NULL |
| `ingestion_time` | TIMESTAMP_NTZ | NOT NULL | Original ingestion time |
| `staging_time` | TIMESTAMP_NTZ | DEFAULT CURRENT_TIMESTAMP() | When added to staging |

**Primary Key**: (`badge_id`, `event_timestamp`)

**Deduplication Logic**:
```sql
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY badge_id, event_timestamp 
    ORDER BY ingestion_time DESC
) = 1
```

---

### Schema: ANALYTICS_BADGE_TRACKING

Dimensional model optimized for analytics.

#### Table: DIM_USERS

**Purpose**: User dimension with Type 2 SCD

**Table Type**: Permanent

| Column Name | Data Type | Nullable | Description |
|-------------|-----------|----------|-------------|
| `user_key` | NUMBER | NOT NULL | Surrogate key (autoincrement) |
| `user_id` | VARCHAR(50) | NOT NULL | Business key |
| `user_name` | VARCHAR(100) | NULL | Full name |
| `user_type` | VARCHAR(20) | NULL | EMPLOYEE, CONTRACTOR, VISITOR, VENDOR |
| `department` | VARCHAR(50) | NULL | Department or organization |
| `email` | VARCHAR(100) | NULL | Email address |
| `phone` | VARCHAR(20) | NULL | Phone number |
| `clearance_level` | VARCHAR(20) | NULL | PUBLIC, CONFIDENTIAL, SECRET |
| `is_active` | BOOLEAN | DEFAULT TRUE | Is user currently active |
| `effective_start_date` | TIMESTAMP_NTZ | NOT NULL | When this version became effective |
| `effective_end_date` | TIMESTAMP_NTZ | NULL | When this version expired (NULL if current) |
| `is_current` | BOOLEAN | DEFAULT TRUE | Is this the current record |
| `created_timestamp` | TIMESTAMP_NTZ | DEFAULT CURRENT_TIMESTAMP() | Record creation time |
| `updated_timestamp` | TIMESTAMP_NTZ | DEFAULT CURRENT_TIMESTAMP() | Last update time |

**Primary Key**: `user_key`  
**Natural Key**: `user_id`  
**Indexes**: `idx_dim_users_user_id`

**Type 2 SCD Query** (current records only):
```sql
SELECT * FROM DIM_USERS WHERE is_current = TRUE;
```

**Type 2 SCD Query** (point-in-time):
```sql
SELECT * FROM DIM_USERS
WHERE user_id = 'USR-001'
  AND effective_start_date <= '2024-01-01'
  AND (effective_end_date IS NULL OR effective_end_date > '2024-01-01');
```

#### Table: DIM_ZONES

**Purpose**: Zone and location dimension

**Table Type**: Permanent

| Column Name | Data Type | Nullable | Description |
|-------------|-----------|----------|-------------|
| `zone_key` | NUMBER | NOT NULL | Surrogate key (autoincrement) |
| `zone_id` | VARCHAR(50) | NOT NULL | Business key |
| `reader_id` | VARCHAR(50) | NULL | Badge reader in this zone |
| `building_name` | VARCHAR(100) | NOT NULL | Building name |
| `floor_number` | NUMBER(3) | NULL | Floor number |
| `zone_name` | VARCHAR(100) | NOT NULL | Zone name (e.g., Main Lobby) |
| `zone_type` | VARCHAR(50) | NULL | LOBBY, OFFICE, CONFERENCE_ROOM, SECURE_AREA, PARKING |
| `capacity` | NUMBER | NULL | Maximum occupancy |
| `requires_clearance` | VARCHAR(20) | NULL | Required clearance level |
| `is_monitored` | BOOLEAN | DEFAULT TRUE | Is zone actively monitored |
| `is_restricted` | BOOLEAN | DEFAULT FALSE | Is access restricted |
| `reader_location` | VARCHAR(100) | NULL | Physical location of reader |
| `reader_type` | VARCHAR(50) | NULL | ENTRY, EXIT, BIDIRECTIONAL |
| `latitude` | NUMBER(10,6) | NULL | Geographic latitude |
| `longitude` | NUMBER(10,6) | NULL | Geographic longitude |
| `created_timestamp` | TIMESTAMP_NTZ | DEFAULT CURRENT_TIMESTAMP() | Record creation time |
| `updated_timestamp` | TIMESTAMP_NTZ | DEFAULT CURRENT_TIMESTAMP() | Last update time |

**Primary Key**: `zone_key`  
**Natural Key**: `zone_id`  
**Indexes**: `idx_dim_zones_reader_id`

#### Table: FCT_ACCESS_EVENTS

**Purpose**: Fact table for access events

**Table Type**: Permanent  
**Clustering**: `CLUSTER BY (event_date)`

| Column Name | Data Type | Nullable | Description |
|-------------|-----------|----------|-------------|
| `event_key` | NUMBER | NOT NULL | Surrogate key (autoincrement) |
| `user_key` | NUMBER | NOT NULL | FK to DIM_USERS |
| `zone_key` | NUMBER | NOT NULL | FK to DIM_ZONES |
| `badge_id` | VARCHAR(50) | NOT NULL | Badge identifier (degenerate dimension) |
| `reader_id` | VARCHAR(50) | NOT NULL | Reader identifier (degenerate dimension) |
| `event_timestamp` | TIMESTAMP_NTZ | NOT NULL | When event occurred |
| `event_date` | DATE | NOT NULL | Event date (clustering key) |
| `event_hour` | NUMBER(2) | NOT NULL | Hour of day (0-23) |
| `event_day_of_week` | NUMBER(1) | NOT NULL | Day of week (0=Sunday) |
| `direction` | VARCHAR(10) | NULL | ENTRY, EXIT, or NULL |
| `signal_strength` | NUMBER(5,2) | NULL | Signal strength in dBm |
| `signal_quality` | VARCHAR(10) | NULL | WEAK, MEDIUM, STRONG |
| `is_restricted_access` | BOOLEAN | NULL | Was this restricted zone access |
| `is_after_hours` | BOOLEAN | NULL | Before 6am or after 10pm |
| `is_weekend` | BOOLEAN | NULL | Saturday or Sunday |
| `ingestion_time` | TIMESTAMP_NTZ | NOT NULL | Original ingestion time |
| `fact_load_time` | TIMESTAMP_NTZ | DEFAULT CURRENT_TIMESTAMP() | When fact was created |

**Primary Key**: `event_key`  
**Foreign Keys**:
- `fk_fct_user`: `user_key` → `DIM_USERS(user_key)`
- `fk_fct_zone`: `zone_key` → `DIM_ZONES(zone_key)`

**Sample Analytics Queries**:

**Daily access count by zone**:
```sql
SELECT 
    z.zone_name,
    f.event_date,
    COUNT(*) as access_count,
    SUM(CASE WHEN f.direction = 'ENTRY' THEN 1 ELSE 0 END) as entries,
    SUM(CASE WHEN f.direction = 'EXIT' THEN 1 ELSE 0 END) as exits
FROM FCT_ACCESS_EVENTS f
JOIN DIM_ZONES z ON f.zone_key = z.zone_key
WHERE f.event_date >= CURRENT_DATE() - 7
GROUP BY z.zone_name, f.event_date
ORDER BY f.event_date, access_count DESC;
```

**After-hours restricted access**:
```sql
SELECT 
    u.user_name,
    z.zone_name,
    f.event_timestamp,
    f.signal_quality
FROM FCT_ACCESS_EVENTS f
JOIN DIM_USERS u ON f.user_key = u.user_key AND u.is_current = TRUE
JOIN DIM_ZONES z ON f.zone_key = z.zone_key
WHERE f.is_after_hours = TRUE
  AND f.is_restricted_access = TRUE
  AND f.event_date = CURRENT_DATE()
ORDER BY f.event_timestamp DESC;
```

---

## Monitoring Views

### V_CHANNEL_STATUS
Real-time channel health and ingestion status.

### V_INGESTION_METRICS
Hourly ingestion metrics for last 24 hours.

### V_END_TO_END_LATENCY
Pipeline latency across all layers.

### V_DATA_FRESHNESS
Data freshness metrics.

### V_PARTITION_EFFICIENCY
Query pruning effectiveness.

### V_STREAMING_COSTS
Cost tracking (credits per GB).

### V_TASK_EXECUTION_HISTORY
Task execution history for last 24 hours.

---

## Data Lineage

```
RFID Vendor → REST API → PIPE (transformations) → RAW_BADGE_EVENTS
                                                       ↓
                                              raw_badge_events_stream
                                                       ↓
                                          raw_to_staging_task (QUALIFY)
                                                       ↓
                                               STG_BADGE_EVENTS
                                                       ↓
                                        staging_to_analytics_task (MERGE)
                                                       ↓
                                      ┌─────────────┴─────────────┐
                                 DIM_USERS                    DIM_ZONES
                                      │                            │
                                      └─────────────┬─────────────┘
                                             FCT_ACCESS_EVENTS
```

## Data Volumes

**Estimated Sizes** (for 10-day simulation, 100 events/sec):

| Table | Rows | Size (Uncompressed) | Size (Compressed) |
|-------|------|---------------------|-------------------|
| RAW_BADGE_EVENTS | 86,400,000 | 12 GB | 3 GB |
| STG_BADGE_EVENTS | 86,400,000 | 10 GB | 2.5 GB |
| FCT_ACCESS_EVENTS | 86,400,000 | 15 GB | 4 GB |
| DIM_USERS | 500 | <1 MB | <1 MB |
| DIM_ZONES | 50 | <1 MB | <1 MB |

**Total Storage**: ~10 GB compressed

---

## Governance

### Data Classification

| Column | Classification | Justification |
|--------|---------------|---------------|
| `user_id`, `user_name`, `email`, `phone` | PII | Personally identifiable |
| `clearance_level` | Confidential | Security-related |
| `zone_id`, `reader_id` | Public | Non-sensitive location data |
| `event_timestamp` | Public | Non-sensitive temporal data |

### Access Control

**Roles**:
- `RFID_ADMIN`: Full access to all objects
- `RFID_ANALYST`: Read-only access to analytics layer
- `RFID_OPERATOR`: Ingestion and monitoring only

**Sample RBAC**:
```sql
-- Create roles
CREATE ROLE RFID_ADMIN;
CREATE ROLE RFID_ANALYST;

-- Grant permissions
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE RFID_ANALYST;
GRANT USAGE ON SCHEMA ANALYTICS_BADGE_TRACKING TO ROLE RFID_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS_BADGE_TRACKING TO ROLE RFID_ANALYST;

-- Apply masking policy (optional)
CREATE MASKING POLICY email_mask AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('RFID_ADMIN') THEN val
    ELSE '***@***'
  END;

ALTER TABLE DIM_USERS MODIFY COLUMN email SET MASKING POLICY email_mask;
```

