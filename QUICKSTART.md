# Snowflake-Native Quick Start (5 Minutes, Browser Only)

**Zero local setup required!** This guide runs the entire RFID Badge Tracking demo from Snowflake Workspaces using Git integration.

---

## 🎯 What You'll Accomplish

1. Connect this GitHub repository to Snowflake
2. Deploy the complete pipeline (database, pipe, tables, streams, tasks)
3. Configure JWT authentication with Snowflake secrets
4. Run the simulator notebook to send 1000 events via REST API
5. Validate data flowing through all pipeline layers

**Total time: ~5 minutes** (all in browser, zero installs)

---

## 📋 Prerequisites

- Snowflake account (trial works!)
- Role with `CREATE DATABASE` and `CREATE API INTEGRATION` privileges
- Warehouse (default `COMPUTE_WH` is fine, or create your own)

> **Note on Snowflake UI:** As of September 2025, Snowflake has migrated from "Worksheets" to "Workspaces" (GA). This guide uses the current terminology. Navigation is now: **Projects → Workspaces**.

---

## 🚀 Step-by-Step Instructions

### Step 1: Add Public Repository to Snowflake (1 min)

**No authentication needed!** Since this is a public repository, Snowflake can clone it directly via HTTPS.

1. Open Snowsight UI (your Snowflake account home)
2. Click **Projects** → **Workspaces** → **+ SQL File**
3. Copy/paste the entire contents of `sql/00_git_setup/01_git_repository_setup.sql`
4. Click **Run All** (▶▶)

**Note:** The repository URL is pre-configured to `https://github.com/sfc-gh-miwhitaker/sfe-simple-stream` - no changes needed! The `sfe-` prefix helps identify this as a demo project.

**Expected output:**
```
✅ API Integration created: GIT_API_INTEGRATION
✅ Database created: SNOWFLAKE_EXAMPLE
✅ Schema created: GIT_REPOS
✅ Repository cloned: SIMPLE_STREAM_REPO (read-only)
✅ Files visible: sql/, notebooks/, examples/, README.md, etc.
```

**What just happened?**
- Snowflake cloned the public GitHub repo via HTTPS
- Repository is **read-only** (you can't push changes, only read files)
- You can fetch latest updates anytime with: `ALTER GIT REPOSITORY simple_stream_repo FETCH;`

---

### Step 2: Configure Authentication Secrets (1 min)

#### 2a. Generate RSA Key Pair (if you don't have one)

**Option A: Use Snowflake SQL File (Recommended)**
```sql
-- Generate key pair and register public key
CALL SYSTEM$GENERATE_RSA_KEYPAIR('RSA_2048');

-- Get the public key
SELECT SYSTEM$GET_RSA_PUBLIC_KEY() AS public_key;

-- Register public key with your user
ALTER USER <YOUR_USERNAME> SET RSA_PUBLIC_KEY = '<paste_public_key_here>';

-- Get the private key (save this securely - you'll need it in step 2b)
SELECT SYSTEM$GET_RSA_PRIVATE_KEY() AS private_key;
```

**Option B: Use OpenSSL Locally**
```bash
# See config/jwt_keypair_setup.md for detailed instructions
openssl genrsa -out rsa_key.p8 2048
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
# Then register public key as shown above
```

#### 2b. Create Snowflake Secrets

1. Open a new SQL file in Workspaces
2. Copy/paste contents of `sql/00_git_setup/02_configure_secrets.sql`
3. Update the placeholder values:
   - Line 44: Your account identifier (e.g., `MYORG-ACCOUNT123`)
   - Line 51: Your username (e.g., `DEMO_USER`)
   - Lines 62-65: Your full private key (including headers)
4. Click **Run All**

**Expected output:**
```
✅ 3 secrets created: RFID_ACCOUNT, RFID_USER, RFID_JWT_PRIVATE_KEY
✅ Secrets accessible to SYSADMIN role
```

**Verify public key is registered:**
```sql
DESC USER <YOUR_USERNAME>;
-- Look for RSA_PUBLIC_KEY_FP populated
```

---

### Step 3: Deploy Pipeline (1 min)

**Option A: Use Stored Procedure (Easiest)**
```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.DEPLOY_PIPELINE();
```

**Option B: Execute SQL Directly**
1. Open new SQL file in Workspaces
2. Copy/paste contents of `sql/00_git_setup/03_deploy_from_git.sql`
3. Click **Run All**

**Expected output:**
```
✅ Step 1/9: Database and schemas created
✅ Step 2/9: RAW_BADGE_EVENTS table created
✅ Step 3/9: BADGE_EVENTS_PIPE created
✅ Step 4/9: STG_BADGE_EVENTS table created
✅ Step 5/9: Dimension tables created
✅ Step 6/9: FCT_ACCESS_EVENTS table created
✅ Step 7/9: raw_badge_events_stream created
✅ Step 8/9: Tasks created and resumed
✅ Step 9/9: Monitoring views created

🎉 PIPELINE DEPLOYED SUCCESSFULLY!
```

**Verify deployment:**
```sql
CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.VALIDATE_PIPELINE();
```

You should see:
```
📊 PIPELINE VALIDATION REPORT
════════════════════════════════════════════════════════════════

DATA LAYER                  | ROW COUNT  | STATUS
────────────────────────────────────────────────────────────────
RAW_BADGE_EVENTS            |          0 | ⚠️  Empty
STG_BADGE_EVENTS            |          0 | ⏳ Processing
FCT_ACCESS_EVENTS           |          0 | ⏳ Processing

════════════════════════════════════════════════════════════════

PIPELINE OBJECTS:
  Stream (CDC): ✅ Empty (all processed)
  Tasks Running: 2/2
  Pipe Status: Running

⚠️  PIPELINE STATUS: NO DATA
No events ingested yet. Run simulator or send test data.
```

---

### Step 4: Run Simulator Notebook (1 min)

1. In Snowsight, click **Projects** → **Notebooks**
2. Click **+ Notebook** → **From Git Repository**
3. Select:
   - Repository: `SNOWFLAKE_EXAMPLE.GIT_REPOS.STREAMING_INGEST_REPO`
   - Branch: `main`
   - File: `notebooks/RFID_Simulator.ipynb`
4. Click **Create Notebook**
5. Select warehouse: `COMPUTE_WH` (or your warehouse)
6. Click **Run All** (▶▶)

**Watch the magic happen:**
```
✅ Libraries imported successfully
✅ Configuration loaded for account: YOUR_ACCOUNT
✅ JWT authentication initialized
✅ Snowpipe Streaming client initialized
✅ Event generator initialized

======================================================================
🚀 Starting RFID Badge Event Simulation
======================================================================

📡 Step 1: Getting control plane hostname...
   Control host: <your_control_host>

🔓 Step 2: Opening streaming channel 'rfid_channel_1730750000'...
   ✅ Channel 'rfid_channel_1730750000' opened
   Ingest host: <your_ingest_host>

📤 Step 3: Sending 1000 events via REST API...
   Batch 1/10: 100 events sent | Total: 100 | Rate: 1000 events/sec
   Batch 2/10: 100 events sent | Total: 200 | Rate: 1050 events/sec
   ...
   Batch 10/10: 100 events sent | Total: 1000 | Rate: 1020 events/sec

======================================================================
✅ Simulation Complete!
   Events sent: 1000
   Duration: 0.98 seconds
   Average rate: 1020 events/sec
======================================================================

🔍 Validating data pipeline...
   Waiting 5 seconds for ingestion to complete...

📊 Pipeline Status:
   ==================================================================
   Layer                | Row Count | Status
   ------------------------------------------------------------------
   RAW                  |     1,000 | ✅ Data received
   STAGING              |     1,000 | ✅ Processed
   ANALYTICS            |     1,000 | ✅ Transformed
   ==================================================================
   Stream Status: ✅ Empty (all processed)

   ✅ SUCCESS! REST API ingestion is working!
   Data flowed: REST API → Snowpipe → RAW table
   ✅ BONUS! Complete pipeline validated!
   Data flowed: RAW → Streams → Tasks → STAGING → ANALYTICS
```

---

### Step 5: Explore the Data (<1 min)

In a SQL file in Workspaces, run:

```sql
-- View transformed events in analytics layer
SELECT * 
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
ORDER BY event_timestamp DESC
LIMIT 100;

-- Check dimension tables
SELECT * FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS LIMIT 10;
SELECT * FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_ZONES LIMIT 10;

-- View pipeline health dashboard
SELECT * FROM SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.V_PIPELINE_HEALTH;

-- Check task execution history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  DATABASE_NAME => 'SNOWFLAKE_EXAMPLE'
))
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;
```

---

## 🎯 What You Just Demonstrated

### Snowflake-Native Architecture:
- ✅ **Git Integration** - Repository cloned directly into Snowflake
- ✅ **Snowpipe Streaming REST API** - Direct HTTP POST ingestion
- ✅ **JWT Authentication** - Secure key-pair auth via Snowflake Secrets
- ✅ **Snowflake Notebooks** - Python + `requests` library calling REST API
- ✅ **Streams & Tasks** - Event-driven CDC pipeline
- ✅ **Zero External Infrastructure** - No Kafka, no middleware, pure Snowflake

### Key Capabilities Proven:
1. **High-throughput ingestion**: 1000+ events/sec via REST API
2. **Low latency**: <10 seconds from POST to queryable analytics
3. **Automated pipeline**: Stream → Task → Transform (no manual intervention)
4. **Enterprise security**: Encrypted secrets, RBAC, audit trails
5. **Browser-only deployment**: Zero local tools required

---

## 📚 Next Steps

### Test with External Tools

Try the curl examples from the README:

```bash
# Get JWT token
export JWT_TOKEN=$(curl ... )

# Send events
curl -X POST -H "Authorization: Bearer ${JWT_TOKEN}" \
  https://<ingest_host>/v2/streaming/.../channels/my_channel:insert-rows \
  -d '{"rows": [...]}'
```

### Customize the Pipeline

1. **Modify event schema**: Edit `sql/01_setup/01_core_setup.sql` (RAW_BADGE_EVENTS table)
2. **Add transformations**: Update `sql/01_setup/01_core_setup.sql` (pipe definition with new columns)
3. **Create dashboards**: Use Snowsight to visualize `FCT_ACCESS_EVENTS`
4. **Add data quality checks**: Review `sql/04_data_quality/dq_checks.sql`

### Production Deployment

See `config/jwt_keypair_setup.md` for:
- Key rotation schedules
- Minimal privilege grants
- Audit query templates
- High-availability recommendations

---

## 🧹 Cleanup (Optional)

To remove all objects and start fresh:

```sql
-- Option A: Use stored procedure
CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.RESET_PIPELINE();

-- Option B: Execute teardown script
-- (Copy/paste contents of sql/99_cleanup/teardown_all.sql)

-- Option C: Drop entire database
DROP DATABASE SNOWFLAKE_EXAMPLE CASCADE;
```

**Note:** The `RESET_PIPELINE()` procedure preserves the `GIT_REPOS` schema and secrets, making re-deployment faster.

---

## 🆘 Troubleshooting

### Issue: "Object does not exist or not authorized"
**Solution:** Ensure you're using the correct role and warehouse in your SQL file:
```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;
```

### Issue: "API Integration not allowed"
**Solution:** Your account admin needs to enable external access:
```sql
USE ROLE ACCOUNTADMIN;
SHOW API INTEGRATIONS;
-- If git_api_integration is not enabled, re-run step 1
```

### Issue: "Invalid JWT token"
**Solution:** Verify public key is registered:
```sql
DESC USER <YOUR_USERNAME>;
-- RSA_PUBLIC_KEY_FP should be populated
-- If not, re-run "ALTER USER ... SET RSA_PUBLIC_KEY = '...';"
```

### Issue: "Tasks not running"
**Solution:** Resume tasks manually:
```sql
ALTER TASK SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.process_raw_to_staging RESUME;
ALTER TASK SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.process_staging_to_analytics RESUME;
```

### Issue: "No data in analytics table"
**Solution:** Check stream and task status:
```sql
-- Check if stream has data
SELECT SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_badge_events_stream');

-- Check task history
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(DATABASE_NAME => 'SNOWFLAKE_EXAMPLE'))
ORDER BY SCHEDULED_TIME DESC LIMIT 5;
```

---

## 🌟 Success Criteria

You've completed the quick start if you can answer "YES" to:

- [ ] Git repository cloned into Snowflake (`SHOW GIT REPOSITORIES`)
- [ ] Secrets created and readable (`SHOW SECRETS`)
- [ ] Pipeline deployed (9 tables, 1 pipe, 1 stream, 2 tasks)
- [ ] Simulator notebook ran successfully (1000 events sent)
- [ ] Data visible in analytics layer (`SELECT COUNT(*) FROM FCT_ACCESS_EVENTS > 0`)
- [ ] Tasks showing "started" state (`SHOW TASKS`)

**All "YES"? Congratulations!** 🎉 You've deployed a production-grade streaming pipeline with zero local setup!

---

## 📖 Additional Resources

- **Architecture Deep Dive**: See `docs/ARCHITECTURE.md`
- **REST API Reference**: See `docs/REST_API_GUIDE.md`
- **Monitoring Guide**: See `docs/05-MONITORING.md`
- **Local Development**: See `QUICKSTART_LOCAL.md` (for Python development)

---

**Questions or feedback?** Open an issue on GitHub or contact your Snowflake representative.

