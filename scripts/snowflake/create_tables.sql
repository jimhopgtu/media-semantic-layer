-- Snowflake Setup Script: Create Tables
-- Run this after creating your database and schema

-- Create database and schema
CREATE DATABASE IF NOT EXISTS media_analytics;
USE DATABASE media_analytics;

CREATE SCHEMA IF NOT EXISTS raw;
USE SCHEMA raw;

-- ============================================================================
-- TABLE 1: events_raw (GA4-style event stream)
-- ============================================================================

CREATE OR REPLACE TABLE events_raw (
    event_date STRING,
    event_timestamp NUMBER(38,0),
    event_name STRING,
    user_pseudo_id STRING,
    ga_session_id STRING,
    event_params VARIANT,  -- JSON array of key-value pairs
    device OBJECT(
        category STRING,
        operating_system STRING,
        browser STRING
    ),
    geo OBJECT(
        country STRING,
        region STRING,
        city STRING
    ),
    traffic_source OBJECT(
        source STRING,
        medium STRING,
        campaign STRING
    ),
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'GA4-style event stream from synthetic data generator. Contract 1.';

-- ============================================================================
-- TABLE 2: article_metadata
-- ============================================================================

CREATE OR REPLACE TABLE article_metadata (
    article_id STRING PRIMARY KEY,
    title STRING NOT NULL,
    writer_id STRING NOT NULL,
    publish_date DATE NOT NULL,
    category STRING NOT NULL,
    word_count NUMBER(38,0) NOT NULL,
    is_premium BOOLEAN NOT NULL,
    estimated_rpm NUMBER(10,2) NOT NULL,
    
    -- AI enrichment fields (populated later)
    sentiment_score_positive NUMBER(5,4),
    sentiment_score_negative NUMBER(5,4),
    sentiment_label STRING,
    sentiment_enriched_at TIMESTAMP_NTZ,
    
    -- Metadata
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Constraints
    CONSTRAINT chk_category CHECK (category IN ('sports', 'finance', 'lifestyle', 'news', 'opinion')),
    CONSTRAINT chk_word_count CHECK (word_count BETWEEN 300 AND 3000),
    CONSTRAINT chk_rpm CHECK (estimated_rpm BETWEEN 1.50 AND 15.00),
    CONSTRAINT chk_sentiment_label CHECK (sentiment_label IS NULL OR sentiment_label IN ('POSITIVE', 'NEGATIVE', 'NEUTRAL')),
    CONSTRAINT chk_premium_rpm CHECK (NOT is_premium OR estimated_rpm >= 8.0)
)
COMMENT = 'Article catalog with AI sentiment enrichment. Contract 2.';

-- ============================================================================
-- TABLE 3: writer_metadata
-- ============================================================================

CREATE OR REPLACE TABLE writer_metadata (
    writer_id STRING PRIMARY KEY,
    writer_name STRING NOT NULL,
    primary_category STRING NOT NULL,
    tenure_start_date DATE NOT NULL,
    contract_type STRING NOT NULL,
    target_articles_per_month NUMBER(38,0) NOT NULL,
    
    -- Metadata
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Constraints
    CONSTRAINT chk_writer_category CHECK (primary_category IN ('sports', 'finance', 'lifestyle', 'news', 'opinion')),
    CONSTRAINT chk_contract_type CHECK (contract_type IN ('staff', 'freelance', 'contractor')),
    CONSTRAINT chk_tenure CHECK (tenure_start_date BETWEEN '2020-01-01' AND '2025-01-01'),
    CONSTRAINT chk_target CHECK (target_articles_per_month BETWEEN 5 AND 50),
    CONSTRAINT chk_staff_target CHECK (contract_type != 'staff' OR target_articles_per_month >= 15)
)
COMMENT = 'Writer profiles and editorial organization. Contract 3.';

-- ============================================================================
-- CREATE FOREIGN KEY RELATIONSHIPS (for documentation, not enforced in Snowflake)
-- ============================================================================

-- Note: Snowflake doesn't enforce foreign keys, but we can define them for metadata

ALTER TABLE article_metadata 
    ADD CONSTRAINT fk_article_writer 
    FOREIGN KEY (writer_id) REFERENCES writer_metadata(writer_id)
    NOT ENFORCED;

-- ============================================================================
-- CREATE INDEXES FOR QUERY PERFORMANCE
-- ============================================================================

-- Cluster keys for large tables
ALTER TABLE events_raw CLUSTER BY (event_date, event_name);
ALTER TABLE article_metadata CLUSTER BY (publish_date, category);

-- ============================================================================
-- GRANT PERMISSIONS (adjust based on your role setup)
-- ============================================================================

-- Grant to dbt service account (replace with your actual role)
GRANT USAGE ON DATABASE media_analytics TO ROLE dbt_role;
GRANT USAGE ON SCHEMA media_analytics.raw TO ROLE dbt_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA media_analytics.raw TO ROLE dbt_role;

-- Grant future privileges
GRANT SELECT, INSERT, UPDATE ON FUTURE TABLES IN SCHEMA media_analytics.raw TO ROLE dbt_role;

-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Run these after loading data to validate schema

-- Check events_raw structure
SELECT 
    event_name,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_pseudo_id) as unique_users,
    MIN(event_date) as first_event_date,
    MAX(event_date) as last_event_date
FROM events_raw
GROUP BY event_name
ORDER BY event_count DESC;

-- Check article_metadata
SELECT 
    category,
    is_premium,
    COUNT(*) as article_count,
    AVG(word_count) as avg_word_count,
    AVG(estimated_rpm) as avg_rpm
FROM article_metadata
GROUP BY category, is_premium
ORDER BY category, is_premium;

-- Check writer_metadata
SELECT 
    contract_type,
    COUNT(*) as writer_count,
    AVG(target_articles_per_month) as avg_monthly_target
FROM writer_metadata
GROUP BY contract_type
ORDER BY writer_count DESC;

-- Check referential integrity
SELECT 
    COUNT(DISTINCT a.writer_id) as writers_in_articles,
    COUNT(DISTINCT w.writer_id) as writers_in_metadata,
    COUNT(DISTINCT a.writer_id) - COUNT(DISTINCT w.writer_id) as orphaned_writers
FROM article_metadata a
LEFT JOIN writer_metadata w ON a.writer_id = w.writer_id;

SELECT 'Setup complete! ✓' as status;
