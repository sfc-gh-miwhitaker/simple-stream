# JWT Key-Pair Authentication Setup Guide

This guide walks through setting up key-pair authentication for Snowflake Snowpipe Streaming REST API.

## Overview

Snowflake uses JWT (JSON Web Token) authentication with RSA key pairs for secure API access. You need:
1. An RSA private key (kept secure on your system)
2. A public key (registered with Snowflake)

## Step 1: Generate RSA Key Pair

### Option A: Using OpenSSL (Recommended)

```bash
# For development: Generate unencrypted private key
openssl genrsa -out private_key.pem 2048

# For production: Generate encrypted private key with passphrase (RECOMMENDED)
openssl genrsa -aes256 -out private_key.pem 2048
# You'll be prompted to enter a passphrase - remember it!

# Generate public key from private key
openssl rsa -in private_key.pem -pubout -out public_key.pem
# If encrypted, you'll need to enter the passphrase
```

### Option B: Using Python

```python
from python.simulator.auth import generate_keypair

# Generate key pair
private_path, public_path = generate_keypair(output_dir="./config")

# This will print the public key in format needed for Snowflake
```

## Step 2: Extract Public Key for Snowflake

Snowflake requires the public key as a single line without headers/footers:

```bash
# Extract public key content (remove headers/footers and newlines)
cat public_key.pem | grep -v "BEGIN PUBLIC KEY" | grep -v "END PUBLIC KEY" | tr -d '\n'
```

Copy the output (single line of base64 text).

## Step 3: Register Public Key with Snowflake

Connect to Snowflake using SnowSQL or Snowsight and run:

```sql
-- Replace YOUR_USERNAME with your actual username
-- Replace <public_key_content> with the single-line public key from Step 2
ALTER USER YOUR_USERNAME SET RSA_PUBLIC_KEY='<public_key_content>';

-- Verify registration
DESC USER YOUR_USERNAME;
-- Look for RSA_PUBLIC_KEY_FP (fingerprint) to confirm it's set
```

## Step 4: Configure Environment

Update `config/.env`:

```bash
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=YOUR_USERNAME
SNOWFLAKE_PRIVATE_KEY_PATH=./config/private_key.pem

# If you used encrypted key with passphrase (REQUIRED for production):
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=your_passphrase_here
```

**Important Notes**:
- If you generated an **encrypted** key (with `-aes256`), you **MUST** set the passphrase
- If you generated an **unencrypted** key, leave `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` commented out or unset
- Never commit the `.env` file - it's already in `.gitignore`

## Step 5: Test Authentication

```bash
# Test JWT token generation
python -c "
from python.simulator.auth import SnowflakeAuth
auth = SnowflakeAuth(
    account='your_account',
    user='YOUR_USERNAME',
    private_key_path='./config/private_key.pem'
)
token = auth.generate_jwt_token()
print('JWT Token generated successfully!')
print(f'Token length: {len(token)} characters')
"
```

## Security Best Practices

1. **Never commit private keys to version control**
   - The `.gitignore` already excludes `*.pem` files
   - Store private keys securely (e.g., password manager, vault)

2. **Use encrypted private keys in production**
   ```bash
   openssl genrsa -aes256 -out private_key.pem 2048
   ```

3. **Set appropriate file permissions**
   ```bash
   chmod 600 private_key.pem  # Owner read/write only
   ```

4. **Rotate keys regularly**
   - Generate new key pair every 90-180 days
   - Update Snowflake with new public key
   - Replace private key in deployment

5. **Use separate keys per environment**
   - Development key
   - Staging key
   - Production key

---

## Production & Enterprise Security

### For Multi-Partner & Production Deployments

When deploying to production or managing multiple vendor integrations, follow these enhanced guidelines:

#### Credential Isolation
- Issue **one service user + RSA key pair per partner per environment**
- Never reuse production keys across environments
- Create separate service accounts for each RFID vendor

#### Secure Key Storage
Store keys in managed secrets vaults:
- ✅ HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager
- ❌ Never: Git, shared drives, email, unencrypted storage

#### Minimal Privileges
```sql
-- Example: Create streaming-only role
CREATE ROLE RFID_STREAMING_ROLE;
GRANT OPERATE, MONITOR ON PIPE BADGE_EVENTS_PIPE TO ROLE RFID_STREAMING_ROLE;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE RFID_STREAMING_ROLE;
GRANT ROLE RFID_STREAMING_ROLE TO USER RFID_SERVICE_USER;
```

Do NOT grant: ACCOUNTADMIN, SYSADMIN, CREATE/ALTER/DROP, or SELECT on tables.

#### Key Rotation Schedule
- **Recommended**: Every 90 days
- **Minimum**: Every 180 days
- **After incident**: Immediately

```sql
-- Rotate public key
DESC USER RFID_SERVICE_USER;  -- View current keys
ALTER USER RFID_SERVICE_USER SET RSA_PUBLIC_KEY='<new_key>';
```

#### Audit & Monitor
```sql
-- Check authentication attempts
SELECT user_name, is_success, error_code, event_timestamp
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE user_name = 'RFID_SERVICE_USER'
ORDER BY event_timestamp DESC;
```

Set up alerts for:
- Failed auth attempts (> 5/hour)
- Unexpected IP addresses
- Off-hours operations

---

## Troubleshooting

### "Failed to load private key"
- Verify file exists: `ls -la config/private_key.pem`
- Check file permissions: Should be readable by your user
- Verify PEM format: Should start with `-----BEGIN PRIVATE KEY-----`

### "Authentication failed"
- Verify public key is registered: `DESC USER your_username;`
- Check account identifier format (no `.snowflakecomputing.com`)
- Verify username matches exactly (case-sensitive)

### "JWT token expired"
- Tokens expire after 60 minutes
- The simulator automatically generates fresh tokens
- For manual testing, regenerate token before each use

## Additional Resources

- [Snowflake Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth.html)
- [Snowpipe Streaming REST API](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming.html)

