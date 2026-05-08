SELECT *
FROM `iowa_liquor_pipeline.sales_forecast`
WHERE store_number = '4829'
ORDER BY category_name, forecast_date;
