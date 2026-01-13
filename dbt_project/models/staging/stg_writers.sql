with source as (
    select * from {{ source('raw', 'writer_metadata') }}
),

transformed as (
    select
        writer_id,
        writer_name,
        primary_category,
        tenure_start_date::date as tenure_start_date,
        contract_type,
        target_articles_per_month,

        -- Calculated field: months since tenure start
        datediff(month, tenure_start_date::date, current_date()) as tenure_months

    from source
)

select * from transformed
