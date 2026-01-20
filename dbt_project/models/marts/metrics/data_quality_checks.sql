-- models/marts/metrics/data_quality_checks.sql
{{
  config(
    materialized='table',
    tags=['marts', 'metrics', 'data_quality']
  )
}}

/*
Data quality validation checks across all layers.
Identifies anomalies, missing data, and metric reasonableness.

Use Case: "Is our data trustworthy? Are there any red flags?"
*/

WITH event_quality AS (
    SELECT
        'event_completeness' AS check_category,
        'Events with all required fields' AS check_name,
        COUNT(*) AS total_records,
        COUNT(CASE WHEN article_id IS NOT NULL 
                   AND user_pseudo_id IS NOT NULL 
                   AND event_date IS NOT NULL 
                   AND event_timestamp IS NOT NULL 
                   THEN 1 END) AS passed_records,
        COUNT(CASE WHEN article_id IS NOT NULL 
                   AND user_pseudo_id IS NOT NULL 
                   AND event_date IS NOT NULL 
                   AND event_timestamp IS NOT NULL 
                   THEN 1 END) * 100.0 / COUNT(*) AS pass_rate_pct,
        CASE 
            WHEN COUNT(CASE WHEN article_id IS NOT NULL 
                           AND user_pseudo_id IS NOT NULL 
                           AND event_date IS NOT NULL 
                           AND event_timestamp IS NOT NULL 
                           THEN 1 END) * 100.0 / COUNT(*) >= 95 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS status
    FROM {{ ref('fct_article_events') }}
),

engagement_reasonableness AS (
    SELECT
        'engagement_metrics' AS check_category,
        'Engagement time within reasonable bounds' AS check_name,
        COUNT(*) AS total_records,
        COUNT(CASE WHEN engagement_time_msec BETWEEN 0 AND 3600000 -- 0 to 1 hour
                   THEN 1 END) AS passed_records,
        COUNT(CASE WHEN engagement_time_msec BETWEEN 0 AND 3600000 
                   THEN 1 END) * 100.0 / COUNT(*) AS pass_rate_pct,
        CASE 
            WHEN COUNT(CASE WHEN engagement_time_msec BETWEEN 0 AND 3600000 
                           THEN 1 END) * 100.0 / COUNT(*) >= 98 
            THEN 'PASS' 
            ELSE 'WARN' 
        END AS status
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
),

scroll_reasonableness AS (
    SELECT
        'engagement_metrics' AS check_category,
        'Scroll percent within valid range' AS check_name,
        COUNT(*) AS total_records,
        COUNT(CASE WHEN percent_scrolled BETWEEN 0 AND 100 
                   THEN 1 END) AS passed_records,
        COUNT(CASE WHEN percent_scrolled BETWEEN 0 AND 100 
                   THEN 1 END) * 100.0 / COUNT(*) AS pass_rate_pct,
        CASE 
            WHEN COUNT(CASE WHEN percent_scrolled BETWEEN 0 AND 100 
                           THEN 1 END) * 100.0 / COUNT(*) >= 98 
            THEN 'PASS' 
            ELSE 'WARN' 
        END AS status
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
),

dimension_referential_integrity AS (
    SELECT
        'referential_integrity' AS check_category,
        'All articles exist in dim_articles' AS check_name,
        COUNT(DISTINCT f.article_id) AS total_records,
        COUNT(DISTINCT CASE WHEN d.article_id IS NOT NULL THEN f.article_id END) AS passed_records,
        COUNT(DISTINCT CASE WHEN d.article_id IS NOT NULL THEN f.article_id END) * 100.0 / 
            COUNT(DISTINCT f.article_id) AS pass_rate_pct,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN d.article_id IS NOT NULL THEN f.article_id END) * 100.0 / 
                COUNT(DISTINCT f.article_id) >= 99 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS status
    FROM {{ ref('fct_article_events') }} f
    LEFT JOIN {{ ref('dim_articles') }} d ON f.article_id = d.article_id
),

writer_referential_integrity AS (
    SELECT
        'referential_integrity' AS check_category,
        'All writers exist in dim_writers' AS check_name,
        COUNT(DISTINCT f.writer_id) AS total_records,
        COUNT(DISTINCT CASE WHEN w.writer_id IS NOT NULL THEN f.writer_id END) AS passed_records,
        COUNT(DISTINCT CASE WHEN w.writer_id IS NOT NULL THEN f.writer_id END) * 100.0 / 
            COUNT(DISTINCT f.writer_id) AS pass_rate_pct,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN w.writer_id IS NOT NULL THEN f.writer_id END) * 100.0 / 
                COUNT(DISTINCT f.writer_id) >= 99 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS status
    FROM {{ ref('fct_article_events') }} f
    LEFT JOIN {{ ref('dim_writers') }} w ON f.writer_id = w.writer_id
),

engagement_rate_check AS (
    SELECT
        'metric_reasonableness' AS check_category,
        'Overall engagement rate within expected range (15-50%)' AS check_name,
        1 AS total_records,
        CASE WHEN AVG(is_engaged) BETWEEN 0.15 AND 0.50 THEN 1 ELSE 0 END AS passed_records,
        CASE WHEN AVG(is_engaged) BETWEEN 0.15 AND 0.50 THEN 100.0 ELSE 0.0 END AS pass_rate_pct,
        CASE 
            WHEN AVG(is_engaged) BETWEEN 0.15 AND 0.50 THEN 'PASS'
            WHEN AVG(is_engaged) BETWEEN 0.10 AND 0.60 THEN 'WARN'
            ELSE 'FAIL' 
        END AS status
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
),

quality_score_distribution AS (
    SELECT
        'metric_reasonableness' AS check_category,
        'Quality scores properly distributed (0.3-0.8 range)' AS check_name,
        COUNT(*) AS total_records,
        COUNT(CASE WHEN quality_adjusted_engagement BETWEEN 0 AND 1 
                   THEN 1 END) AS passed_records,
        COUNT(CASE WHEN quality_adjusted_engagement BETWEEN 0 AND 1 
                   THEN 1 END) * 100.0 / COUNT(*) AS pass_rate_pct,
        CASE 
            WHEN COUNT(CASE WHEN quality_adjusted_engagement BETWEEN 0 AND 1 
                           THEN 1 END) * 100.0 / COUNT(*) >= 95 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS status
    FROM {{ ref('fct_article_events') }}
    WHERE event_name = 'page_view'
),

combined AS (
    SELECT * FROM event_quality
    UNION ALL
    SELECT * FROM engagement_reasonableness
    UNION ALL
    SELECT * FROM scroll_reasonableness
    UNION ALL
    SELECT * FROM dimension_referential_integrity
    UNION ALL
    SELECT * FROM writer_referential_integrity
    UNION ALL
    SELECT * FROM engagement_rate_check
    UNION ALL
    SELECT * FROM quality_score_distribution
)

SELECT 
    *,
    CURRENT_TIMESTAMP() AS checked_at
FROM combined
ORDER BY 
    CASE status 
        WHEN 'FAIL' THEN 1 
        WHEN 'WARN' THEN 2 
        WHEN 'PASS' THEN 3 
    END,
    check_category,
    check_name