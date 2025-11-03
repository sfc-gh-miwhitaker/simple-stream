# Create New Repository: simple_stream

This document contains the exact commands to create your new `simple_stream` repository.

---

## ✅ What's Already Done

All code has been updated to reference the new repository name:
- ✅ SQL scripts updated (`streaming_ingest_repo` → `simple_stream_repo`)
- ✅ README.md renamed to "Simple Stream"
- ✅ All local deployment tools removed
- ✅ Project is 100% Snowflake-native

---

## 📋 Step-by-Step Instructions

### Step 1: Create GitHub Repository

1. Go to **https://github.com/new**
2. Fill in:
   - **Repository name:** `simple_stream`
   - **Description:** `Snowflake-native Snowpipe Streaming REST API demo`
   - **Visibility:** Public
   - **⚠️ IMPORTANT:** DO NOT check "Initialize with README"
3. Click **"Create repository"**

---

### Step 2: Update Git Remote

Open terminal in this directory and run:

```bash
# Remove old remote
git remote remove origin

# Add new remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/simple_stream.git

# Verify
git remote -v
```

**Expected output:**
```
origin  https://github.com/YOUR_USERNAME/simple_stream.git (fetch)
origin  https://github.com/YOUR_USERNAME/simple_stream.git (push)
```

---

### Step 3: Commit and Push

```bash
# Stage all changes
git add .

# Commit with descriptive message
git commit -m "feat: Initial commit - Snowflake-native streaming demo

- Snowpipe Streaming REST API showcase via notebooks
- 100% browser-only deployment with Git integration
- Zero local setup required
- RFID badge tracking example with REST API
- Removed all local deployment tools
- Simplified to single Snowflake-native path"

# Set default branch to main
git branch -M main

# Push to GitHub
git push -u origin main
```

---

### Step 4: Verify on GitHub

1. Go to `https://github.com/YOUR_USERNAME/simple_stream`
2. You should see:
   - ✅ README.md displays "Simple Stream" title
   - ✅ `notebooks/RFID_Simulator.ipynb` visible
   - ✅ `sql/00_git_setup/` directory present
   - ✅ `QUICKSTART.md` file present

---

### Step 5: Update SQL Script with Actual URL

After pushing, update the repository URL in the SQL script:

**File:** `sql/00_git_setup/01_git_repository_setup.sql`

**Line 49:** Change this:
```sql
ORIGIN = 'https://github.com/YOUR_ORG/simple_stream'  -- TODO: Update with your GitHub org/username
```

To this (with your actual username):
```sql
ORIGIN = 'https://github.com/YOUR_USERNAME/simple_stream'
```

Then commit and push the update:
```bash
git add sql/00_git_setup/01_git_repository_setup.sql
git commit -m "docs: Update repository URL with actual GitHub username"
git push
```

---

## 🎯 What Users Will Do

When someone clones your new `simple_stream` repository:

1. **Open Snowsight** (browser)
2. **Run SQL script:** `sql/00_git_setup/01_git_repository_setup.sql`
   - This clones `simple_stream` into their Snowflake account
3. **Configure secrets:** `sql/00_git_setup/02_configure_secrets.sql`
4. **Deploy:** `CALL DEPLOY_PIPELINE();`
5. **Run notebook:** Import `RFID_Simulator.ipynb` from Git
6. **Validate:** `CALL VALIDATE_PIPELINE();`

**Total time:** 5 minutes | **Tools:** Browser only

---

## 🏷️ Optional: Configure Repository Settings

### Add Topics (for discoverability):
- `snowflake`
- `snowpipe-streaming`
- `rest-api`
- `data-engineering`
- `streaming-data`
- `snowflake-native`
- `real-time-analytics`

### Set Website:
```
https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview
```

### Add Social Preview Image:
Upload a screenshot of the notebook running or the pipeline diagram.

---

## 🐛 Troubleshooting

### "Repository already exists"
If you see this error, the repo name is taken. Choose a different name:
- `simple-stream` (with hyphen)
- `snowflake-simple-stream`
- `simple-streaming-demo`

### "Permission denied (publickey)"
Use HTTPS instead of SSH:
```bash
git remote set-url origin https://github.com/YOUR_USERNAME/simple_stream.git
```

### "Failed to push some refs"
The repository might have been initialized with README. Delete and recreate without README checkbox.

---

## ✅ Success Criteria

You'll know it worked when:
- ✅ Repository visible at `github.com/YOUR_USERNAME/simple_stream`
- ✅ README displays "Simple Stream" title
- ✅ All files show up in GitHub web interface
- ✅ Commit history shows your initial commit
- ✅ No references to old `Streaming-Ingest` repo name

---

## 📞 Next Steps After Push

1. **Test the workflow** - Follow `QUICKSTART.md` yourself to verify
2. **Share the repository** - Send link to customers/partners
3. **Monitor issues** - Watch for user questions or bug reports
4. **Iterate** - Improve based on feedback

---

**You're ready to go! Follow Steps 1-4 above to create your new repository.** 🚀

