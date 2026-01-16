-- models/marts/core/mart_engagement_summary.sql
{{
  config(
    materialized='table',
    tags=['marts', 'aggregated', 'engagement_summary']
  )
}}

WITH weekly_engagement_summary AS (
    SELECT
        DATE_TRUNC('week', event_date) AS week_start_date,
        article_category,
        device_category,
        traffic_medium,
        
        -- Volume metrics
        COUNT(DISTINCT article_id) AS distinct_articles,
        COUNT(DISTINCT user_pseudo_id) AS unique_users,
        COUNT(DISTINCT ga_session_id) AS unique_sessions,
        COUNT(*) AS total_events,
        
        -- Engagement metrics
        COUNT(CASE WHEN is_engaged = 1 THEN 1 END) AS engaged_events,
        COUNT(DISTINCT CASE WHEN is_engaged = 1 THEN user_pseudo_id END) AS engaged_users,
        COUNT(CASE WHEN is_highly_engaged = 1 THEN 1 END) AS highly_engaged_events,
        
        -- Time metrics
        AVG(engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY engagement_time_msec) / 1000.0 AS median_engagement_seconds,
        AVG(percent_scrolled) AS avg_scroll_percent,
        
        -- Quality metrics
        AVG(quality_adjusted_engagement) AS avg_quality_adjusted_engagement,
        SUM(quality_adjusted_engagement) AS total_quality_adjusted_engagement,
        
        -- Revenue metrics
        SUM(estimated_revenue) AS total_revenue,
        AVG(estimated_revenue) AS avg_revenue_per_event,
        
        -- Content mix
        COUNT(CASE WHEN is_premium = TRUE THEN 1 END) AS premium_events,
        COUNT(CASE WHEN is_evergreen = TRUE THEN 1 END) AS evergreen_events,
        COUNT(CASE WHEN content_length_bucket = 'long' OR content_length_bucket = 'very_long' THEN 1 END) AS long_form_events
        
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
    GROUP BY 
        DATE_TRUNC('week', event_date),
        article_category,
        device_category,
        traffic_medium
),

calculated_metrics AS (
    SELECT
        *,
        
        -- Engagement rates
        engaged_users * 1.0 / NULLIF(unique_users, 0) AS engagement_rate,
        engaged_events * 1.0 / NULLIF(total_events, 0) AS event_engagement_rate,
        highly_engaged_events * 1.0 / NULLIF(total_events, 0) AS high_engagement_rate,
        total_quality_adjusted_engagement / NULLIF(unique_users, 0) AS quality_engagement_rate,
        
        -- Session metrics
        total_events * 1.0 / NULLIF(unique_sessions, 0) AS events_per_session,
        engaged_events * 1.0 / NULLIF(unique_sessions, 0) AS engaged_events_per_session,
        
        -- Revenue metrics
        total_revenue / NULLIF(unique_users, 0) AS revenue_per_user,
        (total_revenue / NULLIF(total_events, 0)) * 1000 AS effective_rpm,
        
        -- Content mix percentages
        premium_events * 100.0 / NULLIF(total_events, 0) AS premium_pct,
        evergreen_events * 100.0 / NULLIF(total_events, 0) AS evergreen_pct,
        long_form_events * 100.0 / NULLIF(total_events, 0) AS long_form_pct,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS mart_updated_at
        
    FROM weekly_engagement_summary
)

SELECT * FROM calculated_metrics