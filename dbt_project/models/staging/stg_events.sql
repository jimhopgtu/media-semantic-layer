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
        raw_json:event_date::STRING AS event_date,
        TO_TIMESTAMP(raw_json:event_timestamp::NUMBER / 1000000) AS event_timestamp,
        raw_json:event_name::STRING AS event_name,
        raw_json:user_pseudo_id::STRING AS user_pseudo_id,
        raw_json:ga_session_id::STRING AS ga_session_id,
        
        -- Article/Writer context - parse event_params array
        raw_json:event_params[0]:value:string_value::STRING AS article_id,
        raw_json:event_params[1]:value:string_value::STRING AS writer_id,
        
        -- Engagement metrics - check multiple array positions
        COALESCE(
            raw_json:event_params[2]:value:int_value::NUMBER,
            raw_json:event_params[3]:value:int_value::NUMBER,
            raw_json:event_params[4]:value:int_value::NUMBER
        ) AS engagement_time_msec,
        
        COALESCE(
            raw_json:event_params[2]:value:int_value::NUMBER,
            raw_json:event_params[3]:value:int_value::NUMBER,
            raw_json:event_params[4]:value:int_value::NUMBER
        ) AS percent_scrolled,
        
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
        
        -- Removed: _loaded_at (doesn't exist in events_raw)
        
    FROM source
)

SELECT * FROM parsed