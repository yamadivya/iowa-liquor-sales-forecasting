CREATE OR REPLACE MODEL `iowa_liquor_pipeline.arima_iowa_model`
OPTIONS (
  model_type                = 'ARIMA_PLUS_XREG',
  time_series_timestamp_col = 'week_start',
  time_series_data_col      = 'weekly_sales',
  time_series_id_col        = ['store_number', 'category_name'],
  data_frequency            = 'WEEKLY',
  horizon                   = 12,
  auto_arima                = TRUE,
  holiday_region            = 'US'
) AS
SELECT
  week_start,
  store_number,
  category_name,
  weekly_sales,
  has_holiday,
  has_payday
FROM `iowa_liquor_pipeline.model_input_weekly`
WHERE
  store_number IN ('2633', '4829')
  AND week_start BETWEEN '2017-01-01' AND '2024-09-30';
