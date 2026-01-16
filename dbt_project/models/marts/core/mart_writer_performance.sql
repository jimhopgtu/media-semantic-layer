-- models/marts/core/mart_writer_performance.sql
{{
  config(
    materialized='table',
    tags=['marts', 'aggregated', 'writer_performance']
  )
}}

WITH weekly_writer_metrics AS (
    SELECT
        f.writer_id,
        DATE_TRUNC('week', f.event_date) AS week_start_date,
        
        -- Article counts
        COUNT(DISTINCT f.article_id) AS articles_published,
        
        -- Audience metrics
        COUNT(DISTINCT CASE WHEN f.event_name = 'page_view' THEN f.user_pseudo_id END) AS unique_viewers,
        COUNT(CASE WHEN f.event_name = 'page_view' THEN 1 END) AS total_page_views,
        
        -- Engagement metrics
        COUNT(DISTINCT CASE WHEN f.is_engaged = 1 THEN f.user_pseudo_id END) AS engaged_users,
        COUNT(CASE WHEN f.is_engaged = 1 THEN 1 END) AS engaged_events,
        AVG(CASE WHEN f.event_name = 'page_view' THEN f.engagement_time_msec / 1000.0 END) AS avg_engagement_seconds,
        AVG(CASE WHEN f.event_name = 'page_view' THEN f.percent_scrolled END) AS avg_scroll_percent,
        
        -- Quality metrics
        AVG(f.quality_adjusted_engagement) AS avg_quality_adjusted_engagement,
        SUM(f.quality_adjusted_engagement) AS total_quality_adjusted_engagement,
        
        -- Revenue metrics
        SUM(f.estimated_revenue) AS total_revenue,
        AVG(f.estimated_revenue) AS avg_revenue_per_event,
        
        -- Content mix
        COUNT(DISTINCT CASE WHEN f.is_premium = TRUE THEN f.article_id END) AS premium_articles,
        COUNT(DISTINCT CASE WHEN f.content_length_bucket = 'long' OR f.content_length_bucket = 'very_long' THEN f.article_id END) AS long_form_articles,
        
        -- Category distribution (assuming writer can write in multiple categories)
        COUNT(DISTINCT f.article_category) AS categories_covered
        
    FROM {{ ref('fct_article_events') }} f
    WHERE f.event_name = 'page_view'
    GROUP BY 
        f.writer_id,
        DATE_TRUNC('week', f.event_date)
),

enriched AS (
    SELECT
        m.*,
        w.writer_name,
        w.primary_category,
        w.contract_type,
        w.experience_level,
        w.productivity_tier,
        w.target_articles_per_month,
        w.tenure_months,
        
        -- Calculated rates
        m.engaged_users * 1.0 / NULLIF(m.unique_viewers, 0) AS engagement_rate,
        m.total_quality_adjusted_engagement / NULLIF(m.unique_viewers, 0) AS quality_engagement_rate,
        
        -- Per-article metrics (like Arena Group scorecards)
        m.total_revenue / NULLIF(m.articles_published, 0) AS revenue_per_article,
        m.unique_viewers / NULLIF(m.articles_published, 0) AS avg_viewers_per_article,
        m.engaged_users / NULLIF(m.articles_published, 0) AS avg_engaged_users_per_article,
        
        -- Productivity metrics
        m.articles_published * 4.33 AS estimated_monthly_articles, -- 4.33 weeks per month
        CASE 
            WHEN m.articles_published * 4.33 >= w.target_articles_per_month THEN 'on_target'
            WHEN m.articles_published * 4.33 >= w.target_articles_per_month * 0.8 THEN 'slightly_below'
            ELSE 'below_target'
        END AS productivity_status,
        
        -- Content quality flags
        CASE
            WHEN m.avg_quality_adjusted_engagement >= 0.35 THEN 'high_quality'
            WHEN m.avg_quality_adjusted_engagement >= 0.25 THEN 'good_quality'
            WHEN m.avg_quality_adjusted_engagement >= 0.15 THEN 'acceptable_quality'
            ELSE 'needs_improvement'
        END AS quality_tier,
        
        -- Premium content focus
        m.premium_articles * 100.0 / NULLIF(m.articles_published, 0) AS premium_article_pct,
        
        -- Long-form content focus
        m.long_form_articles * 100.0 / NULLIF(m.articles_published, 0) AS long_form_pct,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS mart_updated_at
        
    FROM weekly_writer_metrics m
    LEFT JOIN {{ ref('dim_writers') }} w ON m.writer_id = w.writer_id
)

SELECT * FROM enriched