-- models/marts/metrics/metrics_baseline.sql
{{
  config(
    materialized='table',
    tags=['marts', 'metrics', 'baseline']
  )
}}

/*
Baseline metrics calculation for the entire dataset.
These serve as benchmarks for experimentation and anomaly detection.

Use Case: "What's our normal engagement rate before we run experiments?"
*/

WITH overall_metrics AS (
    SELECT
        'overall' AS segment,
        'all_time' AS time_period,
        
        -- Volume metrics
        COUNT(DISTINCT article_id) AS total_articles,
        COUNT(DISTINCT user_pseudo_id) AS total_users,
        COUNT(*) AS total_events,
        
        -- Engagement metrics
        AVG(is_engaged) AS engagement_rate,
        AVG(is_highly_engaged) AS high_engagement_rate,
        AVG(quality_adjusted_engagement) AS quality_engagement_rate,
        
        -- Time metrics
        AVG(engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY engagement_time_msec) / 1000.0 AS median_engagement_seconds,
        AVG(percent_scrolled) AS avg_scroll_percent,
        
        -- Revenue metrics
        SUM(estimated_revenue) AS total_revenue,
        AVG(estimated_revenue) AS avg_revenue_per_event,
        SUM(estimated_revenue) / COUNT(DISTINCT user_pseudo_id) AS revenue_per_user,
        
        -- Metadata
        MIN(event_date) AS first_event_date,
        MAX(event_date) AS last_event_date,
        DATEDIFF('day', MIN(event_date), MAX(event_date)) AS days_of_data
        
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
),

category_metrics AS (
    SELECT
        article_category AS segment,
        'by_category' AS time_period,
        
        COUNT(DISTINCT article_id) AS total_articles,
        COUNT(DISTINCT user_pseudo_id) AS total_users,
        COUNT(*) AS total_events,
        
        AVG(is_engaged) AS engagement_rate,
        AVG(is_highly_engaged) AS high_engagement_rate,
        AVG(quality_adjusted_engagement) AS quality_engagement_rate,
        
        AVG(engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY engagement_time_msec) / 1000.0 AS median_engagement_seconds,
        AVG(percent_scrolled) AS avg_scroll_percent,
        
        SUM(estimated_revenue) AS total_revenue,
        AVG(estimated_revenue) AS avg_revenue_per_event,
        SUM(estimated_revenue) / COUNT(DISTINCT user_pseudo_id) AS revenue_per_user,
        
        MIN(event_date) AS first_event_date,
        MAX(event_date) AS last_event_date,
        DATEDIFF('day', MIN(event_date), MAX(event_date)) AS days_of_data
        
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
    GROUP BY article_category
),

device_metrics AS (
    SELECT
        device_category AS segment,
        'by_device' AS time_period,
        
        COUNT(DISTINCT article_id) AS total_articles,
        COUNT(DISTINCT user_pseudo_id) AS total_users,
        COUNT(*) AS total_events,
        
        AVG(is_engaged) AS engagement_rate,
        AVG(is_highly_engaged) AS high_engagement_rate,
        AVG(quality_adjusted_engagement) AS quality_engagement_rate,
        
        AVG(engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY engagement_time_msec) / 1000.0 AS median_engagement_seconds,
        AVG(percent_scrolled) AS avg_scroll_percent,
        
        SUM(estimated_revenue) AS total_revenue,
        AVG(estimated_revenue) AS avg_revenue_per_event,
        SUM(estimated_revenue) / COUNT(DISTINCT user_pseudo_id) AS revenue_per_user,
        
        MIN(event_date) AS first_event_date,
        MAX(event_date) AS last_event_date,
        DATEDIFF('day', MIN(event_date), MAX(event_date)) AS days_of_data
        
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
    GROUP BY device_category
),

combined AS (
    SELECT * FROM overall_metrics
    UNION ALL
    SELECT * FROM category_metrics
    UNION ALL
    SELECT * FROM device_metrics
)

SELECT 
    *,
    CURRENT_TIMESTAMP() AS calculated_at
FROM combined