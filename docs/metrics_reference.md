# Metrics Reference - Week 2 Day 1

## Core Engagement Metrics

### is_engaged (Binary Flag)
**Definition:** User spent 60+ seconds OR scrolled 75%+ of article  
**Type:** Boolean (0/1)  
**Business Rule:** Separates genuine readers from bounce traffic  
**Threshold Rationale:** 
- 60 seconds = enough time to read ~200 words
- 75% scroll = saw most of the content

**SQL:**
```sql
CASE 
    WHEN engagement_time_msec >= 60000 OR percent_scrolled >= 75
    THEN 1 
    ELSE 0 
END AS is_engaged
```

### is_highly_engaged (Binary Flag)
**Definition:** User spent 3+ minutes OR scrolled 90%+ of article  
**Type:** Boolean (0/1)  
**Business Rule:** Identifies deeply engaged "super readers"  
**Use Case:** Premium content optimization, newsletter targeting

**SQL:**
```sql
CASE
    WHEN engagement_time_msec >= 180000 OR percent_scrolled >= 90
    THEN 1
    ELSE 0
END AS is_highly_engaged
```

### quality_adjusted_engagement (Continuous 0-1)
**Definition:** Engagement × AI Quality Score  
**Type:** Decimal (0.0 to 1.0)  
**Business Rule:** PRIMARY METRIC for experiments - prevents clickbait  
**Why Important:** 
- Clickbait headline: High engagement, low quality → Low score
- Quality content: High engagement, high quality → High score
- This ensures we optimize for long-term value

**SQL:**
```sql
CASE 
    WHEN is_engaged = 1
    THEN COALESCE(quality_score, 0.5)
    ELSE 0
END AS quality_adjusted_engagement
```

**Example:**
- Article A: 40% engagement, 0.85 quality → 0.34 quality-adjusted
- Article B: 40% engagement, 0.45 quality → 0.18 quality-adjusted
→ Article A wins despite same engagement rate

---

## Revenue Metrics

### estimated_revenue (Per Event)
**Definition:** (Article RPM / 1000) per page view  
**Type:** Decimal  
**Business Rule:** Revenue attribution at event level  

**SQL:**
```sql
estimated_rpm / 1000.0 AS estimated_revenue
```

**Aggregation Example:**
```sql
-- Total revenue by article
SELECT 
    article_id,
    title,
    COUNT(*) AS page_views,
    SUM(estimated_revenue) AS total_revenue,
    total_revenue / page_views AS actual_rpm
FROM fct_article_events
WHERE event_name = 'page_view'
GROUP BY article_id, title
```

---

## Dimension Classifications

### content_length_bucket
**Buckets:**
- short: < 500 words
- medium: 500-999 words
- long: 1000-1999 words  
- very_long: 2000+ words

**Use Case:** Analyze engagement patterns by content length

### rpm_tier
**Buckets:**
- high: RPM >= $8.00
- medium: $5.00 <= RPM < $8.00
- low: RPM < $5.00

**Use Case:** Focus optimization on high-value content

### experience_level (Writer)
**Buckets:**
- new: < 6 months tenure
- established: 6-23 months
- veteran: 24+ months

**Use Case:** Compare performance by writer maturity

### productivity_tier (Writer)
**Buckets:**
- high_volume: 20+ articles/month
- medium_volume: 10-19 articles/month
- low_volume: < 10 articles/month

**Use Case:** Resource allocation and capacity planning

---

## Common Analytics Queries

### 1. Engagement Rate by Category
```sql
SELECT
    article_category,
    COUNT(DISTINCT CASE WHEN event_name = 'page_view' THEN user_pseudo_id END) AS viewers,
    COUNT(DISTINCT CASE WHEN is_engaged = 1 THEN user_pseudo_id END) AS engaged_users,
    engaged_users * 1.0 / viewers AS engagement_rate,
    AVG(quality_adjusted_engagement) AS avg_quality_adj_engagement
FROM fct_article_events
GROUP BY article_category
ORDER BY engagement_rate DESC
```

### 2. Writer Performance Scorecard
```sql
SELECT
    w.writer_name,
    w.experience_level,
    w.contract_type,
    COUNT(DISTINCT f.article_id) AS articles_published,
    AVG(f.is_engaged) AS avg_engagement_rate,
    SUM(f.estimated_revenue) AS total_revenue,
    total_revenue / articles_published AS revenue_per_article,
    AVG(f.quality_adjusted_engagement) AS quality_score
FROM fct_article_events f
JOIN dim_writers w ON f.writer_id = w.writer_id
WHERE f.event_name = 'page_view'
GROUP BY w.writer_name, w.experience_level, w.contract_type
ORDER BY quality_score DESC
```

### 3. Content Performance Over Time
```sql
SELECT
    DATE_TRUNC('week', event_date) AS week,
    article_category,
    COUNT(DISTINCT article_id) AS articles,
    AVG(is_engaged) AS engagement_rate,
    SUM(estimated_revenue) AS revenue,
    AVG(quality_adjusted_engagement) AS quality_metric
FROM fct_article_events
WHERE event_name = 'page_view'
GROUP BY week, article_category
ORDER BY week DESC, article_category
```

### 4. Device Mix Analysis
```sql
SELECT
    device_category,
    COUNT(DISTINCT user_pseudo_id) AS users,
    AVG(engagement_time_msec) / 1000.0 AS avg_seconds,
    AVG(percent_scrolled) AS avg_scroll_pct,
    AVG(is_engaged) AS engagement_rate,
    SUM(estimated_revenue) AS revenue
FROM fct_article_events
WHERE event_name = 'page_view'
GROUP BY device_category
```

### 5. Traffic Source Attribution
```sql
SELECT
    traffic_source,
    traffic_medium,
    COUNT(DISTINCT user_pseudo_id) AS users,
    AVG(is_engaged) AS engagement_rate,
    AVG(is_highly_engaged) AS high_engagement_rate,
    SUM(estimated_revenue) AS revenue,
    revenue / users AS revenue_per_user
FROM fct_article_events
WHERE event_name = 'page_view'
GROUP BY traffic_source, traffic_medium
ORDER BY users DESC
```

---

## Experimentation Metrics (Week 2)

When we add experiments in Week 2, we'll calculate:

### Lift Calculation
```sql
WITH control AS (
    SELECT AVG(quality_adjusted_engagement) AS control_metric
    FROM fct_article_events
    WHERE experiment_id = 'exp_001' AND variant = 'control'
),
treatment AS (
    SELECT AVG(quality_adjusted_engagement) AS treatment_metric
    FROM fct_article_events  
    WHERE experiment_id = 'exp_001' AND variant = 'treatment'
)
SELECT
    treatment_metric,
    control_metric,
    (treatment_metric - control_metric) / control_metric * 100 AS lift_pct,
    treatment_metric - control_metric AS absolute_lift
FROM treatment, control
```

### Statistical Significance
```sql
-- Will use t-test or z-test depending on sample size
-- p-value < 0.05 = statistically significant
```

---

## Quality Score Details

### How quality_score is Calculated (in dim_articles)
```sql
CASE 
    WHEN sentiment_label = 'POSITIVE' THEN sentiment_score_positive
    WHEN sentiment_label = 'NEGATIVE' THEN 1 - sentiment_score_negative  
    ELSE 0.5  -- neutral default
END AS quality_score
```

**Range:** 0.0 (terrible quality) to 1.0 (excellent quality)

**Interpretation:**
- 0.7 - 1.0: High quality, trust-building content
- 0.5 - 0.7: Neutral/adequate quality  
- 0.3 - 0.5: Questionable quality
- 0.0 - 0.3: Low quality/clickbait

**Important:** This is populated by AI sentiment analysis in Week 1 Day 4.
Until then, defaults to 0.5 (neutral).