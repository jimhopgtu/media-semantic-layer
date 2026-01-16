-- models/marts/core/dim_writers.sql
{{
  config(
    materialized='table',
    tags=['marts', 'dimension', 'writers']
  )
}}

WITH writers AS (
    SELECT * FROM {{ ref('stg_writers') }}
),

enriched AS (
    SELECT
        -- Primary key
        writer_id,
        
        -- Writer attributes
        writer_name,
        primary_category,
        tenure_start_date,
        contract_type,
        target_articles_per_month,
        tenure_months,
        
        -- Derived classifications
        CASE
            WHEN tenure_months < 6 THEN 'new'
            WHEN tenure_months < 24 THEN 'established'
            ELSE 'veteran'
        END AS experience_level,
        
        CASE
            WHEN contract_type = 'staff' THEN 'full_time'
            WHEN contract_type IN ('freelance', 'contractor') THEN 'flexible'
            ELSE 'other'
        END AS employment_category,
        
        -- Activity targets
        CASE
            WHEN target_articles_per_month >= 20 THEN 'high_volume'
            WHEN target_articles_per_month >= 10 THEN 'medium_volume'
            ELSE 'low_volume'
        END AS productivity_tier,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS dim_updated_at
        
    FROM writers
)

SELECT * FROM enriched