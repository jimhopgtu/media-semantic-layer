-- models/marts/dim_writers.sql
{{
  config(
    materialized='table',
    tags=['marts', 'dimensions']
  )
}}

SELECT
    writer_id,
    writer_name,
    primary_category,
    tenure_start_date,
    contract_type,
    target_articles_per_month,
    tenure_months

FROM {{ ref('stg_writers') }}
