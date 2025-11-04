/*******************************************************************************
 * Simple Streaming Pipeline - Complete Deployment
 * 
 * PURPOSE: Deploy complete Snowpipe Streaming pipeline from Git in one command
 * DEPLOYS: Git integration + infrastructure + analytics + tasks + monitoring
 * TIME: 45 seconds
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Git Integration & Database
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Example projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO;

USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION SFE_GIT_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream';

-- ============================================================================
-- STEP 2: Deploy Pipeline from Git
-- ============================================================================

EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/01_core.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/02_analytics.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/03_tasks.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/04_monitoring.sql;

-- ============================================================================
-- VALIDATION
-- ============================================================================

SELECT 'Schemas' AS object, COUNT(*) AS count, IFF(COUNT(*)=4, '✓', '✗') AS ok
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE CATALOG_NAME = 'SNOWFLAKE_EXAMPLE' 
  AND SCHEMA_NAME IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER', 'DEMO_REPO')
UNION ALL
SELECT 'Tasks', COUNT(*), IFF(COUNT(*)=2, '✓', '✗')
FROM INFORMATION_SCHEMA.TASKS 
WHERE TASK_SCHEMA = 'RAW_INGESTION'
UNION ALL
SELECT 'Views', COUNT(*), IFF(COUNT(*)>=7, '✓', '✗')
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'RAW_INGESTION'
ORDER BY object;

-- ============================================================================
-- DEPLOYMENT COMPLETE - Share this with your data provider
-- ============================================================================

SELECT '
================================================================================
  API CONFIGURATION FOR DATA PROVIDER
================================================================================

ENDPOINT:
  https://' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE/insertRows

AUTHENTICATION:
  Username:     sfe_ingest_user
  Role:         sfe_ingest_role  
  Private Key:  rsa_key.p8 (provided separately)
  Method:       Key Pair JWT (token expires in 1 hour)

--------------------------------------------------------------------------------
API REQUEST FORMAT
--------------------------------------------------------------------------------

Method: POST

Headers:
  Authorization: Bearer <your_jwt_token>
  Content-Type: application/json

Body (JSON):
{
  "badge_id": "BADGE-001",
  "user_id": "USR-001",
  "zone_id": "ZONE-LOBBY-1",
  "reader_id": "RDR-101",
  "event_timestamp": "2024-11-04T10:30:00",
  "signal_strength": -65.5,
  "direction": "ENTRY"
}

REQUIRED FIELDS:
  badge_id           STRING      Unique badge identifier
  user_id            STRING      User identifier  
  zone_id            STRING      Zone/location identifier
  reader_id          STRING      RFID reader identifier
  event_timestamp    STRING      ISO 8601 format (e.g., "2024-11-04T10:30:00")

OPTIONAL FIELDS:
  signal_strength    NUMBER      RSSI in dBm (e.g., -65.5)
  direction          STRING      "ENTRY" or "EXIT"

--------------------------------------------------------------------------------
PYTHON EXAMPLE
--------------------------------------------------------------------------------

import jwt
import datetime
from cryptography.hazmat.primitives import serialization

# Load private key (rsa_key.p8)
with open("rsa_key.p8", "rb") as key_file:
    private_key = serialization.load_pem_private_key(
        key_file.read(), password=None
    )

# Generate JWT token
account = "' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '"
username = "sfe_ingest_user"
qualified_username = f"{account}.{username}"

token = jwt.encode(
    {
        "iss": f"{qualified_username}.SHA256:<public_key_fingerprint>",
        "sub": qualified_username,
        "iat": datetime.datetime.utcnow(),
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=1)
    },
    private_key,
    algorithm="RS256"
)

# Send data to Snowflake
import requests
response = requests.post(
    "https://' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE/insertRows",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    json={
        "badge_id": "BADGE-001",
        "user_id": "USR-001",
        "zone_id": "ZONE-LOBBY-1",
        "reader_id": "RDR-101",
        "event_timestamp": "2024-11-04T10:30:00",
        "signal_strength": -65.5,
        "direction": "ENTRY"
    }
)

print(f"Status: {response.status_code}")
print(f"Response: {response.text}")

================================================================================
Documentation: https://docs.snowflake.com/en/developer-guide/sql-api/authenticating
================================================================================
' AS API_CONFIGURATION;
