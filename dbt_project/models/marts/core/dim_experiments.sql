-- models/marts/core/dim_experiments.sql
-- PLACEHOLDER: Will be implemented in Week 2 when we add experimentation data
{{
  config(
    materialized='table',
    tags=['marts', 'dimension', 'experiments', 'placeholder']
  )
}}

-- For now, create an empty structure so downstream models can reference it
SELECT
    'placeholder' AS experiment_id,
    'Placeholder Experiment' AS experiment_name,
    'Not yet implemented' AS experiment_description,
    NULL::VARCHAR AS control_variant,
    NULL::VARCHAR AS test_variant,
    NULL::DATE AS start_date,
    NULL::DATE AS end_date,
    NULL::VARCHAR AS hypothesis,
    NULL::VARCHAR AS status
WHERE 1=0  -- Returns no rows