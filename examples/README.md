# Snowpipe Streaming Examples

Working examples demonstrating how to send data to your Snowflake pipe using JWT authentication.

## Quick Start

### 1. Get Credentials

Run the API handoff script in Snowflake:

```sql
@sql/07_api_handoff.sql
```

This outputs your `ACCOUNT_ID` and complete configuration.

### 2. Place Private Key

Copy `rsa_key.p8` (generated in `sql/06_configure_auth.sql`) to this directory:

```bash
examples/
  ├── rsa_key.p8          # Your private key (DO NOT COMMIT)
  ├── send_events.sh      # Unix/Mac demo
  ├── send_events.bat     # Windows demo
  └── send_events_impl.py # Shared Python code
```

### 3. Configure Script

Edit `send_events.sh` (or `send_events.bat` on Windows) and update:

```bash
ACCOUNT_ID="YOUR_ORG-YOUR_ACCOUNT"  # e.g., "SFSENORTHAMERICA-MWHITAKER_AWS"
```

### 4. Run Demo

**Unix/Mac:**
```bash
chmod +x send_events.sh
./send_events.sh
```

**Windows:**
```cmd
send_events.bat
```

## What It Does

The demo script:

1. **Validates prerequisites** - Checks Python, dependencies, private key
2. **Generates JWT token** - Creates 59-minute token using private key
3. **Sends 3 sample events** - Demonstrates actual data ingestion
4. **Shows results** - HTTP status codes and troubleshooting tips

### Sample Output

```
================================================================
Snowpipe Streaming Event Sender
================================================================

✓ Python 3 found: Python 3.11.5
✓ Private key found: ./rsa_key.p8
✓ Account ID: SFSENORTHAMERICA-MWHITAKER_AWS

================================================================
Initializing Authentication
================================================================

✓ JWT token generated (expires: 14:32:15)

================================================================
Sending Sample Events
================================================================

✓ Event 1/3: BADGE-001 -> ZONE-LOBBY-1 (HTTP 200)
✓ Event 2/3: BADGE-002 -> ZONE-OFFICE-A (HTTP 200)
✓ Event 3/3: BADGE-001 -> ZONE-OFFICE-A (HTTP 200)

================================================================
Summary
================================================================
Successfully sent: 3/3 events

Next Steps:
  1. Wait 1-2 minutes for data to arrive
  2. Query in Snowflake:
     SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS;

  3. Check metrics:
     SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS;
```

## Using in Production

The `send_events_impl.py` file contains production-ready code you can adapt:

### SnowpipeAuthManager Class

```python
# Initialize once at application startup
auth = SnowpipeAuthManager(
    private_key_path="rsa_key.p8",
    account_id="YOUR_ORG-YOUR_ACCOUNT",
    username="sfe_ingest_user"
)

# Use in your data ingestion loop
def send_event(event_data):
    token = auth.get_token()  # Auto-refreshes if needed
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    response = requests.post(endpoint, json=event_data, headers=headers)
    return response
```

### Key Features

- **Thread-safe**: Uses locking for concurrent access
- **Auto-refresh**: Regenerates token 5 minutes before expiry
- **Performance**: Token generated once per hour, not per API call
- **Zero downtime**: No service interruption during token refresh

## Troubleshooting

### Error: "Invalid JWT token"

- Verify `ACCOUNT_ID` format: `ORG-ACCOUNT` (uppercase, with hyphen)
- Ensure public key is registered: Run `SHOW USERS LIKE 'sfe_ingest_user'` in Snowflake
- Check token expiry: Token is valid for 59 minutes

### Error: "HTTP 403 Forbidden"

- User doesn't have INSERT privilege on pipe
- Run in Snowflake: `SHOW GRANTS TO ROLE sfe_ingest_role;`
- Should see: `INSERT` on `SFE_BADGE_EVENTS_PIPE`

### Error: "HTTP 404 Not Found"

- Pipe endpoint URL is incorrect
- Verify pipe exists: `SHOW PIPES IN SCHEMA RAW_INGESTION;`
- Check spelling: `SFE_BADGE_EVENTS_PIPE` (case-sensitive)

### Events Not Appearing in Table

- Wait 1-2 minutes for micro-batch processing
- Check pipe status: `SELECT SYSTEM$PIPE_STATUS('SFE_BADGE_EVENTS_PIPE');`
- Review errors: `SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY());`

## Security Notes

**DO NOT commit `rsa_key.p8` to version control**

Add to `.gitignore`:
```
examples/rsa_key.p8
*.p8
*.pem
```

**Store private key securely:**
- Production: Use key vault (AWS Secrets Manager, Azure Key Vault, etc.)
- Development: Keep in encrypted storage, restricted file permissions
- Rotation: Regenerate keys every 90 days

## Dependencies

```bash
pip install PyJWT cryptography requests
```

- `PyJWT`: JWT token generation
- `cryptography`: RSA key handling
- `requests`: HTTP client for API calls

## Next Steps

After successfully running the demo:

1. Adapt `send_events_impl.py` for your data source
2. Implement error handling and retry logic
3. Add logging and monitoring
4. Set up key rotation process
5. Deploy to production environment

## Support

- **Snowflake Documentation**: https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming
- **JWT Authentication**: https://docs.snowflake.com/en/developer-guide/sql-api/authenticating
- **Project Issues**: Contact your Snowflake administrator

