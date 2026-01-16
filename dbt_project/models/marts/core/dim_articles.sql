-- models/marts/core/dim_articles.sql
{{
  config(
    materialized='table',
    tags=['marts', 'dimension', 'articles']
  )
}}

WITH articles AS (
    SELECT * FROM {{ ref('stg_articles') }}
),

-- Enrich with derived attributes
enriched AS (
    SELECT
        -- Primary key
        article_id,
        
        -- Article attributes
        title,
        writer_id,
        publish_date,
        category,
        word_count,
        is_premium,
        estimated_rpm,
        
        -- Content classification
        CASE 
            WHEN word_count < 500 THEN 'short'
            WHEN word_count < 1000 THEN 'medium'
            WHEN word_count < 2000 THEN 'long'
            ELSE 'very_long'
        END AS content_length_bucket,
        
        CASE
            WHEN estimated_rpm >= 8.0 THEN 'high'
            WHEN estimated_rpm >= 5.0 THEN 'medium'
            ELSE 'low'
        END AS rpm_tier,
        
        is_evergreen,
        
        -- AI sentiment (will be populated in Week 1, Day 4)
        sentiment_score_positive,
        sentiment_score_negative,
        sentiment_label,
        sentiment_enriched_at,
        
        -- Quality score (composite metric)
        CASE 
            WHEN sentiment_label = 'POSITIVE' THEN sentiment_score_positive
            WHEN sentiment_label = 'NEGATIVE' THEN 1 - sentiment_score_negative
            ELSE 0.5  -- neutral default
        END AS quality_score,
        
        -- Metadata
        loaded_at,
        updated_at,
        CURRENT_TIMESTAMP() AS dim_updated_at
        
    FROM articles
)

SELECT * FROM enriched