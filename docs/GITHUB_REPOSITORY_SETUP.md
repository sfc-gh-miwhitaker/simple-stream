# GitHub Repository Setup for Public Read-Only Access

This document explains how the public repository is configured to support read-only cloning in Snowflake.

---

## ✅ Current Configuration (Already Done)

Your repository is **already configured correctly** for public read-only access:

1. **Repository Visibility: Public** ✅
   - URL: `https://github.com/sfc-gh-miwhitaker/simple-stream`
   - Anyone can clone via HTTPS without authentication
   - Perfect for demos, examples, and reference implementations

2. **Default Branch: `main`** ✅
   - Snowflake clones from the `main` branch by default
   - All deployment scripts reference files in `main`

3. **Standard HTTPS URL** ✅
   - Format: `https://github.com/[org]/[repo]`
   - Snowflake's API Integration uses this for cloning

---

## 🎯 How Users Consume Your Repository

### Step 1: User Adds Repository to Snowflake

Users open Snowsight Workspaces (Projects → Workspaces → + SQL File) and run a single SQL script to clone your public repository:

```sql
-- From: sql/00_git_setup/01_git_repository_setup.sql
CREATE OR REPLACE GIT REPOSITORY sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream';
```

**What happens:**
- Snowflake clones the repository via HTTPS (no credentials needed)
- Repository is read-only (users cannot push changes back)
- Users can read all files in the repository from SQL/Python

### Step 2: User Deploys from Repository

Users can execute SQL scripts directly from the repository:

```sql
-- Deploy pipeline by reading SQL from the Git repository
CALL DEPLOY_PIPELINE();  -- Stored procedure reads from repo files
```

### Step 3: User Gets Updates (If You Push Changes)

When you push updates to GitHub, users can fetch them:

```sql
ALTER GIT REPOSITORY simple_stream_repo FETCH;
```

---

## 🔧 Snowflake API Integration Configuration

### Critical: API_ALLOWED_PREFIXES

The API Integration must specify your GitHub account/organization in the allowed prefixes:

```sql
CREATE OR REPLACE API INTEGRATION SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/')  -- ✅ Specific to your account
  ENABLED = TRUE;
  -- ⚠️ Do NOT include ALLOWED_AUTHENTICATION_SECRETS for public repos
```

**Common Error:**
```
Failed to access the Git Repository. Operation 'clone' is not authorized.
```

**Causes:**
- ❌ Using generic prefix: `('https://github.com/')` - too broad, Snowflake may reject
- ❌ Including `ALLOWED_AUTHENTICATION_SECRETS` parameter for public repos (should be omitted)
- ❌ Wrong URL format or typo in repository URL
- ✅ Solution: Use account-specific prefix WITHOUT authentication parameters for public repos

### Maintaining the Repository

**What You Need to Do:**

1. **Keep Repository Public**
   - If you make it private, users will need authentication (SSH keys or GitHub tokens)
   - Public = frictionless for demos and examples

2. **Push Changes to `main` Branch**
   - All SQL scripts reference the `main` branch
   - Users will see updates when they fetch

3. **No Breaking Changes to File Paths**
   - Keep the numbered structure: `sql/01_setup/`, `sql/02_validation/`, etc.
   - Keep stored procedure definitions in `sql/00_git_setup/04_stored_procedures.sql`

### What You Don't Need to Do

- ❌ Set up SSH keys or deploy keys
- ❌ Configure GitHub Actions for users
- ❌ Manage authentication credentials
- ❌ Create forks for each user
- ❌ Worry about users pushing bad code (they can't, it's read-only!)

---

## 📊 Benefits of This Approach

### For Users:
- **Zero authentication** - No SSH keys, no tokens, no OAuth
- **Zero maintenance** - Just fetch updates when available
- **Zero risk** - Can't accidentally break your repository
- **Instant setup** - One SQL script to clone entire project

### For You:
- **Single source of truth** - One repository, many users
- **Easy updates** - Push to `main`, users fetch
- **No support burden** - No authentication debugging
- **Clear separation** - Users can't modify your canonical code

---

## 🚀 Advanced: Supporting Multiple Versions

If you want to support multiple versions (e.g., v1.0, v2.0), users can reference specific branches or tags:

```sql
-- User can specify a branch or tag
CREATE OR REPLACE GIT REPOSITORY simple_stream_repo
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/simple-stream'
  GIT_CREDENTIALS = git_creds;  -- Only needed for private repos

-- Read files from a specific branch/tag/commit
LIST @simple_stream_repo/branches/main;
-- or
LIST @simple_stream_repo/tags/v1.0;
-- or
LIST @simple_stream_repo/commits/abc123;
```

**Best Practice:**
- Use semantic versioning tags: `v1.0.0`, `v1.1.0`, `v2.0.0`
- Keep `main` as the latest stable release
- Document which version users should use in README.md

---

## 🔒 What If You Need Private Access?

If you need to make the repository private in the future, users would need to:

1. Generate a GitHub personal access token (PAT)
2. Create a Secret in Snowflake with the token
3. Create Git Credentials object referencing the Secret
4. Reference credentials when creating the Git Repository

**Example:**
```sql
-- Only needed for PRIVATE repositories
CREATE SECRET github_token
  TYPE = PASSWORD
  USERNAME = 'sfc-gh-miwhitaker'
  PASSWORD = 'ghp_xxxxxxxxxxxxx';  -- GitHub PAT

CREATE GIT CREDENTIAL github_creds
  USING SECRET github_token;

CREATE GIT REPOSITORY simple_stream_repo
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/simple-stream'
  GIT_CREDENTIALS = github_creds;  -- Now required
```

But for a demo/example project, **keeping it public is ideal**!

---

## 📚 Related Documentation

- [Snowflake Git Repository Documentation](https://docs.snowflake.com/en/developer-guide/git/git-overview)
- [GitHub Repository Visibility](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)
- [GitHub Branches and Tags](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-branches-in-your-repository)

---

## ✅ Summary

**Your repository is already set up perfectly for public read-only access!**

- ✅ Repository is public
- ✅ URL is pre-configured in all scripts
- ✅ Users can clone with one SQL statement
- ✅ No authentication required
- ✅ Users get updates with `ALTER GIT REPOSITORY ... FETCH`

**No additional configuration needed!** Just keep pushing updates to `main` and users can fetch them.

