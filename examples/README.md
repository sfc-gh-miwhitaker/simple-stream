# Snowpipe Streaming Demo

This directory provides a minimal, repeatable example of Snowflake's **Snowpipe Streaming (high-performance)** REST API. The helper script generates a JWT from an RSA private key, discovers the ingest host, opens a streaming channel, appends a few badge events, and closes the channel.

## Files

| File | Purpose |
| ---- | ------- |
| `config.example.json` | Template configuration (copy to `config.json` and edit). |
| `send_events_stream.py` | Python helper that calls the streaming REST endpoints. |
| `send_events.sh` / `send_events.bat` | Unix / Windows wrappers that invoke the helper from any directory. |
| `.gitignore` | Keeps local config, keys, and virtual environments out of source control. |

## Prerequisites

- Snowflake account with the demo objects deployed (see `sql/01_core.sql`, `sql/03_tasks.sql`, etc.).
- Service account (e.g. `sfe_ingest_user`) with INSERT privileges on the streaming pipe (`SFE_BADGE_EVENTS_PIPE`).
- RSA 2048-bit key pair (private key stored locally, public key registered on the Snowflake user).
- Python 3.9+ with `pip` (the helper uses `requests`, `PyJWT`, and `cryptography`).

## Quick Start (Unix/macOS)

1. **Generate RSA key pair** (PKCS#8, unencrypted):
   ```bash
   mkdir -p keys
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out keys/rsa_key.p8 -nocrypt
   openssl rsa -in keys/rsa_key.p8 -pubout -outform DER | openssl base64 -A > keys/rsa_key.pub.b64
   ``
2. **Register public key with Snowflake** (copy the single-line base64 string):
   ```bash
   pbcopy < keys/rsa_key.pub.b64  # macOS clipboard helper
   ```
   ```sql
   ALTER USER sfe_ingest_user SET RSA_PUBLIC_KEY = '<paste clipboard here>';
   DESCRIBE USER sfe_ingest_user;  -- note RSA_PUBLIC_KEY_FP
   ```
3. **Create config** from template:
   ```bash
   cp config.example.json config.json
   ```
   Edit `config.json`:
   - `account_host`: e.g. `myorg-myaccount.snowflakecomputing.com`
   - `username`: Snowflake service user (e.g. `SFE_INGEST_USER`)
   - `private_key_path`: relative or absolute path to `rsa_key.p8`
   - `pipe_name`: fully-qualified pipe (e.g. `SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE`)
4. **(Optional) Create virtual environment**:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install requests PyJWT cryptography
   ```
5. **Run the demo**:
   ```bash
   ./send_events.sh
   ```
6. **Verify data** in Snowflake:
   ```sql
   SELECT *
   FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
   ORDER BY ingestion_time DESC
   LIMIT 10;
   ```

## Quick Start (Windows)

1. Generate keys (PowerShell or Git Bash) and copy `keys/rsa_key.pub.b64` content.
2. Register the public key with Snowflake (`ALTER USER ... SET RSA_PUBLIC_KEY = '...'`).
3. Copy `config.example.json` to `config.json` and update the values.
4. (Optional) Create virtual environment:
   ```cmd
   python -m venv .venv
   .venv\Scripts\activate
   pip install requests PyJWT cryptography
   ```
5. Run the wrapper:
   ```cmd
   send_events.bat
   ```
6. Verify the rows in Snowflake as shown above.

## Script Output

A successful run prints:

```
✓ Configuration loaded
✓ Account host: https://<account_host>
✓ Account identifier: <ORG_ACCOUNT>
✓ RSA fingerprint: SHA256:...
✓ JWT generated
✓ Ingest host: https://<ingest_host>
✓ Scoped token acquired
✓ Channel opened: demo_channel_...
✓ Appended 3 events (next token prefix: ...)
✓ Channel closed
```

## Troubleshooting

| Symptom | Action |
| ------- | ------ |
| `RSA fingerprint ...` differs from `DESCRIBE USER` | Run `ALTER USER ... SET RSA_PUBLIC_KEY` again with the single-line base64 output. |
| `SQL API request failed ... JWT token is invalid` | Run `SELECT SYSTEM$GET_LOGIN_FAILURE_DETAILS('<uuid>');` and check for fingerprint or account mismatch. |
| `requests.exceptions.ConnectionError` | Ensure network access to `https://<account_host>` is allowed. |
| `Config file not found` | Copy `config.example.json` to `config.json` and update placeholders. |

## Notes

- The helper sends a short burst of events (default: 3). Adjust `sample_events` in `config.json` to send more.
- Channels are created per run (`channel_name` in config). If a run is interrupted, you can delete the channel manually with `DELETE` or let Snowflake clean it up.
- Keep `rsa_key.p8` secure. Update the Snowflake user key whenever you regenerate the private key.
