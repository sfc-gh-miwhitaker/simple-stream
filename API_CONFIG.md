# Snowpipe Streaming API Configuration

**Generated for:** SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE  
**Purpose:** Provide to data ingestion vendor/team

---

## Account Information

```
Account URL: <your-org>-<your-account>.snowflakecomputing.com
Account ID:  <your-org>-<your-account>
```

**Note:** Run `sql/deploy.sql` to see your actual account values.

---

## Pipe Endpoint

| Property | Value |
|----------|-------|
| Database | `SNOWFLAKE_EXAMPLE` |
| Schema | `RAW_INGESTION` |
| Pipe Name | `SFE_BADGE_EVENTS_PIPE` |
| Fully Qualified | `SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE` |

---

## Authentication

**Method:** OAuth 2.0 or Key Pair JWT  
**Requirements:**
- User must have `INSERT` privilege on the pipe
- Recommend creating dedicated service account
- See: https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview

---

## JSON Message Format

### Example Payload

```json
{
  "badge_id": "BADGE-001",
  "user_id": "USR-001",
  "zone_id": "ZONE-LOBBY-1",
  "reader_id": "RDR-101",
  "event_timestamp": "2024-11-04T10:30:00",
  "signal_strength": -65.5,
  "direction": "ENTRY"
}
```

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `badge_id` | STRING | Unique badge identifier | `"BADGE-001"` |
| `user_id` | STRING | User identifier | `"USR-001"` |
| `zone_id` | STRING | Zone/location identifier | `"ZONE-LOBBY-1"` |
| `reader_id` | STRING | RFID reader identifier | `"RDR-101"` |
| `event_timestamp` | STRING | ISO 8601 timestamp | `"2024-11-04T10:30:00"` |

### Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `signal_strength` | NUMBER | RSSI in dBm | `-65.5` |
| `direction` | STRING | Entry or exit | `"ENTRY"` or `"EXIT"` |

**Notes:**
- All fields are case-sensitive
- Timestamp must be ISO 8601 format (will be converted to `TIMESTAMP_NTZ`)
- Additional fields in JSON will be stored in `raw_json` column
- Missing optional fields will use defaults (`signal_strength` = -999, `direction` = null)

---

## Server-Side Transformations

The pipe automatically applies these transformations:

1. **Signal Quality Calculation:**
   - `< -80 dBm` → "WEAK"
   - `-80 to -60 dBm` → "MEDIUM"  
   - `> -60 dBm` → "STRONG"

2. **Direction Normalization:**
   - Converts to uppercase

3. **Ingestion Timestamp:**
   - Automatically added server-side

---

## Testing

### Test Message

```bash
curl -X POST \
  https://<account>.snowflakecomputing.com/v1/data/pipes/<pipe>/insertRows \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "badge_id": "TEST-001",
    "user_id": "USR-TEST",
    "zone_id": "ZONE-LOBBY-1",
    "reader_id": "RDR-101",
    "event_timestamp": "2024-11-04T10:30:00",
    "signal_strength": -65.5,
    "direction": "ENTRY"
  }'
```

### Verify Ingestion

```sql
-- Check for test data
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS 
WHERE badge_id = 'TEST-001'
ORDER BY ingestion_time DESC 
LIMIT 10;
```

---

## Monitoring Queries

### Ingestion Rate (Last Hour)

```sql
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS
ORDER BY ingestion_hour DESC 
LIMIT 24;
```

### Pipeline Health

```sql
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_END_TO_END_LATENCY;
```

### Error Monitoring

```sql
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_CHANNEL_STATUS;
```

---

## Expected Throughput

- **Latency:** < 2 minutes end-to-end (ingestion → analytics)
- **Tasks:** Run every 1 minute
- **Capacity:** Millions of events per second (Snowpipe Streaming)

---

## Support Contacts

**Snowflake Team:** [Your contact info]  
**Pipeline Owner:** [Your contact info]  
**Monitoring Dashboard:** [Link if available]

---

## Change Log

| Date | Change | Updated By |
|------|--------|------------|
| 2024-11-04 | Initial deployment | Setup script |

---

## Additional Resources

- [Snowpipe Streaming Overview](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)
- [REST API Reference](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-rest)
- [Authentication Guide](https://docs.snowflake.com/en/developer-guide/sql-api/authenticating)

