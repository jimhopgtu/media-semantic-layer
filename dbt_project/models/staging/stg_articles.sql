with source as (
    select * from {{ source('raw', 'article_metadata') }}
),

max_date as (
    select max(publish_date) as max_publish_date
    from source
),

transformed as (
    select
        article_id,
        title,
        slug,
        writer_id,
        category,
        subcategory,
        tags,
        publish_date::date as publish_date,
        last_updated::timestamp as last_updated_at,
        word_count,
        read_time_minutes,
        is_premium,
        status,

        -- AI enrichment fields (will be populated later)
        sentiment_score_positive,
        sentiment_score_negative,
        sentiment_label,
        sentiment_enriched_at,

        -- Calculated field: articles older than 30 days are considered evergreen
        case
            when publish_date <= dateadd(day, -30, (select max_publish_date from max_date))
            then true
            else false
        end as is_evergreen

    from source
)

select * from transformed
