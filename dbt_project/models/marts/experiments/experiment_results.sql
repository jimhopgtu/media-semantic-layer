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

-- Simulate variant effects based on experiment design
variant_effects AS (
    SELECT
        e.experiment_id,
        -- Simulated lift effects for different experiment types
        CASE e.experiment_id
            WHEN 'exp_001' THEN 0.08   -- Question headlines: +8% engagement, +6% quality
            WHEN 'exp_002' THEN 0.12   -- Short headlines: +12% engagement, +10% quality  
            WHEN 'exp_003' THEN 0.05   -- Top images: +5% engagement, +4% quality
            WHEN 'exp_004' THEN 0.15   -- Bold CTA: +15% engagement, +12% quality
            WHEN 'exp_005' THEN 0.03   -- Top byline: +3% engagement, +3% quality
            WHEN 'exp_006' THEN 0.25   -- CLICKBAIT: +25% engagement, -8% quality (THIS IS THE KEY ONE)
            WHEN 'exp_007' THEN -0.05  -- Extended length: -5% engagement, +10% quality (fewer clicks but higher quality)
            WHEN 'exp_008' THEN 0.10   -- View count: +10% engagement, +8% quality
            WHEN 'exp_009' THEN 0.07   -- Animated thumbnail: +7% engagement, +5% quality
            WHEN 'exp_010' THEN 0.04   -- Reading time: +4% engagement, +5% quality
        END AS engagement_lift_multiplier,
        CASE e.experiment_id
            WHEN 'exp_001' THEN 0.06
            WHEN 'exp_002' THEN 0.10
            WHEN 'exp_003' THEN 0.04
            WHEN 'exp_004' THEN 0.12
            WHEN 'exp_005' THEN 0.03
            WHEN 'exp_006' THEN -0.08  -- CLICKBAIT: Lower quality despite higher engagement
            WHEN 'exp_007' THEN 0.10   -- Extended: Higher quality despite lower engagement
            WHEN 'exp_008' THEN 0.08
            WHEN 'exp_009' THEN 0.05
            WHEN 'exp_010' THEN 0.05
        END AS quality_lift_multiplier
    FROM experiments e
),

variant_metrics AS (
    -- Calculate base metrics for each variant, then apply simulated effects
    SELECT
        a.experiment_id,
        a.variant_group,
        a.variant_assigned,
        ve.engagement_lift_multiplier,
        ve.quality_lift_multiplier,
        
        -- Sample sizes
        COUNT(DISTINCT a.user_pseudo_id) AS users_in_variant,
        
        -- Base metrics (same for both variants before applying effect)
        AVG(f.is_engaged) AS base_engagement_rate,
        AVG(f.quality_adjusted_engagement) AS base_quality_engagement,
        AVG(f.engagement_time_msec) / 1000.0 AS avg_engagement_seconds,
        AVG(f.percent_scrolled) AS avg_scroll_percent,
        SUM(f.estimated_revenue) / COUNT(DISTINCT a.user_pseudo_id) AS revenue_per_user,
        
        -- Apply variant effects ONLY to treatment group
        CASE 
            WHEN a.variant_group = 'treatment' 
            THEN AVG(f.is_engaged) * (1 + ve.engagement_lift_multiplier)
            ELSE AVG(f.is_engaged)
        END AS engagement_rate,
        
        CASE 
            WHEN a.variant_group = 'treatment' 
            THEN AVG(f.quality_adjusted_engagement) * (1 + ve.quality_lift_multiplier)
            ELSE AVG(f.quality_adjusted_engagement)
        END AS quality_engagement_rate,
        
        -- Variance (simplified for demo)
        0.15 AS engagement_stddev,
        0.10 AS quality_engagement_stddev
        
    FROM assignments a
    INNER JOIN {{ ref('fct_article_events') }} f 
        ON a.user_pseudo_id = f.user_pseudo_id 
        AND a.article_id = f.article_id
    INNER JOIN variant_effects ve ON a.experiment_id = ve.experiment_id
    WHERE f.event_name = 'page_view'
    GROUP BY 
        a.experiment_id, 
        a.variant_group, 
        a.variant_assigned,
        ve.engagement_lift_multiplier,
        ve.quality_lift_multiplier
),

control_metrics AS (
    SELECT * FROM variant_metrics WHERE variant_group = 'control'
),

treatment_metrics AS (
    SELECT * FROM variant_metrics WHERE variant_group = 'treatment'
),

results AS (
    SELECT
        e.experiment_id,
        e.experiment_name,
        e.category,
        e.hypothesis,
        e.start_date,
        e.end_date,
        e.duration_days,
        
        -- Control metrics
        c.variant_assigned AS control_variant,
        c.users_in_variant AS control_users,
        c.engagement_rate AS control_engagement_rate,
        c.quality_engagement_rate AS control_quality_engagement,
        c.avg_engagement_seconds AS control_avg_seconds,
        c.revenue_per_user AS control_revenue_per_user,
        
        -- Treatment metrics  
        t.variant_assigned AS treatment_variant,
        t.users_in_variant AS treatment_users,
        t.engagement_rate AS treatment_engagement_rate,
        t.quality_engagement_rate AS treatment_quality_engagement,
        t.avg_engagement_seconds AS treatment_avg_seconds,
        t.revenue_per_user AS treatment_revenue_per_user,
        
        -- Lift calculations (relative improvement)
        ((t.engagement_rate - c.engagement_rate) / NULLIF(c.engagement_rate, 0)) * 100 
            AS engagement_lift_pct,
        ((t.quality_engagement_rate - c.quality_engagement_rate) / NULLIF(c.quality_engagement_rate, 0)) * 100 
            AS quality_engagement_lift_pct,
        ((t.revenue_per_user - c.revenue_per_user) / NULLIF(c.revenue_per_user, 0)) * 100 
            AS revenue_lift_pct,
        
        -- Absolute differences
        t.engagement_rate - c.engagement_rate AS engagement_diff,
        t.quality_engagement_rate - c.quality_engagement_rate AS quality_engagement_diff,
        
        -- Statistical significance (z-test approximation)
        CASE
            WHEN c.users_in_variant < 100 OR t.users_in_variant < 100 THEN 'insufficient_sample'
            WHEN ABS(t.quality_engagement_rate - c.quality_engagement_rate) / 
                 SQRT((POWER(c.quality_engagement_stddev, 2) / c.users_in_variant) + 
                      (POWER(t.quality_engagement_stddev, 2) / t.users_in_variant)) > 1.96 
            THEN 'significant'
            ELSE 'not_significant'
        END AS statistical_significance,
        
        -- Determine winner based on quality-adjusted engagement
        CASE
            WHEN c.users_in_variant < 100 OR t.users_in_variant < 100 THEN 'inconclusive'
            WHEN ABS(t.quality_engagement_rate - c.quality_engagement_rate) / 
                 SQRT((POWER(c.quality_engagement_stddev, 2) / c.users_in_variant) + 
                      (POWER(t.quality_engagement_stddev, 2) / t.users_in_variant)) <= 1.96 
            THEN 'no_winner'
            WHEN t.quality_engagement_rate > c.quality_engagement_rate 
            THEN 'treatment_wins'
            ELSE 'control_wins'
        END AS winner,
        
        -- Clickbait detection: High engagement but low quality
        CASE
            WHEN t.engagement_rate > c.engagement_rate * 1.1  -- 10%+ higher engagement
                 AND t.quality_engagement_rate < c.quality_engagement_rate * 0.95  -- 5%+ lower quality
            THEN TRUE
            ELSE FALSE
        END AS is_clickbait_variant,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS results_calculated_at
        
    FROM experiments e
    INNER JOIN control_metrics c ON e.experiment_id = c.experiment_id
    INNER JOIN treatment_metrics t ON e.experiment_id = t.experiment_id
)

SELECT * FROM results