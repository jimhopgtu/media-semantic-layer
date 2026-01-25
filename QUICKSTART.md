# Quick Start Guide

Get this project running in 30 minutes or less.

## Prerequisites Checklist

- [ ] Snowflake account (free trial: https://signup.snowflake.com/)
- [ ] dbt Cloud account (free: https://www.getdbt.com/signup/) OR dbt Core installed
- [ ] Python 3.9+ installed
- [ ] Git installed
- [ ] Preset account (free: https://preset.io/signup/)

---

## Step 1: Clone & Setup (5 min)

```bash
# Clone repository
git clone https://github.com/yourusername/media-semantic-layer.git
cd media-semantic-layer

# Install Python dependencies
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
```

**Edit `.env` file:**
```bash
# Snowflake credentials
SNOWFLAKE_ACCOUNT=your_account.snowflakecomputing.com
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_DATABASE=MEDIA_ANALYTICS
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_SCHEMA=RAW
```

---

## Step 2: Load Synthetic Data (10 min)

```bash
# Generate and load synthetic data
python scripts/data_generation/generate_synthetic_data.py

# This creates:
# - 192K events across 99 days
# - 5,000 articles
# - 75 writers
# - ~50K unique users
```

**Verify in Snowflake:**
```sql
SELECT COUNT(*) FROM media_analytics.raw.events_raw;
-- Should return ~192,000

SELECT COUNT(*) FROM media_analytics.raw.article_metadata;
-- Should return ~5,000
```

---

## Step 3: Run dbt Models (10 min)

```bash
cd dbt_project

# Install dbt packages
dbt deps

# Run all models
dbt run

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

**Verify key tables exist:**
```sql
-- Check dimensional model
SELECT COUNT(*) FROM media_analytics.dev_james_marts.dim_articles;
SELECT COUNT(*) FROM media_analytics.dev_james_marts.fct_article_events;

-- Check experiment results
SELECT * FROM media_analytics.dev_james_marts.experiment_results
WHERE is_clickbait_variant = TRUE;
-- Should return 1 row (exp_006)
```

---

## Step 4: Connect Preset (5 min)

1. **Log into Preset:** https://preset.io/

2. **Add Database Connection:**
   - Click "+ Database"
   - Select "Snowflake"
   - Fill in credentials:
     - Host: `your_account.snowflakecomputing.com`
     - Database: `MEDIA_ANALYTICS`
     - Schema: `DEV_JAMES_MARTS`
     - Warehouse: `COMPUTE_WH`
   - Test & Connect

3. **Create First Dataset:**
   - Go to SQL Lab
   - Run: `SELECT * FROM experiment_results LIMIT 10`
   - Click "Save" → "Save Dataset"

4. **Create First Chart:**
   - Chart Type: Table
   - Show all experiments
   - You're done! 🎉

---

## What You Should See

### Experiment Results
- **10 experiments** across 5 categories
- **1 clickbait experiment flagged** (exp_006)
- **Sample sizes:** 1,000-5,000 users per experiment
- **Statistical significance:** Most experiments significant

### Writer Performance
- **75 writers** tracked
- **Quality tiers:** Distribution across high/good/acceptable/needs_improvement
- **Revenue per article:** Ranges from $0.001 - $0.005

### Article Performance
- **5,000 articles** analyzed
- **Engagement rates:** 25-35% overall
- **Quality engagement:** 15-25% (lower due to quality weighting)

---

## Common Issues & Solutions

### "Schema does not exist"
```sql
-- Create schemas manually
CREATE SCHEMA IF NOT EXISTS media_analytics.raw;
CREATE SCHEMA IF NOT EXISTS media_analytics.dev_james_staging;
CREATE SCHEMA IF NOT EXISTS media_analytics.dev_james_marts;
```

### "dbt run fails"
```bash
# Clear cache and rebuild
dbt clean
dbt deps
dbt run --full-refresh
```

### "No clickbait detected"
```sql
-- Verify lift percentages
SELECT 
    experiment_id,
    engagement_lift_pct,
    quality_engagement_lift_pct,
    is_clickbait_variant
FROM experiment_results
WHERE experiment_id = 'exp_006';

-- Should show: +25% engagement, -8% quality, TRUE
```

### "Preset connection fails"
- Verify Snowflake user has access to schemas
- Check warehouse is running
- Try using full account URL: `abc12345.us-east-1.snowflakecomputing.com`

---

## Next Steps

Once everything is running:

1. **Explore the dashboards** - Click around Preset
2. **Run custom queries** - Use SQL Lab to analyze data
3. **Modify experiments** - Change lift percentages in `experiment_results.sql`
4. **Add your own data** - Replace synthetic data with real data
5. **Customize for your domain** - Adapt models to your business

---

## Quick Commands Reference

```bash
# Generate new synthetic data
python scripts/data_generation/generate_synthetic_data.py

# Run specific dbt models
dbt run --select staging
dbt run --select marts
dbt run --select experiments

# Run tests
dbt test --select experiment_results

# View lineage
dbt docs generate && dbt docs serve

# Check data quality
dbt run --select data_quality_checks
```

---

## Getting Help

**Documentation:**
- [Full Documentation](./docs/)
- [dbt Best Practices](./docs/dbt_best_practices.md)
- [Dashboard Guide](./docs/preset_dashboard_guide.md)

**Issues:**
- Check [GitHub Issues](https://github.com/yourusername/media-semantic-layer/issues)
- Review dbt logs: `dbt_project/logs/dbt.log`
- Enable debug mode: `dbt run --debug`

**Questions:**
- Open a GitHub Discussion
- Email: [your-email@example.com]

---

## Success Criteria

✅ You're all set when you can:

1. Query `experiment_results` and see 10 experiments
2. See exp_006 flagged as clickbait
3. View writer scorecards in Preset
4. Run `dbt test` with all tests passing
5. Show experiment scatter plot with clickbait in red

**Time to complete:** 30 minutes  
**Difficulty:** Intermediate  
**Cost:** $0 (free tiers)

---

**Ready to dive deeper?** Check out the [full documentation](./docs/) for advanced topics!