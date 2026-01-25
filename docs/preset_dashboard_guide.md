# Preset Dashboard Design Guide

## Dashboard 1: Experiment Results (The Showpiece!)

**Purpose:** Show how quality-adjusted engagement prevents clickbait

### Charts to Create:

#### 1. Experiment Performance Table
**Chart Type:** Table

**Columns to show:**
- experiment_name
- category  
- engagement_lift_pct (format as %, 1 decimal)
- quality_engagement_lift_pct (format as %, 1 decimal)
- winner
- is_clickbait_variant

**Formatting:**
- Color engagement_lift_pct: Green if positive, red if negative
- Color quality_engagement_lift_pct: Green if positive, red if negative
- Highlight row RED if is_clickbait_variant = TRUE
- Sort by quality_engagement_lift_pct DESC

**SQL (if needed):**
```sql
SELECT 
    experiment_name,
    category,
    ROUND(engagement_lift_pct, 1) AS engagement_lift_pct,
    ROUND(quality_engagement_lift_pct, 1) AS quality_lift_pct,
    winner,
    is_clickbait_variant,
    control_users + treatment_users AS sample_size
FROM experiment_results
ORDER BY quality_engagement_lift_pct DESC
```

---

#### 2. Clickbait Detection Spotlight
**Chart Type:** Big Number (with comparison)

**Metric:** Count of clickbait experiments
**Filter:** WHERE is_clickbait_variant = TRUE

**SQL:**
```sql
SELECT COUNT(*) 
FROM experiment_results 
WHERE is_clickbait_variant = TRUE
```

**Subheader:** "Experiments Prevented from Shipping"

---

#### 3. Engagement vs Quality Scatter Plot
**Chart Type:** Scatter Plot

**X-Axis:** engagement_lift_pct
**Y-Axis:** quality_engagement_lift_pct
**Color:** is_clickbait_variant
**Label:** experiment_name

**Why this is powerful:**
- Shows most experiments in top-right quadrant (good!)
- Clickbait experiments in top-left quadrant (high engagement, low quality)
- Quality-focused experiments in bottom-right (low engagement, high quality)

**SQL:**
```sql
SELECT 
    experiment_name,
    engagement_lift_pct AS engagement_lift,
    quality_engagement_lift_pct AS quality_lift,
    is_clickbait_variant,
    category
FROM experiment_results
```

---

#### 4. Winners by Category
**Chart Type:** Bar Chart

**Dimension:** category
**Metric:** COUNT(CASE WHEN winner = 'treatment_wins' THEN 1 END)
**Order:** DESC

**SQL:**
```sql
SELECT 
    category,
    COUNT(CASE WHEN winner = 'treatment_wins' THEN 1 END) AS winning_experiments
FROM experiment_results
GROUP BY category
ORDER BY winning_experiments DESC
```

---

#### 5. Sample Size Distribution
**Chart Type:** Bar Chart (horizontal)

**Dimension:** experiment_name
**Metric:** control_users + treatment_users
**Color by:** statistical_significance

**SQL:**
```sql
SELECT 
    experiment_name,
    control_users + treatment_users AS total_sample_size,
    statistical_significance
FROM experiment_results
ORDER BY total_sample_size DESC
```

---

## Dashboard 2: Writer Performance Scorecards

**Purpose:** Show automated writer analytics (Arena Group parallel)

### Charts to Create:

#### 1. Top Writers Leaderboard
**Chart Type:** Table

**Columns:**
- writer_name
- articles_published
- revenue_per_article (format as currency)
- engagement_rate (format as %)
- quality_tier
- productivity_status

**Filter:** week_start_date = most recent week
**Sort:** revenue_per_article DESC
**Limit:** 20

**SQL:**
```sql
SELECT 
    writer_name,
    articles_published,
    ROUND(revenue_per_article, 2) AS revenue_per_article,
    ROUND(engagement_rate * 100, 1) AS engagement_rate_pct,
    quality_tier,
    productivity_status
FROM mart_writer_performance
WHERE week_start_date = (SELECT MAX(week_start_date) FROM mart_writer_performance)
ORDER BY revenue_per_article DESC
LIMIT 20
```

---

#### 2. Quality Distribution
**Chart Type:** Pie Chart

**Dimension:** quality_tier
**Metric:** COUNT(DISTINCT writer_id)

**SQL:**
```sql
SELECT 
    quality_tier,
    COUNT(DISTINCT writer_id) AS writers
FROM mart_writer_performance
WHERE week_start_date = (SELECT MAX(week_start_date) FROM mart_writer_performance)
GROUP BY quality_tier
```

---

#### 3. Productivity vs Quality Scatter
**Chart Type:** Scatter Plot

**X-Axis:** articles_published
**Y-Axis:** quality_engagement_rate
**Color:** quality_tier
**Size:** revenue_per_article

**SQL:**
```sql
SELECT 
    writer_name,
    articles_published,
    quality_engagement_rate,
    quality_tier,
    revenue_per_article
FROM mart_writer_performance
WHERE week_start_date = (SELECT MAX(week_start_date) FROM mart_writer_performance)
```

---

#### 4. Revenue Trends Over Time
**Chart Type:** Line Chart

**X-Axis:** week_start_date
**Y-Axis:** AVG(revenue_per_article)
**Group by:** quality_tier

**SQL:**
```sql
SELECT 
    week_start_date,
    quality_tier,
    AVG(revenue_per_article) AS avg_revenue
FROM mart_writer_performance
GROUP BY week_start_date, quality_tier
ORDER BY week_start_date
```

---

## Dashboard 3: Article Performance

**Purpose:** Show content analytics

### Charts to Create:

#### 1. Category Performance Comparison
**Chart Type:** Bar Chart (grouped)

**Dimension:** article_category
**Metrics:**
- AVG(engagement_rate) 
- AVG(quality_engagement_rate)

**SQL:**
```sql
SELECT 
    article_category,
    AVG(engagement_rate) AS avg_engagement,
    AVG(quality_engagement_rate) AS avg_quality_engagement
FROM mart_article_performance
GROUP BY article_category
ORDER BY avg_quality_engagement DESC
```

---

#### 2. Top Performing Articles
**Chart Type:** Table

**Columns:**
- title
- article_category
- unique_viewers
- engagement_rate
- quality_engagement_rate
- revenue_per_viewer

**Filter:** event_date in last 7 days
**Sort:** quality_engagement_rate DESC
**Limit:** 20

**SQL:**
```sql
SELECT 
    a.title,
    p.article_category,
    p.unique_viewers,
    ROUND(p.engagement_rate * 100, 1) AS engagement_pct,
    ROUND(p.quality_engagement_rate * 100, 1) AS quality_pct,
    ROUND(p.revenue_per_viewer, 4) AS revenue_per_viewer
FROM mart_article_performance p
JOIN dim_articles a ON p.article_id = a.article_id
WHERE p.event_date >= DATEADD('day', -7, CURRENT_DATE())
ORDER BY p.quality_engagement_rate DESC
LIMIT 20
```

---

#### 3. Engagement by Device
**Chart Type:** Pie Chart

**Dimension:** device_category
**Metric:** SUM(unique_users)

**SQL:**
```sql
SELECT 
    device_category,
    SUM(unique_users) AS total_users
FROM mart_engagement_summary
GROUP BY device_category
```

---

#### 4. Content Age Performance
**Chart Type:** Line Chart

**X-Axis:** content_age_bucket (ordered: week_1, week_2_to_4, month_2_to_3, older)
**Y-Axis:** AVG(engagement_rate)

**SQL:**
```sql
SELECT 
    content_age_bucket,
    AVG(engagement_rate) AS avg_engagement
FROM mart_article_performance
GROUP BY content_age_bucket
ORDER BY 
    CASE content_age_bucket
        WHEN 'week_1' THEN 1
        WHEN 'week_2_to_4' THEN 2
        WHEN 'month_2_to_3' THEN 3
        ELSE 4
    END
```

---

## Dashboard Layout Tips

### Dashboard 1: Experiment Results (4x3 grid)
```
┌─────────────────────┬─────────────┐
│                     │  Clickbait  │
│  Experiment Table   │  Detection  │
│  (Wide)             │  (Big #)    │
│                     │             │
├─────────────────────┴─────────────┤
│                                   │
│  Engagement vs Quality Scatter    │
│  (Full width)                     │
│                                   │
├────────────────┬──────────────────┤
│  Winners by    │  Sample Size     │
│  Category      │  Distribution    │
│                │                  │
└────────────────┴──────────────────┘
```

### Dashboard 2: Writer Scorecards (3x3 grid)
```
┌─────────────────────────────────┐
│  Top Writers Leaderboard        │
│  (Full width)                   │
├──────────────┬──────────────────┤
│  Quality     │  Productivity    │
│  Distribution│  vs Quality      │
│  (Pie)       │  (Scatter)       │
├──────────────┴──────────────────┤
│  Revenue Trends Over Time       │
│  (Full width line chart)        │
└─────────────────────────────────┘
```

---

## Color Scheme Recommendations

**For clickbait/quality:**
- ✅ Green: Good quality, winners
- ⚠️ Yellow: Neutral, borderline
- ❌ Red: Clickbait, losers

**For lift percentages:**
- Green: Positive lift
- Red: Negative lift
- Gray: No change

**For quality tiers:**
- Purple: high_quality
- Blue: good_quality
- Orange: acceptable_quality
- Red: needs_improvement

---

## Key Metrics to Highlight

1. **"25% engagement lift but -8% quality"** - The clickbait example (exp_006)
2. **"80%+ of experiments safe to ship"** - Show quality-adjusted prevents bad decisions
3. **"$X revenue per article"** - Writer profitability tracking
4. **"XX% engagement rate overall"** - Baseline performance

---

## Pro Tips for Preset

1. **Use SQL Lab first** - Test your queries before creating charts
2. **Save datasets** - Create virtual datasets for complex queries
3. **Add filters** - Time range, category, writer filters on dashboards
4. **Mobile friendly** - Preset dashboards work on mobile automatically
5. **Share dashboards** - Get a public link to show in your portfolio

---

## Next Steps After Dashboard Creation

1. **Screenshot everything** - For your portfolio/resume
2. **Record a Loom video** - Walk through the dashboards (~2 min)
3. **Add to GitHub README** - Embed screenshots
4. **LinkedIn post** - Share the project with screenshots

Let me know when you're ready to start building and I'll guide you through each chart! 🎨