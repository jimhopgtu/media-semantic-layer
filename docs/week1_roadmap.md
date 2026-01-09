# Week 1 Development Roadmap

**Goal:** Build dbt staging models, marts, and semantic layer definitions

**Total time:** ~16-18 hours across 5 days (Monday-Friday)

---

## Monday: Staging Models (4-5 hours)

### Morning (2-3 hours): GA4 Event Unnesting

**What we're building:**
- `stg_ga4_events.sql` - Unnest event_params from JSON
- Extract: article_id, writer_id, engagement_time, percent_scrolled

**Steps:**
1. Create `dbt_project/models/staging/` directory
2. Create `stg_ga4_events.sql`:

```sql
-- Flatten GA4 nested JSON structure
WITH unnested AS (
    SELECT 
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        ga_session_id,
        -- Extract article_id from event_params array
        event_params[0]:value:string_value::STRING AS article_id,
        -- Add other fields...
        device.category AS device_category,
        geo.country AS country,
        traffic_source.source AS traffic_source
    FROM {{ source('raw', 'events_raw') }}
)
SELECT * FROM unnested
```

3. Create `stg_ga4_events.yml` with tests
4. Run: `dbt run -m stg_ga4_events`

**Claude Code usage:**
```bash
# Generate boilerplate
Ask Claude: "Generate dbt staging model for unnesting GA4 event_params"
```

---

### Afternoon (2 hours): Dimension Tables

**What we're building:**
- `stg_articles.sql` - Clean article metadata
- `stg_writers.sql` - Clean writer metadata

**Steps:**
1. Create both staging models with basic SELECT * + type casting
2. Add schema tests (not_null, unique, relationships)
3. Run: `dbt test`

**Expected output:**
```
Completed successfully
✓ 15 tests passed
```

---

## Tuesday: Fact Table & Sessionization (4-5 hours)

### Morning (2-3 hours): Build fct_article_events

**What we're building:**
- Join events with articles and writers
- Calculate engagement metrics per event
- Create event-level fact table

```sql
-- dbt_project/models/marts/fct_article_events.sql
SELECT 
    e.event_date,
    e.event_timestamp,
    e.event_name,
    e.article_id,
    e.writer_id,
    e.user_pseudo_id,
    e.ga_session_id,
    -- Engagement calculations
    CASE WHEN e.event_name = 'user_engagement' 
         THEN e.engagement_time_msec / 1000.0 END AS engagement_time_sec,
    e.percent_scrolled,
    -- Dimensions
    a.category AS article_category,
    a.is_premium,
    w.contract_type AS writer_contract_type
FROM {{ ref('stg_ga4_events') }} e
LEFT JOIN {{ ref('stg_articles') }} a ON e.article_id = a.article_id
LEFT JOIN {{ ref('stg_writers') }} w ON e.writer_id = w.writer_id
```

### Afternoon (2 hours): Dimension Tables

**What we're building:**
- `dim_articles.sql` - SCD Type 1 article dimension
- `dim_writers.sql` - Writer dimension

Both models:
- Add surrogate keys
- Include all attributes needed for semantic layer
- Document columns

---

## Wednesday: Semantic Layer (5-6 hours)

### ALL DAY: Define Entities, Measures, Metrics

This is the **centerpiece** of your project!

**What we're building:**
1. `_semantic_models.yml` (already created!)
2. `_metrics.yml` (already created!)
3. Validate with MetricFlow CLI

**Steps:**

1. **Connect dbt to GitHub:**
   - dbt Cloud → Account Settings → Integrations
   - Connect GitHub repo
   - Set dbt_project/ as root directory

2. **Deploy to dbt Cloud:**
   - Push code to GitHub: `git push`
   - dbt Cloud → Jobs → Create Job
   - Commands: `dbt deps`, `dbt run`, `dbt test`
   - Run job manually

3. **Install MetricFlow CLI:**
```bash
pip install dbt-metricflow
```

4. **Test metrics:**
```bash
# Query total pageviews by category
mf query --metrics total_pageviews --group-by article__category

# Query writer revenue
mf query --metrics revenue_per_article --group-by writer__writer_name --order revenue_per_article desc --limit 10
```

**Expected output:**
```
✓ Query successful
  article__category | total_pageviews
  sports           | 234,567
  finance          | 189,234
  ...
```

---

## Thursday: AI Enrichment with Hugging Face (4-5 hours)

### Morning (2 hours): Enrichment Script

**What we're building:**
- Python script that calls Hugging Face Inference API
- Batch processing (100 articles at a time)
- Updates article_metadata.sentiment_* fields

**Create: `scripts/huggingface_enrichment.py`**

```python
import requests
import os
from dotenv import load_dotenv
import snowflake.connector

load_dotenv()

API_URL = "https://api-inference.huggingface.co/models/distilbert-base-uncased-finetuned-sst-2-english"
headers = {"Authorization": f"Bearer {os.getenv('HUGGINGFACE_API_KEY')}"}

def get_sentiment(text):
    response = requests.post(API_URL, headers=headers, json={"inputs": text})
    return response.json()

def enrich_articles():
    # 1. Connect to Snowflake
    # 2. SELECT article_id, title WHERE sentiment_score_positive IS NULL
    # 3. Batch call Hugging Face (100 at a time)
    # 4. UPDATE article_metadata SET sentiment_* = results
    pass
```

### Afternoon (2-3 hours): Run Enrichment + Validate

**Steps:**
1. Run script: `python scripts/huggingface_enrichment.py`
2. Monitor progress (will take 10-15 min for 5K articles)
3. Validate results in Snowflake:

```sql
SELECT 
    sentiment_label,
    COUNT(*) as article_count,
    AVG(sentiment_score_positive) as avg_positive,
    AVG(sentiment_score_negative) as avg_negative
FROM article_metadata
WHERE sentiment_label IS NOT NULL
GROUP BY sentiment_label;

-- Expected: ~40% positive, ~40% negative, ~20% neutral
```

4. Re-run dbt to update marts with enriched data

---

## Friday: Testing & Documentation (3-4 hours)

### Morning (2 hours): dbt Tests & Data Quality

**Add comprehensive tests:**

```yaml
# models/marts/_schema.yml
models:
  - name: fct_article_events
    description: "Event-level fact table with article and writer context"
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - event_timestamp
            - user_pseudo_id
            - event_name
    columns:
      - name: article_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_articles')
              field: article_id
      - name: engagement_time_sec
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 300  # 5 minutes max
```

**Run all tests:**
```bash
dbt test

# Expected: 25-30 tests, all passing
```

### Afternoon (1-2 hours): Documentation

**Update README with:**
1. Architecture diagram (use diagrams.net or ASCII art)
2. Sample queries showing semantic layer usage
3. Screenshots of Snowflake query results

**Generate dbt docs:**
```bash
dbt docs generate
dbt docs serve

# Opens browser with documentation site
# Take screenshots for your portfolio
```

---

## Week 1 Completion Checklist

By Friday EOD, you should have:

- [x] **Staging models**: 3 models (events, articles, writers)
- [x] **Mart models**: 3 models (fct_article_events, dim_articles, dim_writers)
- [x] **Semantic layer**: 7 metrics defined and queryable
- [x] **AI enrichment**: 5,000 articles with sentiment scores
- [x] **Tests**: 25+ dbt tests passing
- [x] **Documentation**: dbt docs generated
- [x] **Git commits**: Code pushed to GitHub

---

## Week 2 Preview

**Monday-Wednesday: Airflow Orchestration**
- Build DAG: ingest → dbt → HF → dbt
- Deploy to Astro Cloud
- Schedule daily runs

**Thursday-Friday: Superset Dashboards**
- Connect Preset to dbt Semantic Layer
- Build 2 dashboards (writer scorecards, content performance)
- Add natural language query examples

---

## 🎯 Success Metrics for Week 1

**Technical:**
- ✅ Can query `total_pageviews` by writer via MetricFlow
- ✅ All articles have sentiment_label populated
- ✅ fct_article_events has 500K+ rows
- ✅ All dbt tests pass

**Portfolio Impact:**
- ✅ GitHub shows consistent commits (3-5 per day)
- ✅ README has clear architecture explanation
- ✅ Can demo semantic layer queries in interview

---

## 💡 Tips for Success

**Use Claude Code effectively:**
- Generate boilerplate SQL: "Create dbt model for [description]"
- Debug errors: "Fix this dbt compilation error: [paste error]"
- Review code: "Review this SQL for performance issues"

**Stay organized:**
- Commit after each model: `git commit -m "Add stg_ga4_events model"`
- Test frequently: `dbt run -m model_name && dbt test -m model_name`
- Document as you go: Add descriptions in YAML immediately

**Time management:**
- Stuck for >30 min? Ask Claude or skip to next task
- Don't perfect early models - iterate later
- Save complex optimizations for Week 2

---

**Ready to start? See you Monday!** 🚀

Next: [Staging Models Tutorial](staging_models_guide.md)
