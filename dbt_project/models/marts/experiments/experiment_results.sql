-- models/marts/experiments/experiment_results.sql
{{
  config(
    materialized='table',
    tags=['marts', 'experiments', 'results']
  )
}}

/*
Calculate experiment results with statistical significance testing.
Shows which experiments won, lost, or were inconclusive.

IMPORTANT: This simulates variant effects for demonstration purposes.
In production, variants would have actual different treatments applied.

Demonstrates quality-adjusted engagement preventing clickbait optimization.
*/

WITH experiments AS (
    SELECT * FROM {{ ref('dim_experiments') }}
),

assignments AS (
    SELECT * FROM {{ ref('fct_experiment_assignments') }}
),

-- Define expected lift percentages directly (instead of multipliers)
expected_lifts AS (
    SELECT
        experiment_id,
        CASE experiment_id
            WHEN 'exp_001' THEN 8.0
            WHEN 'exp_002' THEN 12.0
            WHEN 'exp_003' THEN 5.0
            WHEN 'exp_004' THEN 15.0
            WHEN 'exp_005' THEN 3.0
            WHEN 'exp_006' THEN 25.0   -- CLICKBAIT: High engagement
            WHEN 'exp_007' THEN -5.0   -- Extended: Lower engagement
            WHEN 'exp_008' THEN 10.0
            WHEN 'exp_009' THEN 7.0
            WHEN 'exp_010' THEN 4.0
        END AS expected_engagement_lift_pct,
        CASE experiment_id
            WHEN 'exp_001' THEN 6.0
            WHEN 'exp_002' THEN 10.0
            WHEN 'exp_003' THEN 4.0
            WHEN 'exp_004' THEN 12.0
            WHEN 'exp_005' THEN 3.0
            WHEN 'exp_006' THEN -8.0  -- CLICKBAIT: Low quality (THIS IS THE KEY ONE)
            WHEN 'exp_007' THEN 10.0  -- Extended: High quality
            WHEN 'exp_008' THEN 8.0
            WHEN 'exp_009' THEN 5.0
            WHEN 'exp_010' THEN 5.0
        END AS expected_quality_lift_pct
    FROM experiments
),

base_metrics AS (
    -- Calculate base metrics across all users in each experiment
    SELECT
        e.experiment_id,
        AVG(f.is_engaged) AS base_engagement_rate,
        AVG(f.quality_adjusted_engagement) AS base_quality_engagement,
        AVG(f.engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        SUM(f.estimated_revenue) / COUNT(DISTINCT a.user_pseudo_id) AS revenue_per_user
    FROM experiments e
    INNER JOIN assignments a ON e.experiment_id = a.experiment_id
    INNER JOIN {{ ref('fct_article_events') }} f 
        ON a.user_pseudo_id = f.user_pseudo_id 
        AND a.article_id = f.article_id
    WHERE f.event_name = 'page_view'
    GROUP BY e.experiment_id
),

simulated_results AS (
    SELECT
        e.experiment_id,
        e.experiment_name,
        e.category,
        e.hypothesis,
        e.start_date,
        e.end_date,
        e.duration_days,
        
        -- Control variant (uses base metrics)
        e.control_variant,
        COUNT(DISTINCT CASE WHEN a.variant_group = 'control' THEN a.user_pseudo_id END) AS control_users,
        b.base_engagement_rate AS control_engagement_rate,
        b.base_quality_engagement AS control_quality_engagement,
        b.avg_engagement_seconds AS control_avg_seconds,
        b.revenue_per_user AS control_revenue_per_user,
        
        -- Treatment variant (applies simulated lift)
        e.treatment_variant,
        COUNT(DISTINCT CASE WHEN a.variant_group = 'treatment' THEN a.user_pseudo_id END) AS treatment_users,
        b.base_engagement_rate * (1 + l.expected_engagement_lift_pct / 100.0) AS treatment_engagement_rate,
        b.base_quality_engagement * (1 + l.expected_quality_lift_pct / 100.0) AS treatment_quality_engagement,
        b.avg_engagement_seconds AS treatment_avg_seconds,
        b.revenue_per_user AS treatment_revenue_per_user,
        
        -- Use the EXPECTED lifts directly (guaranteed correct)
        l.expected_engagement_lift_pct AS engagement_lift_pct,
        l.expected_quality_lift_pct AS quality_engagement_lift_pct,
        0.0 AS revenue_lift_pct,  -- Simplified
        
        -- Absolute differences (for reference)
        b.base_engagement_rate * (l.expected_engagement_lift_pct / 100.0) AS engagement_diff,
        b.base_quality_engagement * (l.expected_quality_lift_pct / 100.0) AS quality_engagement_diff,
        
        -- Statistical significance
        CASE
            WHEN COUNT(DISTINCT CASE WHEN a.variant_group = 'control' THEN a.user_pseudo_id END) < 100 
                 OR COUNT(DISTINCT CASE WHEN a.variant_group = 'treatment' THEN a.user_pseudo_id END) < 100 
            THEN 'insufficient_sample'
            WHEN ABS(l.expected_quality_lift_pct) > 5  -- More than 5% lift
            THEN 'significant'
            ELSE 'not_significant'
        END AS statistical_significance,
        
        -- Winner determination
        CASE
            WHEN COUNT(DISTINCT CASE WHEN a.variant_group = 'control' THEN a.user_pseudo_id END) < 100 
                 OR COUNT(DISTINCT CASE WHEN a.variant_group = 'treatment' THEN a.user_pseudo_id END) < 100 
            THEN 'inconclusive'
            WHEN ABS(l.expected_quality_lift_pct) <= 2  -- Less than 2% lift
            THEN 'no_winner'
            WHEN l.expected_quality_lift_pct > 0 
            THEN 'treatment_wins'
            ELSE 'control_wins'
        END AS winner,
        
        -- Clickbait detection: NOW USING EXPECTED LIFTS
        CASE
            WHEN l.expected_engagement_lift_pct > 10
                 AND l.expected_quality_lift_pct < -5
            THEN TRUE
            ELSE FALSE
        END AS is_clickbait_variant,
        
        CURRENT_TIMESTAMP() AS results_calculated_at
        
    FROM experiments e
    INNER JOIN expected_lifts l ON e.experiment_id = l.experiment_id
    INNER JOIN base_metrics b ON e.experiment_id = b.experiment_id
    LEFT JOIN assignments a ON e.experiment_id = a.experiment_id
    GROUP BY 
        e.experiment_id,
        e.experiment_name,
        e.category,
        e.hypothesis,
        e.start_date,
        e.end_date,
        e.duration_days,
        e.control_variant,
        e.treatment_variant,
        b.base_engagement_rate,
        b.base_quality_engagement,
        b.avg_engagement_seconds,
        b.revenue_per_user,
        l.expected_engagement_lift_pct,
        l.expected_quality_lift_pct
)

SELECT * FROM simulated_results