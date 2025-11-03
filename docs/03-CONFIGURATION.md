# 03 - Configuration & Authentication

**Goal:** Configure JWT authentication and environment settings.

**Time:** ~5 minutes

**Previous:** [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md) | **Next:** [`04-RUNNING.md`](04-RUNNING.md)

---

## Overview

Configure secure key-pair authentication and environment variables for the RFID simulator to communicate with Snowflake's Snowpipe Streaming REST API.

---

## Prerequisites

- ✅ Completed [02-DEPLOYMENT.md](02-DEPLOYMENT.md)
- ✅ OpenSSL installed (macOS/Linux: built-in, Windows: via Git Bash or manual install)

---

## Step 1: Generate RSA Key Pair

Use OpenSSL (or an equivalent tool) to generate your key pair. The commands below work on macOS, Linux, Windows Git Bash, and WSL.

### Manual Generation (All Platforms)

**For Development (Unencrypted):**
```bash
# Generate 2048-bit RSA private key
openssl genrsa -out config/rsa_key.p8 2048

# Extract public key
openssl rsa -in config/rsa_key.p8 -pubout -out config/rsa_key.pub
```

**For Production (Encrypted - Recommended):**
```bash
# Generate encrypted private key with passphrase
openssl genrsa -aes256 -out config/rsa_key.p8 2048
# You'll be prompted for a passphrase - remember it!

# Extract public key (will prompt for passphrase)
openssl rsa -in config/rsa_key.p8 -pubout -out config/rsa_key.pub
```

### Windows Users

If `openssl` is not available:

1. **Install Git for Windows** (includes OpenSSL)
2. **Use Git Bash** to run the commands above
3. **Or download OpenSSL:** [slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html)

---

## Step 2: Extract Public Key for Snowflake

Snowflake needs the public key as a single line without headers:

**macOS/Linux:**
```bash
cat config/rsa_key.pub | grep -v "BEGIN PUBLIC KEY" | grep -v "END PUBLIC KEY" | tr -d '\n'
```

**Windows (PowerShell):**
```powershell
Get-Content config\rsa_key.pub | Select-String -Pattern "BEGIN|END" -NotMatch | ForEach-Object { $_.Line.Trim() } | Join-String
```

**Copy the output** - it should be a long string of base64 characters.

---

## Step 3: Register Public Key with Snowflake

Connect to Snowflake (Snowsight or CLI) and run:

```sql
-- Replace YOUR_USERNAME with your actual Snowflake username
-- Replace <public_key_content> with the string from Step 2
ALTER USER YOUR_USERNAME SET RSA_PUBLIC_KEY='<public_key_content>';

-- Verify registration
DESC USER YOUR_USERNAME;
```

**Expected Output:**
Look for `RSA_PUBLIC_KEY_FP` field - it should show a fingerprint value.

---

## Step 4: Configure Environment File

### Create Configuration File

```bash
# Windows
copy config\.env.example config\.env

# macOS/Linux
cp config/.env.example config/.env
```

### Edit config/.env

Open `config/.env` in your text editor and configure:

```ini
# ============================================================================
# Snowflake Connection
# ============================================================================

# Account identifier (format: ORGNAME-ACCOUNTNAME)
# Example: MYORG-AWS_PROD
# NOT: myorg-aws.snowflakecomputing.com
SNOWFLAKE_ACCOUNT=YOUR_ACCOUNT_HERE

# Your Snowflake username
SNOWFLAKE_USER=YOUR_USERNAME_HERE

# Database (should match deployment)
SNOWFLAKE_DATABASE=SNOWFLAKE_EXAMPLE

# Schema for raw ingestion
SNOWFLAKE_SCHEMA=STAGE_BADGE_TRACKING

# Snowpipe Streaming object name
SNOWFLAKE_PIPE=BADGE_EVENTS_PIPE

# ============================================================================
# Authentication
# ============================================================================

# Path to private key (relative or absolute)
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8

# Passphrase (ONLY if you encrypted the key - remove if unencrypted)
# SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=your_passphrase_here

# ============================================================================
# Streaming Configuration
# ============================================================================

# Channel name (unique identifier for streaming session)
CHANNEL_NAME=rfid_channel_001

# Events per second (throughput)
EVENTS_PER_SECOND=200

# Simulation duration in days
SIMULATION_DURATION_DAYS=10

# Batch size (rows per API request)
BATCH_SIZE=100

# ============================================================================
# Data Generation
# ============================================================================

# Number of unique users to simulate
NUM_USERS=500

# Number of unique zones
NUM_ZONES=50

# Number of badge readers
NUM_READERS=25
```

### Important Notes

✅ **Account Format:** `ORGNAME-ACCOUNTNAME` (no `.snowflakecomputing.com`)  
✅ **Paths:** Use forward slashes `/` on all platforms (works on Windows too)  
✅ **Passphrase:** Only set if you encrypted the key  
❌ **Never commit:** `.env` file is in `.gitignore` - keep it secret!

---

## Step 5: Test Authentication

Verify your configuration:

```bash
python -c "
from python.simulator.auth import SnowflakeAuth
from python.simulator.config import Config

config = Config()
auth = SnowflakeAuth(
    account=config.snowflake_account,
    user=config.snowflake_user,
    private_key_path=config.private_key_path,
    private_key_passphrase=config.private_key_passphrase
)

token = auth.generate_jwt_token()
print('✓ JWT Token generated successfully!')
print(f'  Token length: {len(token)} characters')
"
```

**Expected Output:**
```
✓ JWT Token generated successfully!
  Token length: 450+ characters
```

---

## Configuration Reference

### Required Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `SNOWFLAKE_ACCOUNT` | `MYORG-AWS` | Account identifier |
| `SNOWFLAKE_USER` | `jdoe` | Your username |
| `SNOWFLAKE_PRIVATE_KEY_PATH` | `config/rsa_key.p8` | Path to private key |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SNOWFLAKE_DATABASE` | `SNOWFLAKE_EXAMPLE` | Target database |
| `SNOWFLAKE_SCHEMA` | `STAGE_BADGE_TRACKING` | Landing schema |
| `SNOWFLAKE_PIPE` | `BADGE_EVENTS_PIPE` | Pipe name |
| `CHANNEL_NAME` | `rfid_channel_001` | Stream channel ID |
| `EVENTS_PER_SECOND` | `200` | Throughput rate |
| `BATCH_SIZE` | `100` | Rows per request |

---

## Security Best Practices

### ✅ DO

- **Encrypt private keys** in production (`-aes256`)
- **Use strong passphrases** (16+ characters)
- **Set restrictive permissions:**
  ```bash
  chmod 600 config/rsa_key.p8
  ```
- **Rotate keys regularly** (every 90 days recommended)
- **Store keys in secure vault** for production (e.g., AWS Secrets Manager)

### ❌ DON'T

- **Never commit** `.env` or private keys to Git
- **Don't share** private keys via email/Slack
- **Don't use** unencrypted keys in production
- **Don't hardcode** credentials in source code

---

## Troubleshooting

### Issue: "Failed to load private key"

**Cause:** File not found or incorrect path

**Solution:**
```bash
# Verify file exists
ls -la config/rsa_key.p8

# Check path in .env (use absolute path if needed)
SNOWFLAKE_PRIVATE_KEY_PATH=/absolute/path/to/config/rsa_key.p8
```

### Issue: "Bad decrypt" or "Passphrase required"

**Cause:** Encrypted key but no passphrase provided

**Solution:**
```ini
# Add to .env
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=your_passphrase
```

### Issue: "Authentication failed"

**Cause:** Public key not registered or mismatch

**Solution:**
```sql
-- Verify in Snowflake
DESC USER your_username;

-- Re-register if needed
ALTER USER your_username SET RSA_PUBLIC_KEY='...';
```

### Issue: "Invalid account identifier"

**Cause:** Wrong format (includes .snowflakecomputing.com)

**Solution:**
```ini
# Wrong
SNOWFLAKE_ACCOUNT=myorg-aws.snowflakecomputing.com

# Correct
SNOWFLAKE_ACCOUNT=MYORG-AWS
```

---

## Next Steps

✅ **Authentication configured!**

Continue to:
👉 **[04-RUNNING.md](04-RUNNING.md)** - Run the simulator and validate data flow

---

## Additional Resources

- **Full Key Setup:** [`config/jwt_keypair_setup.md`](../config/jwt_keypair_setup.md)
- **Platform Help:** [`PLATFORM_GUIDE.md`](PLATFORM_GUIDE.md)
- **REST API Details:** [`REST_API_GUIDE.md`](REST_API_GUIDE.md)

---

**Guide:** 03-CONFIGURATION | ← [02-DEPLOYMENT](02-DEPLOYMENT.md) | [04-RUNNING](04-RUNNING.md) →

