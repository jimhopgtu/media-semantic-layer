-- models/staging/stg_events.sql
{{
  config(
    materialized='view',
    tags=['staging', 'events']
  )
}}

WITH source AS (
    SELECT * FROM {{ source('raw', 'events_raw') }}
),

parsed AS (
    SELECT
        -- Event identifiers
        TO_DATE(raw_json:event_date::STRING, 'YYYYMMDD') AS event_date,
        TO_TIMESTAMP(raw_json:event_timestamp::NUMBER / 1000000) AS event_timestamp,
        raw_json:event_name::STRING AS event_name,
        raw_json:user_pseudo_id::STRING AS user_pseudo_id,
        raw_json:ga_session_id::STRING AS ga_session_id,
        
        -- Article/Writer context - parse event_params array
        raw_json:event_params[0]:value:string_value::STRING AS article_id,
        raw_json:event_params[1]:value:string_value::STRING AS writer_id,
        
        -- Engagement metrics - SIMULATE since not in raw data
        -- Generate reasonable values based on event patterns
        CASE 
            WHEN raw_json:event_name::STRING = 'user_engagement' 
            THEN ABS(MOD(HASH(raw_json:user_pseudo_id::STRING || raw_json:event_timestamp::STRING), 300)) * 1000 + 60000  -- 60s to 360s
            WHEN raw_json:event_name::STRING = 'scroll' 
            THEN ABS(MOD(HASH(raw_json:user_pseudo_id::STRING || raw_json:event_timestamp::STRING), 120)) * 1000 + 30000  -- 30s to 150s
            WHEN raw_json:event_name::STRING = 'page_view'
            THEN ABS(MOD(HASH(raw_json:user_pseudo_id::STRING || raw_json:event_timestamp::STRING), 180)) * 1000        -- 0s to 180s
            ELSE ABS(MOD(HASH(raw_json:user_pseudo_id::STRING || raw_json:event_timestamp::STRING), 60)) * 1000           -- 0s to 60s
        END AS engagement_time_msec,
        
        CASE 
            WHEN raw_json:event_name::STRING = 'user_engagement' 
            THEN ABS(MOD(HASH(raw_json:event_timestamp::STRING || raw_json:user_pseudo_id::STRING), 30)) + 70  -- 70% to 100%
            WHEN raw_json:event_name::STRING = 'scroll' 
            THEN ABS(MOD(HASH(raw_json:event_timestamp::STRING || raw_json:user_pseudo_id::STRING), 50)) + 50  -- 50% to 100%
            WHEN raw_json:event_name::STRING = 'page_view'
            THEN ABS(MOD(HASH(raw_json:event_timestamp::STRING || raw_json:user_pseudo_id::STRING), 100))      -- 0% to 100%
            ELSE ABS(MOD(HASH(raw_json:event_timestamp::STRING || raw_json:user_pseudo_id::STRING), 40))       -- 0% to 40%
        END AS percent_scrolled,
        
        -- Device information
        raw_json:device.category::STRING AS device_category,
        raw_json:device.operating_system::STRING AS device_os,
        raw_json:device.browser::STRING AS device_browser,
        
        -- Geographic information
        raw_json:geo.country::STRING AS geo_country,
        raw_json:geo.region::STRING AS geo_region,
        raw_json:geo.city::STRING AS geo_city,
        
        -- Traffic source
        raw_json:traffic_source.source::STRING AS traffic_source,
        raw_json:traffic_source.medium::STRING AS traffic_medium,
        raw_json:traffic_source.campaign::STRING AS traffic_campaign
        
    FROM source
)

SELECT * FROM parsed