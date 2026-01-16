-- models/marts/core/mart_article_performance.sql
{{
  config(
    materialized='table',
    tags=['marts', 'aggregated', 'article_performance']
  )
}}

WITH daily_article_events AS (
    SELECT
        article_id,
        event_date,
        article_category,
        content_length_bucket,
        rpm_tier,
        is_premium,
        is_evergreen,
        sentiment_label,
        
        -- Event counts
        COUNT(*) AS total_events,
        COUNT(DISTINCT CASE WHEN event_name = 'page_view' THEN user_pseudo_id END) AS unique_viewers,
        COUNT(DISTINCT CASE WHEN event_name = 'page_view' THEN ga_session_id END) AS unique_sessions,
        
        -- Engagement metrics
        COUNT(CASE WHEN is_engaged = 1 THEN 1 END) AS engaged_events,
        COUNT(DISTINCT CASE WHEN is_engaged = 1 THEN user_pseudo_id END) AS engaged_users,
        COUNT(CASE WHEN is_highly_engaged = 1 THEN 1 END) AS highly_engaged_events,
        COUNT(DISTINCT CASE WHEN is_highly_engaged = 1 THEN user_pseudo_id END) AS highly_engaged_users,
        
        -- Time metrics
        AVG(engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY engagement_time_msec) / 1000.0 AS median_engagement_seconds,
        AVG(percent_scrolled) AS avg_scroll_percent,
        
        -- Revenue metrics
        SUM(estimated_revenue) AS total_revenue,
        AVG(estimated_revenue) AS avg_revenue_per_event,
        
        -- Quality metrics
        AVG(quality_adjusted_engagement) AS avg_quality_adjusted_engagement,
        SUM(quality_adjusted_engagement) AS total_quality_adjusted_engagement,
        
        -- Device breakdown
        COUNT(CASE WHEN device_category = 'mobile' THEN 1 END) AS mobile_events,
        COUNT(CASE WHEN device_category = 'desktop' THEN 1 END) AS desktop_events,
        COUNT(CASE WHEN device_category = 'tablet' THEN 1 END) AS tablet_events,
        
        -- Traffic source breakdown
        COUNT(CASE WHEN traffic_medium = 'organic' THEN 1 END) AS organic_events,
        COUNT(CASE WHEN traffic_medium = 'social' THEN 1 END) AS social_events,
        COUNT(CASE WHEN traffic_medium = 'email' THEN 1 END) AS email_events,
        COUNT(CASE WHEN traffic_medium = 'none' THEN 1 END) AS direct_events
        
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
    GROUP BY 
        article_id,
        event_date,
        article_category,
        content_length_bucket,
        rpm_tier,
        is_premium,
        is_evergreen,
        sentiment_label
),

enriched AS (
    SELECT
        e.*,
        a.title,
        a.writer_id,
        a.publish_date,
        a.word_count,
        a.estimated_rpm,
        a.quality_score,
        
        -- Calculated rates
        e.engaged_users * 1.0 / NULLIF(e.unique_viewers, 0) AS engagement_rate,
        e.highly_engaged_users * 1.0 / NULLIF(e.unique_viewers, 0) AS high_engagement_rate,
        e.total_quality_adjusted_engagement / NULLIF(e.unique_viewers, 0) AS quality_engagement_rate,
        
        -- Revenue per metrics
        e.total_revenue / NULLIF(e.unique_viewers, 0) AS revenue_per_viewer,
        (e.total_revenue / NULLIF(e.unique_viewers, 0)) * 1000 AS actual_rpm,
        
        -- Days since publish
        DATEDIFF('day', a.publish_date, e.event_date) AS days_since_publish,
        
        -- Freshness flag
        CASE 
            WHEN DATEDIFF('day', a.publish_date, e.event_date) <= 7 THEN 'week_1'
            WHEN DATEDIFF('day', a.publish_date, e.event_date) <= 30 THEN 'week_2_to_4'
            WHEN DATEDIFF('day', a.publish_date, e.event_date) <= 90 THEN 'month_2_to_3'
            ELSE 'older'
        END AS content_age_bucket,
        
        -- Device mix percentages
        e.mobile_events * 100.0 / NULLIF(e.total_events, 0) AS mobile_pct,
        e.desktop_events * 100.0 / NULLIF(e.total_events, 0) AS desktop_pct,
        e.tablet_events * 100.0 / NULLIF(e.total_events, 0) AS tablet_pct,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS mart_updated_at
        
    FROM daily_article_events e
    LEFT JOIN {{ ref('dim_articles') }} a ON e.article_id = a.article_id
)

SELECT * FROM enriched