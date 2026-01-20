-- models/marts/core/dim_experiments.sql
{{
  config(
    materialized='table',
    tags=['marts', 'dimension', 'experiments']
  )
}}

/*
Experiment catalog containing all A/B tests run on the platform.
Each experiment tests different article variations (headlines, layouts, etc.)

This replaces the placeholder version from Day 1.
*/

WITH experiment_definitions AS (
    -- Define experiments manually for now
    -- In production, this would come from an experiments table or admin system
    
    SELECT 'exp_001' AS experiment_id, 'Headline Test: Question vs Statement' AS experiment_name,
           'sports' AS category, 'Do question headlines drive higher quality engagement than statements?' AS hypothesis,
           'statement_headline' AS control_variant, 'question_headline' AS treatment_variant,
           '2024-10-15'::DATE AS start_date, '2024-11-30'::DATE AS end_date,  -- Extended to 45 days
           'completed' AS status, 0.05 AS target_alpha, 0.80 AS target_power
    UNION ALL
    SELECT 'exp_002', 'Headline Length: Short vs Long',
           'finance', 'Shorter headlines (< 60 chars) improve engagement over longer ones',
           'long_headline', 'short_headline',
           '2024-10-01'::DATE, '2024-11-15'::DATE,  -- Extended to 45 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_003', 'Image Placement: Top vs Inline',
           'lifestyle', 'Hero images at top drive more engagement than inline images',
           'inline_image', 'top_image',
           '2024-10-01'::DATE, '2024-11-15'::DATE,  -- Extended to 45 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_004', 'Call-to-Action: Subtle vs Bold',
           'opinion', 'Bold CTAs increase engagement without sacrificing quality',
           'subtle_cta', 'bold_cta',
           '2024-11-01'::DATE, '2024-12-15'::DATE,  -- Extended to 45 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_005', 'Author Byline: Top vs Bottom',
           'news', 'Author byline at top increases trust and engagement',
           'bottom_byline', 'top_byline',
           '2024-11-01'::DATE, '2024-12-15'::DATE,  -- Extended to 45 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_006', 'Clickbait Test: Sensational vs Informative',
           'sports', 'Sensational headlines may increase clicks but decrease quality engagement',
           'informative_headline', 'sensational_headline',
           '2024-10-01'::DATE, '2024-10-31'::DATE,  -- Extended to 30 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_007', 'Word Count: Standard vs Extended',
           'finance', 'Extended analysis (1500+ words) drives higher quality engagement',
           'standard_length', 'extended_length',
           '2024-11-15'::DATE, '2025-01-07'::DATE,  -- Extended to cover more dates
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_008', 'Social Proof: View Count Display',
           'lifestyle', 'Showing view counts increases engagement through social proof',
           'no_view_count', 'show_view_count',
           '2024-10-20'::DATE, '2024-12-05'::DATE,  -- Extended to 45 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_009', 'Video Thumbnail: Static vs Animated',
           'news', 'Animated video thumbnails increase engagement',
           'static_thumbnail', 'animated_thumbnail',
           '2024-10-05'::DATE, '2024-11-20'::DATE,  -- Extended to 45 days
           'completed', 0.05, 0.80
    UNION ALL
    SELECT 'exp_010', 'Reading Time Display',
           'opinion', 'Showing estimated reading time improves user experience',
           'no_reading_time', 'show_reading_time',
           '2024-11-20'::DATE, '2025-01-07'::DATE,  -- Extended to cover more dates
           'completed', 0.05, 0.80
),

enriched AS (
    SELECT
        experiment_id,
        experiment_name,
        category,
        hypothesis,
        control_variant,
        treatment_variant,
        start_date,
        end_date,
        status,
        target_alpha,
        target_power,
        
        -- Calculated fields
        DATEDIFF('day', start_date, end_date) AS duration_days,
        
        -- Expected sample size (rough estimate: 1000 per variant minimum)
        2000 AS min_sample_size_per_variant,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS dim_updated_at
        
    FROM experiment_definitions
)

SELECT * FROM enriched