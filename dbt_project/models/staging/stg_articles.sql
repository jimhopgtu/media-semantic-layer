-- models/staging/stg_articles.sql
{{
  config(
    materialized='view',
    tags=['staging', 'articles']
  )
}}

WITH source AS (
    SELECT * FROM {{ source('raw', 'article_metadata') }}
),

max_date AS (
    SELECT MAX(publish_date) AS max_publish_date
    FROM source
),

transformed AS (
    SELECT
        -- Primary identifiers
        article_id,
        title,
        writer_id,
        
        -- Article attributes
        publish_date::DATE AS publish_date,
        category,
        word_count,
        is_premium,
        estimated_rpm,
        
        -- AI enrichment fields (will be populated later in Week 1, Day 4)
        sentiment_score_positive,
        sentiment_score_negative,
        sentiment_label,
        sentiment_enriched_at::TIMESTAMP AS sentiment_enriched_at,
        
        -- Calculated fields
        CASE 
            WHEN publish_date <= DATEADD('day', -30, (SELECT max_publish_date FROM max_date))
            THEN TRUE 
            ELSE FALSE 
        END AS is_evergreen,
        
        -- Metadata
        _loaded_at::TIMESTAMP AS loaded_at,
        _updated_at::TIMESTAMP AS updated_at
        
    FROM source
)

SELECT * FROM transformed