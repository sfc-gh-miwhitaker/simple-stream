# Snowpipe Streaming REST API Guide

Complete reference for using Snowflake's native Snowpipe Streaming REST API to ingest RFID badge events.

## Overview

The Snowpipe Streaming REST API (GA September 2025) provides a native HTTP interface for high-performance data ingestion directly into Snowflake with no external infrastructure required.

### Key Benefits

- **Native Integration**: Built into Snowflake platform
- **High Performance**: Up to 10 GB/sec per table
- **Low Latency**: <10 seconds ingest-to-query
- **Cost Efficient**: Throughput-based pricing (credits per GB)
- **Server-Side Processing**: Schema validation and transformations in PIPE object

## Authentication

### JWT with RSA Key-Pair

All API requests require JWT token authentication using RS256 algorithm.

**Generate JWT Token (bash):**
See [`docs/03-CONFIGURATION.md`](docs/03-CONFIGURATION.md) for shell-friendly commands to export `JWT_TOKEN` using your key pair.

**Token Properties**:
- Algorithm: RS256
- Max Expiration: 60 minutes
- Format: `Bearer <token>`

## API Workflow

### Complete 4-Step Process

```
1. Get Control Hostname
   ↓
2. Open Channel  
   ↓
3. Insert Rows (repeat)
   ↓
4. Check Channel Status
```

## Step 1: Get Control Plane Hostname

**Endpoint**: `GET /v2/streaming/hostname`

**Request**:
```bash
curl -X GET \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  "https://${ACCOUNT}.snowflakecomputing.com/v2/streaming/hostname"
```

**Response**:
```json
{
  "hostname": "abc123.snowflakecomputing.com"
}
```

**Use**: The `hostname` becomes your control plane URL for subsequent requests.

## Step 2: Open Streaming Channel

**Endpoint**: `POST /v2/streaming/databases/{db}/schemas/{schema}/pipes/{pipe}:open-channel`

**Request**:
```bash
CONTROL_HOST="https://abc123.snowflakecomputing.com"

curl -X POST \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json" \
  "${CONTROL_HOST}/v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/STAGE_BADGE_TRACKING/pipes/BADGE_EVENTS_PIPE:open-channel" \
  -d '{
    "channel_name": "rfid_channel_001"
  }'
```

**Response**:
```json
{
  "ingest_host": "ingest.abc123.snowflakecomputing.com",
  "scoped_token": "ey...(long token)...==",
  "continuation_token": "ct_abc123",
  "offset_token": "ot_xyz789"
}
```

**Important Fields**:
- `ingest_host`: Use this hostname for data ingestion
- `scoped_token`: Use this token (not JWT) for insert operations
- `continuation_token`: Include in insert requests
- `offset_token`: Tracks ingestion position

**Notes**:
- Channel names must be unique per PIPE
- Channels remain open for reuse
- Scoped tokens are channel-specific

## Step 3: Insert Rows

**Endpoint**: `POST /v2/streaming/databases/{db}/schemas/{schema}/pipes/{pipe}/channels/{channel}:insert-rows`

**Request**:
```bash
INGEST_HOST="https://ingest.abc123.snowflakecomputing.com"
SCOPED_TOKEN="ey...(from open-channel response)"
CONTINUATION_TOKEN="ct_abc123"

curl -X POST \
  -H "Authorization: Bearer ${SCOPED_TOKEN}" \
  -H "Content-Type: application/json" \
  "${INGEST_HOST}/v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/STAGE_BADGE_TRACKING/pipes/BADGE_EVENTS_PIPE/channels/rfid_channel_001:insert-rows" \
  -d '{
    "rows": [
      {
        "badge_id": "BADGE-12345",
        "user_id": "USR-001",
        "zone_id": "ZONE-LOBBY-1",
        "reader_id": "RDR-101",
        "event_timestamp": "2025-10-31T14:23:45.123Z",
        "signal_strength": -45.5,
        "direction": "ENTRY"
      },
      {
        "badge_id": "BADGE-67890",
        "user_id": "USR-002",
        "zone_id": "ZONE-OFFICE-2A",
        "reader_id": "RDR-201",
        "event_timestamp": "2025-10-31T14:23:46.456Z",
        "signal_strength": -38.2,
        "direction": "ENTRY"
      }
    ],
    "continuation_token": "ct_abc123"
  }'
```

**Response**:
```json
{
  "status": "success",
  "continuation_token": "ct_abc456",
  "offset_token": "ot_xyz012"
}
```

**Important Notes**:
- **Max Request Size**: 16 MB per POST
- **Optimal Batch Size**: 10-16 MB (compressed)
- **Timestamp Format**: ISO 8601 with 'Z' suffix (UTC)
- **Update Tokens**: Use new continuation_token in next request

### Data Format

**JSON Row Structure**:
```json
{
  "badge_id": "string (max 50 chars)",
  "user_id": "string (max 50 chars)",
  "zone_id": "string (max 50 chars)",
  "reader_id": "string (max 50 chars)",
  "event_timestamp": "ISO 8601 timestamp",
  "signal_strength": "number (optional)",
  "direction": "ENTRY | EXIT (optional)"
}
```

**PIPE Transformations Applied**:
- Type casting with `TRY_TO_TIMESTAMP_NTZ`
- Default handling with `COALESCE`
- Standardization with `UPPER(direction)`
- Enrichment: `signal_quality` calculated from `signal_strength`
- Validation: Rows with null `badge_id`, `user_id`, or `event_timestamp` rejected

## Step 4: Check Channel Status

**Endpoint**: `POST /v2/streaming/databases/{db}/schemas/{schema}/pipes/{pipe}:bulk-channel-status`

**Request**:
```bash
curl -X POST \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json" \
  "${CONTROL_HOST}/v2/streaming/databases/SNOWFLAKE_EXAMPLE/schemas/STAGE_BADGE_TRACKING/pipes/BADGE_EVENTS_PIPE:bulk-channel-status" \
  -d '{
    "channel_names": ["rfid_channel_001"]
  }'
```

**Response**:
```json
{
  "channel_statuses": {
    "rfid_channel_001": {
      "status": "OPEN",
      "last_insert_time": "2025-10-31T14:30:00.000Z",
      "rows_inserted": 1500,
      "bytes_inserted": 45000
    }
  }
}
```

## Error Handling

### Common Errors

**401 Unauthorized**:
```json
{
  "error": "Invalid or expired JWT token"
}
```
**Solution**: Regenerate JWT token (expires after 60 minutes)

**404 Not Found**:
```json
{
  "error": "Pipe BADGE_EVENTS_PIPE not found"
}
```
**Solution**: Verify pipe exists and database/schema/pipe names are correct

**400 Bad Request**:
```json
{
  "error": "Invalid JSON format in request body"
}
```
**Solution**: Validate JSON structure and field types

**413 Payload Too Large**:
```json
{
  "error": "Request payload exceeds 16 MB limit"
}
```
**Solution**: Reduce batch size

### Retry Strategy

```python
import time
import requests

def insert_with_retry(url, headers, payload, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = requests.post(url, headers=headers, json=payload)
            
            if response.status_code == 200:
                return response.json()
            
            if response.status_code == 429:  # Rate limit
                time.sleep(2 ** attempt)  # Exponential backoff
                continue
            
            if response.status_code >= 500:  # Server error
                time.sleep(1)
                continue
            
            response.raise_for_status()
            
        except requests.RequestException as e:
            if attempt == max_retries - 1:
                raise
            time.sleep(1)
    
    raise RuntimeError("Max retries exceeded")
```

## Performance Best Practices

### Batching

**Optimal Batch Size**: 100-1000 rows or 10-16 MB
```python
BATCH_SIZE = 100

for i in range(0, len(events), BATCH_SIZE):
    batch = events[i:i+BATCH_SIZE]
    client.insert_rows(batch)
```

### Throughput Optimization

1. **Parallel Channels**: Open multiple channels for higher throughput
2. **Async Requests**: Use async HTTP client for concurrent POSTs
3. **Connection Pooling**: Reuse HTTP connections

### Latency Optimization

1. **Small Batches**: Smaller batches = lower latency (but more overhead)
2. **Regional Proximity**: Deploy client near Snowflake region
3. **Network Quality**: Use reliable, low-latency network

## Monitoring

### Query Snowflake Views

```sql
-- Real-time channel status
SELECT * FROM V_CHANNEL_STATUS;

-- Ingestion metrics
SELECT * FROM V_INGESTION_METRICS;

-- Verify data
SELECT COUNT(*) FROM RAW_BADGE_EVENTS;
```

### Channel History Function

```sql
SELECT *
FROM TABLE(
  SNOWFLAKE.INFORMATION_SCHEMA.CHANNEL_HISTORY(
    PIPE_NAME => 'SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.BADGE_EVENTS_PIPE',
    TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
  )
);
```

## Cost Estimation

### Pricing Model

**Throughput-Based**: ~0.01 credits per GB (uncompressed)

**Example Calculation**:
```
Event Size: 150 bytes (avg)
Events/day: 8,640,000 (100 events/sec)
Daily Volume: 1.21 GB uncompressed
Daily Cost: ~0.012 credits
Monthly Cost: ~0.36 credits
```

### Cost Optimization

1. **Compression**: JSON compression reduces network transfer
2. **Batch Efficiency**: Larger batches reduce API overhead
3. **Data Filtering**: Filter in PIPE object to reduce stored volume

## Complete Example Scripts

1. Source environment variables (see [`docs/03-CONFIGURATION.md`](docs/03-CONFIGURATION.md))

## Security Considerations

1. **Never log tokens**: JWT and scoped tokens are sensitive
2. **Use HTTPS**: All requests must use TLS 1.2+
3. **Rotate keys**: Rotate RSA keys every 90-180 days
4. **Limit permissions**: Grant minimum required privileges to user

## Troubleshooting

### Connection Issues

```bash
# Test connectivity
curl -I https://${ACCOUNT}.snowflakecomputing.com

# Verify DNS resolution
nslookup ${ACCOUNT}.snowflakecomputing.com
```

### Authentication Issues

```sql
-- Verify public key registered
DESC USER your_username;

-- Check for RSA_PUBLIC_KEY_FP (fingerprint)
```

### Data Not Appearing

```sql
-- Check pipe status
SHOW PIPES;

-- Check for errors
SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(...));

-- Verify stream has data
SELECT SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream');

-- Check task status
SHOW TASKS;
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(...));
```

## Additional Resources

- [Official Snowpipe Streaming Docs](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming)
- [REST API Reference](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api)
- See [`docs/VENDOR_INTEGRATION.md`](docs/VENDOR_INTEGRATION.md) for production deployment guide.


See [`docs/03-CONFIGURATION.md`](docs/03-CONFIGURATION.md) for detailed instructions on exporting JWT tokens for use with `curl`.

