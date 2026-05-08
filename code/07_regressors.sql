CREATE OR REPLACE TABLE `iowa_liquor_pipeline.future_regressors_weekly` AS
WITH future_weeks AS (
  SELECT week_start
  FROM UNNEST(
    GENERATE_DATE_ARRAY('2025-01-06', '2025-03-31', INTERVAL 1 WEEK)
  ) AS week_start
),
series AS (
  SELECT DISTINCT store_number, category_name
  FROM `iowa_liquor_pipeline.model_input_weekly`
  WHERE store_number IN ('2633', '4829')
)
SELECT
  w.week_start,
  s.store_number,
  s.category_name,
  IF(w.week_start IN (
    '2025-01-20',  -- MLK Day week
    '2025-02-17',  -- Presidents Day week
    '2025-03-17'   -- St Patrick's Day week
  ), 1, 0) AS has_holiday,
  IF(EXTRACT(DAY FROM w.week_start) IN (1, 8, 15, 22), 1, 0) AS has_payday
FROM future_weeks w
CROSS JOIN series s;
