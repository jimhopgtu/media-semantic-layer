-- models/marts/experiments/fct_experiment_assignments.sql
{{
  config(
    materialized='table',
    tags=['marts', 'fact', 'experiments']
  )
}}

/*
Records which variant each user saw for each experiment.
This ensures proper randomization and prevents cross-contamination.

Grain: One row per user per experiment
*/

WITH experiments AS (
    SELECT * FROM {{ ref('dim_experiments') }}
),

articles AS (
    SELECT 
        article_id,
        category,
        publish_date
    FROM {{ ref('dim_articles') }}
),

users_in_experiment_window AS (
    -- Get all users who had events during each experiment window
    SELECT DISTINCT
        e.experiment_id,
        f.user_pseudo_id,
        f.article_id,
        MIN(f.event_timestamp) AS first_exposure_timestamp
    FROM {{ ref('fct_article_events') }} f
    INNER JOIN articles a ON f.article_id = a.article_id
    INNER JOIN experiments e ON a.category = e.category
        AND f.event_date BETWEEN e.start_date AND e.end_date
    GROUP BY e.experiment_id, f.user_pseudo_id, f.article_id
),

assignments AS (
    SELECT
        u.experiment_id,
        u.user_pseudo_id,
        u.article_id,
        u.first_exposure_timestamp,
        
        -- Assign variant using deterministic hash (50/50 split)
        CASE 
            WHEN MOD(ABS(HASH(u.user_pseudo_id || u.experiment_id)), 2) = 0 
            THEN e.control_variant
            ELSE e.treatment_variant
        END AS variant_assigned,
        
        -- Flag which group
        CASE 
            WHEN MOD(ABS(HASH(u.user_pseudo_id || u.experiment_id)), 2) = 0 
            THEN 'control'
            ELSE 'treatment'
        END AS variant_group,
        
        -- Experiment context
        e.experiment_name,
        e.category,
        e.start_date,
        e.end_date,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS assignment_created_at
        
    FROM users_in_experiment_window u
    INNER JOIN experiments e ON u.experiment_id = e.experiment_id
)

SELECT * FROM assignments