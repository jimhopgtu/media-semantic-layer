# Setup Guide - Week 1 Preparation

This guide will walk you through setting up all the tools and accounts needed for the project.

## 📋 Prerequisites Checklist

Before starting, ensure you have:
- [ ] Windows PC with admin rights
- [ ] Python 3.9+ installed
- [ ] Git installed
- [ ] VSCode or preferred code editor
- [ ] Chrome or Firefox browser
- [ ] GitHub account

## 🔧 Day 0: Tool Setup (Friday - 2-3 hours)

### 1. Snowflake Free Trial (15 min)

**Sign up:**
1. Go to https://signup.snowflake.com/
2. Click "Start for Free"
3. Fill form:
   - Edition: **Standard**
   - Cloud Provider: **AWS**
   - Region: **US East (N. Virginia)** or closest to you
   - Business email (your personal email is fine)
4. Verify email and set password
5. **IMPORTANT**: Save your account locator (looks like `xy12345.us-east-1`)

**Initial configuration:**
```sql
-- Run these in Snowflake Worksheets (web UI)
-- This will be your account URL: https://app.snowflake.com/

-- Set up warehouse
USE WAREHOUSE COMPUTE_WH;
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60;

-- Create database
CREATE DATABASE media_analytics;

-- Verify
SHOW DATABASES;
```

**Save credentials:**
```
Account: xy12345.us-east-1.snowflakecomputing.com
Username: YOUR_EMAIL
Password: YOUR_PASSWORD
```

---

### 2. dbt Cloud Developer Account (15 min)

**Sign up:**
1. Go to https://www.getdbt.com/signup
2. Choose "Developer" (free tier)
3. Verify email

**Connect to Snowflake:**
1. In dbt Cloud: Projects → New Project
2. Name: `media-semantic-layer`
3. Connection:
   - Type: **Snowflake**
   - Account: `xy12345.us-east-1` (your account locator)
   - Database: `media_analytics`
   - Warehouse: `COMPUTE_WH`
   - Auth: Username/Password
   - Username: (your Snowflake username)
   - Password: (your Snowflake password)
4. Test connection → Should see ✓
5. Setup repository: **Skip for now** (we'll do this Monday)

---

### 3. GitHub Repository (10 min)

**Create repo:**
1. Go to https://github.com/new
2. Repository name: `media-semantic-layer`
3. Description: "AI-enriched media analytics platform with dbt Semantic Layer"
4. **Public** (for portfolio visibility)
5. Initialize with README: ✓
6. Add .gitignore: **Python**
7. Create repository

**Clone locally:**
```bash
cd ~/projects  # or wherever you keep code
git clone https://github.com/YOUR_USERNAME/media-semantic-layer.git
cd media-semantic-layer
```

---

### 4. Astro (Airflow) Free Tier (15 min)

**Sign up:**
1. Go to https://www.astronomer.io/try-astro
2. Sign up with GitHub or email
3. Verify email
4. Create Organization: `media-analytics`

**Create deployment:**
1. Deployments → New Deployment
2. Name: `media-analytics-prod`
3. Cluster: **Shared** (free tier)
4. Executor: **Celery**
5. Create

**Install Astro CLI (optional for local dev):**

Windows (PowerShell as admin):
```powershell
# Using Chocolatey
choco install astro

# Or download installer from:
# https://github.com/astronomer/astro-cli/releases
```

Test:
```bash
astro version
# Should show: Astro CLI Version: X.X.X
```

---

### 5. Hugging Face Account (5 min)

**Sign up:**
1. Go to https://huggingface.co/join
2. Create account
3. Verify email

**Get API token:**
1. Go to https://huggingface.co/settings/tokens
2. Click "New token"
3. Name: `media-analytics-sentiment`
4. Type: **Read**
5. Create token
6. **SAVE THIS**: `hf_xxxxxxxxxxxxxxxxxxx`

**Test API (optional):**
```bash
curl https://api-inference.huggingface.co/models/distilbert-base-uncased-finetuned-sst-2-english \
  -H "Authorization: Bearer hf_YOUR_TOKEN" \
  -d '{"inputs": "This article is amazing!"}'

# Should return: [{"label":"POSITIVE","score":0.9998}]
```

---

### 6. Preset (Superset) Free Trial (10 min)

**Sign up:**
1. Go to https://preset.io/
2. Click "Start Free Trial"
3. Sign up with email or Google
4. Verify email

**Create workspace:**
1. Name: `media-analytics`
2. Region: **US**
3. Create

**Connect to dbt (we'll do this in Week 2):**
- Settings → dbt Cloud Integration
- (Skip for now - requires dbt project to be deployed first)

---

### 7. Python Environment Setup (15 min)

**Create virtual environment:**
```bash
cd ~/projects/media-semantic-layer

# Create venv
python -m venv venv

# Activate (Windows)
.\venv\Scripts\activate

# Or if using Git Bash on Windows:
source venv/Scripts/activate

# Should see (venv) in your prompt
```

**Install dependencies:**
```bash
# Make sure you're in project root and venv is activated
pip install --upgrade pip
pip install -r requirements.txt

# This will take 2-3 minutes
```

**Test installation:**
```python
python -c "import pandas; import snowflake.connector; print('✓ All imports successful')"
```

---

### 8. Create .env File (5 min)

**Set up environment variables:**
```bash
# Copy template
cp .env.template .env

# Edit .env with your actual values (use VSCode or notepad)
# Fill in:
# - SNOWFLAKE_ACCOUNT
# - SNOWFLAKE_USER
# - SNOWFLAKE_PASSWORD
# - HUGGINGFACE_API_KEY
```

**Example .env:**
```bash
SNOWFLAKE_ACCOUNT=xy12345.us-east-1.snowflakecomputing.com
SNOWFLAKE_USER=YOUR_EMAIL@gmail.com
SNOWFLAKE_PASSWORD=YourPassword123!
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=media_analytics
SNOWFLAKE_SCHEMA=raw
SNOWFLAKE_ROLE=ACCOUNTADMIN

HUGGINGFACE_API_KEY=hf_xxxxxxxxxxxxxxxxxxx
HUGGINGFACE_API_URL=https://api-inference.huggingface.co/models
SENTIMENT_MODEL=distilbert-base-uncased-finetuned-sst-2-english
```

---

### 9. Generate Synthetic Data (10 min)

**Run data generator:**
```bash
# Make sure venv is activated
python generate_synthetic_data.py --output-dir ./data

# Progress output:
# Generating writers... ✓
# Generating articles... ✓
# Generating events... (this takes 5-10 min)
# ✓ Data generation complete!
```

**Verify output:**
```bash
ls -lh data/

# Should see:
# writers.csv     (~8 KB, 75 rows)
# articles.csv    (~800 KB, 5000 rows)  
# events.jsonl    (~150 MB, 500K rows)
```

---

### 10. Load Data to Snowflake (15 min)

**Option A: Web UI (Easiest for first time)**

1. Open Snowflake UI: https://app.snowflake.com/
2. Go to Databases → media_analytics → raw schema
3. Click "Create" → "Table" → "From File"
4. Load each file:
   - **writers.csv** → writer_metadata
   - **articles.csv** → article_metadata
   - **events.jsonl** → events_raw (may take 5-10 min)

**Option B: Python Script**

```bash
# Run loader script
python scripts/load_to_snowflake.py

# This will:
# 1. Connect to Snowflake
# 2. Truncate tables
# 3. Bulk insert data
# 4. Validate load
```

**Verify in Snowflake:**
```sql
USE DATABASE media_analytics;
USE SCHEMA raw;

SELECT 'writers' as table_name, COUNT(*) as row_count FROM writer_metadata
UNION ALL
SELECT 'articles', COUNT(*) FROM article_metadata
UNION ALL
SELECT 'events', COUNT(*) FROM events_raw;

-- Expected:
-- writers:  75
-- articles: 5,000
-- events:   500,000+
```

---

## ✅ Day 0 Completion Checklist

At the end of today, you should have:

- [ ] Snowflake account with `media_analytics` database
- [ ] 3 tables loaded: writer_metadata, article_metadata, events_raw
- [ ] dbt Cloud account connected to Snowflake
- [ ] GitHub repo created and cloned locally
- [ ] Astro (Airflow) account and deployment created
- [ ] Hugging Face API token saved
- [ ] Preset workspace created
- [ ] Python venv with all dependencies installed
- [ ] .env file configured with credentials
- [ ] Synthetic data generated (500K+ events)

---

## 🚀 Ready for Week 1!

**Monday's Goals (Phase 2):**
- Connect dbt Cloud to GitHub repo
- Build staging models (unnest GA4 events)
- Create dimension tables (dim_articles, dim_writers)
- Build fact table (fct_article_events)

**Time estimate:** 4-6 hours

---

## 🆘 Troubleshooting

### Snowflake connection fails
- Check account locator format: `xy12345.us-east-1` (no `https://` or `.snowflakecomputing.com`)
- Verify credentials are correct
- Make sure warehouse is running (COMPUTE_WH)

### Python import errors
- Ensure venv is activated: `(venv)` in prompt
- Try: `pip install -r requirements.txt --upgrade`
- Check Python version: `python --version` (should be 3.9+)

### Data generation is slow
- This is normal! 500K events takes 5-10 minutes
- You can reduce with: `python generate_synthetic_data.py --num-events 100000`

### Snowflake data load fails
- Check file formats match expected schema
- Try loading one table at a time
- Use Snowflake web UI if Python script has issues

---

## 📚 Useful Links

- [Snowflake Docs](https://docs.snowflake.com/)
- [dbt Cloud Quickstart](https://docs.getdbt.com/docs/cloud/about-cloud-setup)
- [dbt Semantic Layer Guide](https://docs.getdbt.com/docs/build/semantic-models)
- [Astro CLI Docs](https://docs.astronomer.io/astro/cli/overview)
- [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index)

---

**Next:** [Week 1 Development Guide](docs/week1_development.md)
