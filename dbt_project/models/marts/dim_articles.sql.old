-- models/marts/dim_articles.sql
{{
  config(
    materialized='table',
    tags=['marts', 'dimensions']
  )
}}

SELECT
    article_id,
    title,
    writer_id,
    publish_date,
    category,
    word_count,
    is_premium,
    estimated_rpm,
    sentiment_score_positive,
    sentiment_score_negative,
    sentiment_label,
    sentiment_enriched_at,
    is_evergreen,
    loaded_at,
    updated_at

FROM {{ ref('stg_articles') }}
