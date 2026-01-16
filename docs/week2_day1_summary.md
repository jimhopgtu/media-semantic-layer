# Week 2, Day 1: Dimensional Models - Complete! ✅

## What We Built Today

I've created the foundational dimensional model layer for your content experimentation platform. This builds on your Day 1 staging models and creates the analytics-ready tables.

## Files Created

### 1. **dim_articles.sql** - Article Dimension
- **Grain:** One row per article
- **Features:**
  - Content length buckets (short/medium/long/very_long)
  - RPM tier classification (high/medium/low)
  - Quality score from AI sentiment
  - Evergreen content flag
- **Key metric:** `quality_score` prevents clickbait optimization

### 2. **dim_writers.sql** - Writer Dimension  
- **Grain:** One row per writer
- **Features:**
  - Experience level (new/established/veteran)
  - Employment category (full_time/flexible)
  - Productivity tier (high/medium/low volume)
  
### 3. **fct_article_events.sql** - Event Fact Table
- **Grain:** One row per event (user + article + timestamp)
- **Key Metrics:**
  - `is_engaged`: 60+ seconds OR 75%+ scrolled
  - `is_highly_engaged`: 3+ minutes OR 90%+ scrolled  
  - `estimated_revenue`: Based on article RPM
  - `quality_adjusted_engagement`: **PRIMARY METRIC** - prevents clickbait
- **Context:** Device, geo, traffic source, article/writer attributes

### 4. **dim_experiments.sql** - Placeholder
- Empty structure for Week 2 experimentation data
- Prevents downstream errors while we build

### 5. **core.yml** - Complete Documentation
- Comprehensive column descriptions
- Business rules documented
- Data quality tests for all key fields
- Relationships validated between dimensions and facts

## Directory Structure

```
dbt_project/models/marts/core/
├── dim_articles.sql
├── dim_writers.sql
├── dim_experiments.sql (placeholder)
├── fct_article_events.sql
└── core.yml
```

## Next Steps: Run the Models

### 1. **Build dimension tables first:**
```bash
cd "G:\My Drive\AI\media-semantic-layer\dbt_project"
dbt run --select dim_articles dim_writers
```

### 2. **Then build the fact table:**
```bash
dbt run --select fct_article_events
```

### 3. **Run all marts together:**
```bash
dbt run --select marts.core
```

### 4. **Run tests to validate:**
```bash
dbt test --select marts.core
```

## What This Enables

### ✅ **Analytics Ready**
- Query engagement metrics by article, writer, category, device
- Calculate writer profitability (revenue per article)
- Track content performance over time

### ✅ **Experimentation Ready**
- Quality-adjusted engagement prevents clickbait
- Event grain allows A/B test analysis
- Composite metrics support multi-variate testing

### ✅ **Self-Service Ready**
- Well-documented dimensions
- Pre-calculated engagement flags
- Consistent grain and relationships

## Key Design Decisions

### 1. **Quality-Adjusted Engagement Metric**
```sql
CASE 
    WHEN is_engaged = 1
    THEN quality_score  -- AI sentiment 0-1
    ELSE 0
END AS quality_adjusted_engagement
```

**Why:** Prevents optimizing for clickbait headlines. A headline that gets clicks but delivers poor content will have:
- High engagement rate (clicks)
- Low sentiment score (quality)
- Low quality-adjusted engagement (primary metric)

### 2. **Event Grain (Not Aggregated)**
We kept events at the finest grain because:
- Enables flexible aggregation in BI layer
- Supports A/B test analysis
- Allows cohort analysis
- Preserves full context for ML models

### 3. **Type 1 SCD Dimensions**
Simple updates-in-place for dimensions because:
- We don't need historical article attribute tracking
- Simplifies queries and maintenance
- If needed later, can add SCD Type 2 for writers

## Metrics You Can Now Calculate

### Engagement Metrics
```sql
-- Overall engagement rate
SELECT 
    COUNT(DISTINCT CASE WHEN is_engaged = 1 THEN user_pseudo_id END) * 1.0 /
    COUNT(DISTINCT user_pseudo_id) AS engagement_rate
FROM fct_article_events
WHERE event_name = 'page_view'
```

### Writer Performance
```sql
-- Revenue per article by writer
SELECT 
    w.writer_name,
    COUNT(DISTINCT f.article_id) AS article_count,
    SUM(f.estimated_revenue) AS total_revenue,
    SUM(f.estimated_revenue) / COUNT(DISTINCT f.article_id) AS revenue_per_article
FROM fct_article_events f
JOIN dim_writers w ON f.writer_id = w.writer_id
GROUP BY w.writer_name
ORDER BY revenue_per_article DESC
```

### Content Performance
```sql
-- Best performing categories by quality-adjusted engagement
SELECT
    article_category,
    AVG(is_engaged) AS engagement_rate,
    AVG(quality_adjusted_engagement) AS quality_adj_engagement,
    COUNT(DISTINCT article_id) AS article_count
FROM fct_article_events
WHERE event_name = 'page_view'
GROUP BY article_category
ORDER BY quality_adj_engagement DESC
```

## How This Mirrors Your Resume Experience

### The Arena Group Parallel
Just like your writer profitability system that:
- Tracked 100+ writers with weekly scorecards
- Combined revenue, engagement, and content ROI
- Informed editorial strategy and compensation

This dimensional model provides:
- Writer dimension with productivity/experience tiers
- Revenue metrics at event grain
- Quality-adjusted engagement to prevent gaming

### Hearst Newspapers Parallel  
Similar to your subscriber journey analysis that:
- Merged GA, email, and subscriber data in BigQuery
- Enabled anonymous-to-subscriber journey tracking
- Contributed to 15%+ subscriber growth

This fact table enables:
- User journey analysis across articles
- Device/traffic source attribution
- Cohort-based engagement analysis

## Tomorrow: Day 2 - Aggregated Metrics Layer

We'll build on these dimensional models to create:
- **mart_article_performance** - Daily article metrics
- **mart_writer_performance** - Weekly writer scorecards  
- **mart_engagement_summary** - Category/device rollups

These will be the "business user" tables that power your dashboards!

---

**Ready to run these models?** Execute the dbt commands above and let me know if you hit any issues!