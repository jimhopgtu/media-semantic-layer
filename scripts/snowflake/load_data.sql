-- Snowflake Data Loading Script
-- Load synthetic data from local files into Snowflake tables

USE DATABASE media_analytics;
USE SCHEMA raw;

-- ============================================================================
-- OPTION 1: Load via Snowflake UI (Web Interface)
-- ============================================================================

/*
1. Go to Snowflake UI → Databases → media_analytics → raw schema
2. For each table, click "Load Data" button
3. Upload corresponding CSV/JSON file:
   - writers.csv → writer_metadata
   - articles.csv → article_metadata  
   - events.jsonl → events_raw
4. Follow wizard to map columns and load
*/

-- ============================================================================
-- OPTION 2: Load via SnowSQL CLI (Recommended for reproducibility)
-- ============================================================================

-- Step 1: Create stage for file uploads
CREATE OR REPLACE STAGE media_analytics_stage;

-- Step 2: Upload files from local machine
-- Run these commands in your terminal (not in Snowflake):
/*
snowsql -a <your_account> -u <your_user>

-- Upload files
PUT file://./data/writers.csv @media_analytics_stage AUTO_COMPRESS=TRUE;
PUT file://./data/articles.csv @media_analytics_stage AUTO_COMPRESS=TRUE;
PUT file://./data/events.jsonl @media_analytics_stage AUTO_COMPRESS=TRUE;

-- Verify files are uploaded
LIST @media_analytics_stage;
*/

-- Step 3: Load writer_metadata
COPY INTO writer_metadata (
    writer_id,
    writer_name,
    primary_category,
    tenure_start_date,
    contract_type,
    target_articles_per_month
)
FROM @media_analytics_stage/writers.csv.gz
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    DATE_FORMAT = 'YYYY-MM-DD'
    ENCODING = 'UTF8'
)
ON_ERROR = 'ABORT_STATEMENT';

-- Validate writer load
SELECT COUNT(*) as writers_loaded FROM writer_metadata;
-- Expected: 75 rows

-- Step 4: Load article_metadata
COPY INTO article_metadata (
    article_id,
    title,
    writer_id,
    publish_date,
    category,
    word_count,
    is_premium,
    estimated_rpm
    -- Note: sentiment fields remain NULL until enrichment
)
FROM @media_analytics_stage/articles.csv.gz
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    DATE_FORMAT = 'YYYY-MM-DD'
    ENCODING = 'UTF8'
)
ON_ERROR = 'ABORT_STATEMENT';

-- Validate article load
SELECT COUNT(*) as articles_loaded FROM article_metadata;
-- Expected: 5000 rows

SELECT 
    category,
    COUNT(*) as article_count,
    MIN(publish_date) as earliest_publish,
    MAX(publish_date) as latest_publish
FROM article_metadata
GROUP BY category
ORDER BY article_count DESC;

-- Step 5: Load events_raw (JSONL format)
COPY INTO events_raw
FROM @media_analytics_stage/events.jsonl.gz
FILE_FORMAT = (
    TYPE = 'JSON'
    COMPRESSION = 'AUTO'
)
ON_ERROR = 'ABORT_STATEMENT';

-- Validate event load
SELECT COUNT(*) as events_loaded FROM events_raw;
-- Expected: 500,000+ rows

SELECT 
    event_name,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_pseudo_id) as unique_users,
    COUNT(DISTINCT ga_session_id) as unique_sessions
FROM events_raw
GROUP BY event_name
ORDER BY event_count DESC;

-- ============================================================================
-- OPTION 3: Load via Python (for automation/Airflow)
-- ============================================================================

-- See scripts/load_to_snowflake.py for Python implementation

-- ============================================================================
-- POST-LOAD VALIDATION
-- ============================================================================

-- Check data quality against contracts

-- Contract 1: Events completeness
SELECT 
    COUNT(*) as total_events,
    COUNT(event_date) as events_with_date,
    COUNT(event_timestamp) as events_with_timestamp,
    COUNT(event_name) as events_with_name,
    COUNT(user_pseudo_id) as events_with_user,
    COUNT(*) - COUNT(user_pseudo_id) as missing_users,
    ROUND(100.0 * COUNT(user_pseudo_id) / COUNT(*), 2) as completeness_pct
FROM events_raw;
-- Expected: >95% completeness

-- Contract 2: Article business logic
SELECT 
    'Articles where is_premium=TRUE but RPM<8' as validation_check,
    COUNT(*) as violations
FROM article_metadata
WHERE is_premium = TRUE AND estimated_rpm < 8.0;
-- Expected: 0 violations

-- Contract 3: Writer business logic
SELECT 
    'Staff writers with target<15' as validation_check,
    COUNT(*) as violations
FROM writer_metadata
WHERE contract_type = 'staff' AND target_articles_per_month < 15;
-- Expected: 0 violations

-- Referential integrity: articles reference valid writers
SELECT 
    COUNT(DISTINCT a.writer_id) as writers_in_articles,
    COUNT(DISTINCT w.writer_id) as writers_total,
    COUNT(DISTINCT CASE WHEN w.writer_id IS NULL THEN a.writer_id END) as orphaned_articles
FROM article_metadata a
LEFT JOIN writer_metadata w ON a.writer_id = w.writer_id;
-- Expected: orphaned_articles = 0

-- Event params structure validation
SELECT 
    event_name,
    COUNT(*) as total,
    COUNT(CASE WHEN event_params IS NOT NULL THEN 1 END) as with_params,
    COUNT(CASE WHEN event_params[0]:key::STRING = 'article_id' THEN 1 END) as with_article_id
FROM events_raw
GROUP BY event_name;

-- Check date ranges
SELECT 
    'events' as table_name,
    MIN(event_date) as min_date,
    MAX(event_date) as max_date,
    DATEDIFF(day, TO_DATE(MIN(event_date), 'YYYYMMDD'), TO_DATE(MAX(event_date), 'YYYYMMDD')) as date_range_days
FROM events_raw
UNION ALL
SELECT 
    'articles' as table_name,
    MIN(publish_date)::STRING as min_date,
    MAX(publish_date)::STRING as max_date,
    DATEDIFF(day, MIN(publish_date), MAX(publish_date)) as date_range_days
FROM article_metadata;
-- Expected: ~90-98 days for both

-- ============================================================================
-- SAMPLE QUERIES (to test data is usable)
-- ============================================================================

-- Query 1: Top articles by pageviews
SELECT 
    a.article_id,
    a.title,
    a.category,
    w.writer_name,
    COUNT(*) as pageviews,
    COUNT(DISTINCT e.user_pseudo_id) as unique_users
FROM events_raw e
JOIN article_metadata a ON e.event_params[0]:value:string_value::STRING = a.article_id
JOIN writer_metadata w ON a.writer_id = w.writer_id
WHERE e.event_name = 'page_view'
GROUP BY 1, 2, 3, 4
ORDER BY pageviews DESC
LIMIT 10;

-- Query 2: Writer performance summary
WITH writer_stats AS (
    SELECT 
        a.writer_id,
        COUNT(DISTINCT a.article_id) as articles_published,
        COUNT(CASE WHEN e.event_name = 'page_view' THEN 1 END) as total_pageviews,
        SUM(a.estimated_rpm * COUNT(CASE WHEN e.event_name = 'page_view' THEN 1 END)) / 1000.0 as est_revenue
    FROM article_metadata a
    LEFT JOIN events_raw e ON e.event_params[0]:value:string_value::STRING = a.article_id
    GROUP BY a.writer_id
)
SELECT 
    w.writer_name,
    w.contract_type,
    ws.articles_published,
    ws.total_pageviews,
    ws.est_revenue,
    ws.est_revenue / NULLIF(ws.articles_published, 0) as revenue_per_article
FROM writer_stats ws
JOIN writer_metadata w ON ws.writer_id = w.writer_id
ORDER BY ws.est_revenue DESC
LIMIT 10;

-- Query 3: Daily traffic trends
SELECT 
    event_date,
    COUNT(*) as total_events,
    COUNT(CASE WHEN event_name = 'page_view' THEN 1 END) as pageviews,
    COUNT(DISTINCT user_pseudo_id) as unique_users,
    COUNT(DISTINCT ga_session_id) as unique_sessions
FROM events_raw
GROUP BY event_date
ORDER BY event_date;

SELECT 'Data loading complete! ✓' as status;
SELECT 'Ready for dbt transformations' as next_step;
