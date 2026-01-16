-- models/marts/fct_article_events.sql
{{
  config(
    materialized='table',
    tags=['marts', 'facts']
  )
}}

WITH events AS (
    SELECT * FROM {{ ref('stg_events') }}
),

articles AS (
    SELECT * FROM {{ ref('stg_articles') }}
),

writers AS (
    SELECT * FROM {{ ref('stg_writers') }}
),

joined AS (
    SELECT

        MD5(CONCAT(e.user_pseudo_id, e.ga_session_id, e.event_timestamp)) AS event_id,

        -- Event fields
        e.event_date,
        e.event_timestamp,
        e.event_name,
        e.user_pseudo_id,
        e.ga_session_id,

        -- Engagement metrics
        e.engagement_time_msec,
        e.percent_scrolled,

        -- Device info
        e.device_category,
        e.device_os,
        e.device_browser,

        -- Geo info
        e.geo_country,
        e.geo_region,
        e.geo_city,

        -- Traffic source
        e.traffic_source,
        e.traffic_medium,
        e.traffic_campaign,

        -- Article attributes
        a.article_id,
        a.title,
        a.category,
        a.word_count,
        a.is_premium,
        a.estimated_rpm,
        a.is_evergreen,

        -- Sentiment fields
        a.sentiment_score_positive,
        a.sentiment_score_negative,
        a.sentiment_label,

        -- Writer info
        w.writer_id,
        w.writer_name,
        w.primary_category AS writer_category,
        w.contract_type,
        w.tenure_months,

        -- Calculated fields
        e.engagement_time_msec / 1000.0 AS engagement_time_sec,
        CASE
            WHEN e.engagement_time_msec > 60000 OR e.percent_scrolled >= 75
            THEN TRUE
            ELSE FALSE
        END AS is_engaged,
        a.estimated_rpm * 0.001 AS revenue_estimate

    FROM events e
    INNER JOIN articles a ON e.article_id = a.article_id
    INNER JOIN writers w ON a.writer_id = w.writer_id
)

SELECT * FROM joined
