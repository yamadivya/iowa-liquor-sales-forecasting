CREATE OR REPLACE TABLE `iowa_liquor_pipeline.sales_forecast` AS
SELECT
  DATE(f.forecast_timestamp)                AS forecast_date,
  f.store_number,
  f.category_name,
  ROUND(f.forecast_value, 2)                AS predicted_sales,
  ROUND(f.prediction_interval_lower_bound, 2) AS lower_90,
  ROUND(f.prediction_interval_upper_bound, 2) AS upper_90,
  CURRENT_TIMESTAMP()                        AS generated_at
FROM ML.FORECAST(
  MODEL `iowa_liquor_pipeline.arima_iowa_model`,
  STRUCT(12 AS horizon, 0.9 AS confidence_level),
  TABLE `iowa_liquor_pipeline.future_regressors_weekly`
) f
ORDER BY f.store_number, f.category_name, f.forecast_timestamp;
