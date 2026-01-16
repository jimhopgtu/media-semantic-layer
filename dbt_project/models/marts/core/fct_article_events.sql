-- models/marts/core/fct_article_events.sql
{{
  config(
    materialized='table',
    tags=['marts', 'fact', 'events']
  )
}}

WITH events AS (
    SELECT * FROM {{ ref('stg_events') }}
),

articles AS (
    SELECT * FROM {{ ref('dim_articles') }}
),

writers AS (
    SELECT * FROM {{ ref('dim_writers') }}
),

-- Join events with dimensions to create fact table
fact_events AS (
    SELECT
        -- Event identifiers (composite grain: user + article + timestamp)
        e.user_pseudo_id,
        e.ga_session_id,
        e.event_timestamp,
        e.event_name,
        
        -- Foreign keys to dimensions
        e.article_id,
        e.writer_id,
        
        -- Event-level metrics
        e.engagement_time_msec,
        e.percent_scrolled,
        
        -- Derived engagement flags
        CASE 
            WHEN e.engagement_time_msec >= 60000 -- 60 seconds
                OR e.percent_scrolled >= 75
            THEN 1 
            ELSE 0 
        END AS is_engaged,
        
        CASE
            WHEN e.engagement_time_msec >= 180000 -- 3 minutes
                OR e.percent_scrolled >= 90
            THEN 1
            ELSE 0
        END AS is_highly_engaged,
        
        -- Revenue metrics (from article dimension)
        a.estimated_rpm,
        (a.estimated_rpm / 1000.0) AS estimated_revenue,
        
        -- Quality-adjusted engagement (prevents clickbait optimization)
        CASE 
            WHEN e.engagement_time_msec >= 60000 OR e.percent_scrolled >= 75
            THEN COALESCE(a.quality_score, 0.5)
            ELSE 0
        END AS quality_adjusted_engagement,
        
        -- Context attributes (for slicing/dicing)
        e.event_date,
        e.device_category,
        e.device_os,
        e.device_browser,
        e.geo_country,
        e.geo_region,
        e.geo_city,
        e.traffic_source,
        e.traffic_medium,
        e.traffic_campaign,
        
        -- Article context
        a.category AS article_category,
        a.content_length_bucket,
        a.rpm_tier,
        a.is_premium,
        a.is_evergreen,
        a.sentiment_label,
        
        -- Writer context
        w.primary_category AS writer_primary_category,
        w.experience_level AS writer_experience_level,
        w.contract_type AS writer_contract_type,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS fact_created_at
        
    FROM events e
    LEFT JOIN articles a ON e.article_id = a.article_id
    LEFT JOIN writers w ON e.writer_id = w.writer_id
)

SELECT * FROM fact_events