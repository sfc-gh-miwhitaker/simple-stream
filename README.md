# Simple Stream

A Snowflake-native demonstration of the **Snowpipe Streaming REST API** using RFID badge tracking as an example. Run the entire demo from your browser with **zero local setup**.

**📦 Repository:** [https://github.com/sfc-gh-miwhitaker/simple-stream](https://github.com/sfc-gh-miwhitaker/simple-stream)

## 🚀 Get Started in 5 Minutes (Browser Only)

**Zero local setup required!** Run the entire demo from Snowflake Workspaces using Git integration.

✅ No Python installation  
✅ No Snowflake CLI  
✅ No local configuration files  
✅ No repository forking or authentication needed (public repo = read-only clone)  
✅ Credentials stored in Snowflake Secrets  
✅ Simulator runs in Snowflake Notebooks  

👉 **[Start Here: QUICKSTART.md](QUICKSTART.md)**

---

**That's it!** Data flows: Raw → Staging → Analytics (via Streams & Tasks). Query in <10 seconds.

See [`docs/REST_API_GUIDE.md`](docs/REST_API_GUIDE.md) for complete API reference and error handling.

---

## Overview

This project demonstrates how to ingest several million RFID badge events over a 10-day period using Snowflake's high-performance streaming architecture (GA September 2025). Perfect for property access control, asset tracking, and real-time location systems.

### Key Features

- **Snowpipe Streaming GA (Sep 2025)**: Direct REST ingestion with continuation tokens, zero middleware
- **Native Snowflake Solution**: 100% in Snowflake - no external services to deploy
- **High Performance**: Up to 10 GB/sec per table, <10 second query latency
- **In-Flight Transformations**: Clean, validate, and enrich data during ingestion
- **Complete Pipeline**: Raw → Staging → Analytics with CDC using Streams and Tasks
- **Production Ready**: Monitoring, data quality checks, real-time dashboards, and comprehensive documentation
- **Enterprise Ready**: Built-in monitoring, Streams + Tasks CDC pattern, and extensible partner onboarding blueprint

### For Enterprise & Partner Deployments

This project doubles as a **customer-partner playbook** for repeatable RFID vendor integrations:

| Phase | Customer Team Owns | Partner/Vendor Owns |
|-------|-------------------|---------------------|
| **0. Success Alignment** | Define access outcomes, SLAs, data retention, compliance tagging | Share deployment constraints, badge schema, sample payloads |
| **1. Foundation** | Execute numbered SQL scripts (`sql/01_setup/`) | N/A |
| **2. Vendor Integration** | Issue Snowflake credentials, configure Snowpipe Streaming pipe | Plug RFID readers into provided REST endpoint, map fields to schema |
| **3. Validation & QA** | Run data-quality checks (`sql/04_data_quality/`) | Provide test payloads, confirm data governance requirements |
| **4. Monitoring & Dashboards** | Create Snowsight worksheets or BI dashboards for security teams | Confirm operational KPIs and alerting thresholds |
| **5. Scale Out** | Define partner onboarding checklist, clone schemas for multi-vendor | Reuse automation scripts and REST endpoints for each location |

**Key Benefits for Enterprise:**
- **<10 second latency** from badge scan to analytics view, meeting real-time security SLAs
- **Zero middleware** - RFID vendors POST directly to Snowflake, eliminating infrastructure management
- **Built-in CDC** - Streams + Tasks pattern keeps compute off until changes arrive, minimizing spend
- **Partner-ready artifacts** - REST API templates, field mappings, simulator, and scaling playbook included
- **Extensible governance** - Add partners by cloning schemas, creating new pipes/channels, reusing tag model

## Quick Start

> **Need a guided walkthrough?** Start with [`QUICKSTART.md`](QUICKSTART.md) for the 5-minute browser-only setup.

### Snowflake-Native Deployment (Browser Only)

1. **Add Public Repository to Snowflake** (1 min)
   - Open Snowsight → Projects → Workspaces → + SQL File
   - Run `sql/00_git_setup/01_git_repository_setup.sql`
   - Repository clones as read-only (no authentication needed)
   
2. **Configure Secrets** (1 min)
   - Generate RSA key pair (see `config/jwt_keypair_setup.md`)
   - Run `sql/00_git_setup/02_configure_secrets.sql`
   
3. **Deploy Pipeline**
   ```sql
   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.DEPLOY_PIPELINE();
   ```
   
4. **Run Simulator Notebook**
   - Projects → Notebooks → Import from Git
   - Select `notebooks/RFID_Simulator.ipynb`
   - Run All
   
5. **Validate**
   ```sql
   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.VALIDATE_PIPELINE();
   ```

**Total time: ~5 minutes | Tools required: Browser**

For detailed steps (key generation, advanced deployment, troubleshooting), see:

1. [`docs/01-SETUP.md`](docs/01-SETUP.md)
2. [`docs/02-DEPLOYMENT.md`](docs/02-DEPLOYMENT.md)
3. [`docs/03-CONFIGURATION.md`](docs/03-CONFIGURATION.md)
4. [`docs/04-RUNNING.md`](docs/04-RUNNING.md)
5. [`docs/05-MONITORING.md`](docs/05-MONITORING.md)

### First Event Test

Want to send a single event via REST? Follow the step-by-step instructions in [`docs/04-RUNNING.md`](docs/04-RUNNING.md) and [`docs/REST_API_GUIDE.md`](docs/REST_API_GUIDE.md). They include ready-to-run `curl` examples and JWT authentication tips.

## Guided Customer Lab

Need the storyline for executives and integrators? Start with [`docs/LAB_GUIDE.md`](docs/LAB_GUIDE.md). It compresses the deployment into five phases, spotlights the Snowpipe Streaming GA enhancements, and arms partners with the instructions they need even if they cannot run the full lab immediately.

## Project Structure

```
├── README.md               # Overview (you're here)
├── QUICKSTART.md           # 5-minute setup guide
├── docs/                   # Numbered walkthrough & reference docs
│   ├── 01-SETUP.md
│   ├── 02-DEPLOYMENT.md
│   ├── 03-CONFIGURATION.md
│   ├── 04-RUNNING.md
│   ├── 05-MONITORING.md
│   └── PLATFORM_GUIDE.md, REST_API_GUIDE.md, ...
├── tools/                  # Cross-platform CLI wrappers (check, deploy, simulate, validate)
├── sql/                    # Snowflake SQL scripts (numbered)
│   ├── 01_setup/
│   ├── 02_validation/
│   ├── 03_monitoring/
│   ├── 04_data_quality/
│   └── 99_cleanup/
├── python/                 # Python packages
│   ├── cli/                # Command-line utilities
│   ├── simulator/          # RFID event simulator
│   ├── shared/             # Shared helpers & validation
│   └── tests/              # pytest test suite
├── config/                 # `.env` template and key setup guide
└── examples/               # Sample data & customization templates
```

## Examples

- `examples/custom_simulation.py` – run a short-duration simulation (2 minutes at 50 events/sec) for quick testing or customization. Execute with `python examples/custom_simulation.py`.

## Architecture

### Data Flow

```
RFID Vendor → POST https://[account].snowflakecomputing.com/v2/streaming/...
           ↓
    PIPE Object (in-flight transformations)
           ↓
    RAW_BADGE_EVENTS
           ↓
    Stream (CDC)
           ↓
    Task (1-min, triggered by stream)
           ↓
    STG_BADGE_EVENTS (deduplication)
           ↓
    Task (MERGE operations)
           ↓
    Analytics: DIM_USERS, DIM_ZONES, FCT_ACCESS_EVENTS
```

### Use Case

Property access control with RFID badges:
- Users wearing badges (employees, visitors, contractors)
- Badge readers at entry/exit points, zone transitions, secure areas
- Real-time tracking of movement and occupancy
- Security alerts and access control

## Documentation

| Document | Description |
|----------|-------------|
| `docs/GITHUB_REPOSITORY_SETUP.md` | How the public repository supports read-only access |
| `docs/01-SETUP.md` | Install prerequisites and verify environment |
| `docs/02-DEPLOYMENT.md` | Deploy Snowflake database, schemas, streams, and tasks |
| `docs/03-CONFIGURATION.md` | Configure JWT authentication and `.env` settings |
| `docs/04-RUNNING.md` | Run the simulator and validate pipeline health |
| `docs/05-MONITORING.md` | Monitor, troubleshoot, and optimize the pipeline |
| `docs/PLATFORM_GUIDE.md` | Platform-specific notes for Windows, macOS, Linux |
| `docs/REST_API_GUIDE.md` | REST API reference and advanced ingestion patterns |
| `docs/ARCHITECTURE.md` | Detailed architecture and design decisions |
| `docs/DATA_DICTIONARY.md` | Dimension and fact table definitions |

## Key Components

### PIPE Object with In-Flight Transformations

The PIPE object centralizes ingestion logic:

```sql
CREATE PIPE badge_events_pipe
AS COPY INTO RAW_BADGE_EVENTS
FROM (
  SELECT 
    $1:badge_id::STRING as badge_id,
    $1:user_id::STRING as user_id,
    TRY_TO_TIMESTAMP_NTZ($1:event_timestamp) as event_timestamp,
    COALESCE($1:signal_strength::NUMBER, -999) as signal_strength,
    CASE 
      WHEN $1:signal_strength::NUMBER < -80 THEN 'WEAK'
      ELSE 'STRONG'
    END as signal_quality,
    CURRENT_TIMESTAMP() as ingestion_time
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
)
FILE_FORMAT = (TYPE = JSON);
```

### CDC Pipeline

Streams and Tasks provide near-real-time transformation:

```sql
-- Stream captures changes
CREATE STREAM raw_badge_events_stream 
ON TABLE RAW_BADGE_EVENTS;

-- Task processes changes every minute
CREATE TASK raw_to_staging_task
  WAREHOUSE = etl_wh
  SCHEDULE = '1 MINUTE'
WHEN SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream')
AS
  INSERT INTO STG_BADGE_EVENTS
  SELECT * FROM raw_badge_events_stream
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY badge_id, event_timestamp 
    ORDER BY ingestion_time DESC
  ) = 1;
```

## Monitoring

Monitor ingestion health with built-in views:

```sql
-- Check channel status
SELECT * FROM V_INGESTION_METRICS;

-- View end-to-end latency
SELECT * FROM V_END_TO_END_LATENCY;

-- Check clustering efficiency
SELECT * FROM V_PARTITION_EFFICIENCY;
```

For live dashboards, save these queries in Snowsight Workspaces or your BI tool of choice and point stakeholders to the quick narrative in [`docs/LAB_GUIDE.md`](docs/LAB_GUIDE.md) (Phase 4) for recommended charts and KPIs.

## Getting Updates

Since you're using a read-only clone of the public repository, you can easily fetch the latest updates:

```sql
-- Fetch latest changes from GitHub
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA GIT_REPOS;
ALTER GIT REPOSITORY simple_stream_repo FETCH;

-- Verify you have the latest files
SELECT * FROM TABLE(
  LIST_GIT_REPOSITORY_FILES(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    ref => 'main'
  )
)
ORDER BY file_path;
```

After fetching updates, you can re-deploy using:
```sql
CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.DEPLOY_PIPELINE();
```

## Cleanup

To remove all deployed resources:

```sql
-- Complete teardown (drops all objects)
-- Copy/paste contents of sql/99_cleanup/teardown_all.sql

-- Stop tasks only (preserve data)
-- Copy/paste contents of sql/99_cleanup/teardown_tasks_only.sql
```

## Performance Characteristics

| Metric | Value |
|--------|-------|
| Max Throughput | 10 GB/sec per table |
| Ingest-to-Query Latency | <10 seconds |
| Max Request Size | 16 MB per POST |
| Authentication | JWT with key-pair |
| Pricing | Throughput-based (credits per GB) |

## Support

For questions or issues:
1. Review documentation in `docs/` directory
2. Check Snowflake documentation for Snowpipe Streaming
3. Examine monitoring views for ingestion health

## License

This is a reference implementation for educational and demonstration purposes.

