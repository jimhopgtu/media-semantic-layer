-- models/semantic/metricflow_time_spine.sql
-- Time spine for MetricFlow - one row per day

{{
  config(
    materialized='table',
    tags=['semantic', 'time_spine']
  )
}}

WITH date_spine AS (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('2024-10-01' as date)",
        end_date="cast('2025-12-31' as date)"
    )}}
)

SELECT
    date_day
FROM date_spine
