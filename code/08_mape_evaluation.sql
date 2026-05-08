-- Evaluate model accuracy using MAPE on holdout period
SELECT
  h.store_number,
  h.category_name,
  ROUND(AVG(ABS(h.weekly_sales - f.forecast_value)
    / NULLIF(h.weekly_sales, 0)) * 100, 2) AS mape_pct,
  ROUND(AVG(h.weekly_sales), 2)            AS avg_actual_sales,
  ROUND(AVG(f.forecast_value), 2)          AS avg_predicted_sales,
  COUNT(*)                                 AS weeks_evaluated
FROM `iowa_liquor_pipeline.model_input_weekly` h
JOIN ML.FORECAST(
  MODEL `iowa_liquor_pipeline.arima_iowa_model`,
  STRUCT(12 AS horizon, 0.9 AS confidence_level),
  TABLE `iowa_liquor_pipeline.future_regressors_weekly`
) f
ON h.store_number   = f.store_number
AND h.category_name = f.category_name
AND h.week_start    = DATE(f.forecast_timestamp)
WHERE h.week_start BETWEEN '2024-10-07' AND '2024-12-30'
GROUP BY 1, 2
ORDER BY mape_pct;
