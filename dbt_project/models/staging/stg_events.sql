with source as (
    select * from {{ source('raw', 'events_raw') }}
),

parsed as (
    select
        raw_json:event_date::date as event_date,
        raw_json:event_timestamp::timestamp as event_timestamp,
        raw_json:event_name::string as event_name,
        raw_json:user_pseudo_id::string as user_pseudo_id,
        raw_json:ga_session_id::string as ga_session_id,

        -- Extract from event_params array
        (
            select value:value::string
            from lateral flatten(input => raw_json:event_params)
            where value:key::string = 'article_id'
        ) as article_id,
        (
            select value:value::string
            from lateral flatten(input => raw_json:event_params)
            where value:key::string = 'writer_id'
        ) as writer_id,
        (
            select value:value::int
            from lateral flatten(input => raw_json:event_params)
            where value:key::string = 'engagement_time_msec'
        ) as engagement_time_msec,
        (
            select value:value::int
            from lateral flatten(input => raw_json:event_params)
            where value:key::string = 'percent_scrolled'
        ) as percent_scrolled,

        -- Device fields
        raw_json:device.category::string as device_category,
        raw_json:device.operating_system::string as device_os,
        raw_json:device.browser::string as device_browser,

        -- Geo fields
        raw_json:geo.country::string as geo_country,
        raw_json:geo.region::string as geo_region,
        raw_json:geo.city::string as geo_city,

        -- Traffic source fields
        raw_json:traffic_source.source::string as traffic_source,
        raw_json:traffic_source.medium::string as traffic_medium,
        raw_json:traffic_source.campaign::string as traffic_campaign

    from source
)

select * from parsed
