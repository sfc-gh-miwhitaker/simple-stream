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

### Option B: Using Python (cryptography library)

```python
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from pathlib import Path

# Generate RSA key pair
private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048
)

# Save private key
private_pem = private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)
Path("./config/rsa_key.p8").write_bytes(private_pem)

# Save public key
public_key = private_key.public_key()
public_pem = public_key.public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo
)
Path("./config/rsa_key.pub").write_bytes(public_pem)

print("✅ Key pair generated: ./config/rsa_key.p8 and ./config/rsa_key.pub")
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

Test JWT token generation using the Jupyter Notebook:

1. Open `notebooks/RFID_Simulator.ipynb` in Snowflake
2. Execute Cell 2 (Load secrets) and Cell 3 (JWT Authentication)
3. Verify you see "✅ JWT authentication initialized"

The notebook contains the complete SnowflakeAuth class implementation with JWT token generation.

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

