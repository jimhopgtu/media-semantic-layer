-- Test that engagement rate is between 0 and 1
{% test engagement_rate_bounds(model, column_name) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} < 0 
   OR {{ column_name }} > 1

{% endtest %}