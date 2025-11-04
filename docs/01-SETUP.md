# 01 - Setup & Prerequisites

**Goal:** Prepare your Snowflake environment and connect the GitHub repository.

**Time:** ~5 minutes

**Next:** [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md)

---

## Overview

This guide walks you through the initial setup: verifying prerequisites, connecting the GitHub repository to Snowflake, and preparing for pipeline deployment.

**What you'll do:**
- ✅ Verify Snowflake account access and privileges
- ✅ Connect public GitHub repository via Git integration
- ✅ Verify repository files are accessible

---

## Prerequisites

### Snowflake Account Requirements

- **Account**: Snowflake trial or paid account
- **Role**: `ACCOUNTADMIN` (for Git API integration) or equivalent
- **Warehouse**: Any warehouse (default `COMPUTE_WH` is fine)
- **Edition**: Standard or higher (Snowpipe Streaming is available on all editions)

### Required Privileges

The user must have:
- `CREATE DATABASE`
- `CREATE API INTEGRATION` (requires ACCOUNTADMIN or delegated privilege)
- `CREATE GIT REPOSITORY`

**Verify your role:**
```sql
SELECT CURRENT_ROLE(), CURRENT_USER(), CURRENT_ACCOUNT();
```

---

## Step 1: Verify Environment

### Check Snowflake Edition

```sql
SELECT SYSTEM$GET_EDITION() AS edition;
-- Should return: STANDARD, ENTERPRISE, or BUSINESS_CRITICAL
```

### Verify Warehouse Access

```sql
SHOW WAREHOUSES;

-- Test warehouse
USE WAREHOUSE COMPUTE_WH;
SELECT 'Warehouse is accessible' AS status;
```

If you don't have `COMPUTE_WH`, create one or use an existing warehouse:

```sql
-- Optional: Create a demo warehouse
CREATE WAREHOUSE IF NOT EXISTS DEMO_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Demo warehouse for simple-stream project';
```

---

## Step 2: Connect GitHub Repository

### Understanding Git Integration

This project uses Snowflake's **Git Repository** feature to:
- Clone code directly from GitHub (no local cloning needed)
- Read SQL scripts and notebooks via SQL commands
- Enable automated deployment from Git
- Support Git-based CI/CD workflows

**Key benefits:**
- ✅ No authentication required (public repository)
- ✅ Read-only access (can't accidentally push changes)
- ✅ Always fetch latest updates with `ALTER GIT REPOSITORY ... FETCH`

---

### Execute Git Setup Script

1. **Open Snowsight** (your Snowflake web UI)
2. Navigate to **Projects** → **Workspaces**
3. Click **+ SQL File** (create new worksheet)
4. Copy/paste the entire contents of `sql/00_git_setup/01_git_repository_setup.sql`
5. Click **Run All** (▶▶ button)

**What it does:**

The script creates ONE thing: the API integration for GitHub access.  
(The workspace UI will create the Git repository object for you!)

**Expected output:**

```
✅ API Integration created: SFE_GIT_API_INTEGRATION (enabled = true)
```

---

## Step 3: Create Git Workspace (Makes it Persistent!)

Now create your workspace in Snowsight - this makes it persist across sessions!

1. In Snowsight, go to: **Projects** → **Workspaces**

2. Click: **"+ Workspace"** → **"From Git repository"**

3. Fill in the form:
   - **Repository URL**: `https://github.com/sfc-gh-miwhitaker/sfe-simple-stream`
   - **Workspace Name**: `sfe-simple-stream`
   - **API Integration**: Select **"SFE_GIT_API_INTEGRATION"** ← Created in Step 2!
   - **Authentication**: Choose **"No authentication"** (public repo)
   - **Branch**: Select **"main"**

4. Click **"Create"**

**✅ Done! Your workspace:**
- Appears in your **Projects → Workspaces** list
- Shows all SQL files, notebooks, and docs in the file explorer
- **Persists across browser sessions and logins** (no need to recreate!)
- Lets you run scripts directly from the repository

---

## Step 4: Verify Repository Access

### List Repository Files

```sql
-- List all files in the repository
LS @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main;
```

You should see:
```
sql/
notebooks/
examples/
config/
docs/
README.md
QUICKSTART.md
.gitignore
```

### Test Reading a File

```sql
-- Read README.md from Git
SELECT file_content
FROM TABLE(
    READ_GIT_FILE(
        repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
        file_path => 'README.md',
        ref => 'main'
    )
)
LIMIT 10;
```

If you can read the file, Git integration is working! ✅

---

## Step 5: Verify Key SQL Directories

```sql
-- Verify SQL setup scripts exist
SELECT relative_path, size
FROM DIRECTORY(@SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main)
WHERE relative_path LIKE 'sql/%'
ORDER BY relative_path;
```

You should see directories:
- `sql/00_git_setup/` - Git integration scripts
- `sql/01_setup/` - Core pipeline setup
- `sql/02_validation/` - Validation queries
- `sql/03_monitoring/` - Monitoring views
- `sql/04_data_quality/` - Data quality checks
- `sql/99_cleanup/` - Teardown scripts

---

## Troubleshooting

### "API integration already exists"

**This is OK!** The script uses `CREATE OR REPLACE`, so it will update the existing integration.

### "Insufficient privileges to create API integration"

**Solution:** Switch to `ACCOUNTADMIN` role:
```sql
USE ROLE ACCOUNTADMIN;
-- Then re-run the Git setup script
```

### "Repository fetch failed"

**Possible causes:**
1. Network issue - retry after a moment
2. GitHub repository URL changed - verify URL in script
3. Snowflake Git integration temporary issue - check Snowflake status page

**Retry fetch:**
```sql
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo FETCH;
```

### "File not found" when reading from repository

**Solution:** Verify the branch name and file path:
```sql
SHOW GIT BRANCHES IN SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo;
-- Should show 'main' branch
```

---

## What's Next?

✅ **You've completed setup!** Your Snowflake environment is now connected to the GitHub repository.

**Next steps:**
1. **Deploy the pipeline** → Continue to [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md)
2. **Configure authentication** → See [`03-CONFIGURATION.md`](03-CONFIGURATION.md) after deployment
3. **Run the simulator** → See [`04-RUNNING.md`](04-RUNNING.md) after configuration

---

## Quick Reference

### Update Repository (Get Latest Changes)

```sql
USE ROLE ACCOUNTADMIN;
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo FETCH;
```

### View Repository Info

```sql
SHOW GIT REPOSITORIES IN SCHEMA SNOWFLAKE_EXAMPLE.DEMO_REPO;
DESC GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo;
```

### Remove Git Integration (Cleanup)

```sql
-- If you need to start over
DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo;
DROP API INTEGRATION IF EXISTS SFE_GIT_API_INTEGRATION;
```

---

## Additional Resources

- [Snowflake Git Repository Documentation](https://docs.snowflake.com/en/developer-guide/git/git-overview)
- [API Integrations for Git](https://docs.snowflake.com/en/sql-reference/sql/create-api-integration-git)
- [`GITHUB_REPOSITORY_SETUP.md`](GITHUB_REPOSITORY_SETUP.md) - Detailed Git integration guide

