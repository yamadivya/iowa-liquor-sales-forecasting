-- Stored procedure to rebuild all feature tables
CREATE OR REPLACE PROCEDURE `iowa_liquor_pipeline.build_model_input`()
BEGIN
  -- Step 1: Refresh staging table
  CREATE OR REPLACE TABLE `iowa_liquor_pipeline.raw_iowa_sales`
  PARTITION BY date
  CLUSTER BY store_number, category_name
  AS
  SELECT
    date, store_number, store_name, city, county,
    category_name, bottles_sold, sale_dollars, volume_sold_liters
  FROM `bigquery-public-data.iowa_liquor_sales.sales`
  WHERE
    EXTRACT(YEAR FROM date) BETWEEN 2017 AND 2024
    AND store_number IN ('2633', '4829', '3814')
    AND category_name IN (
      'AMERICAN VODKAS',
      'CANADIAN WHISKIES',
      'STRAIGHT BOURBON WHISKIES'
    );

  -- Step 2: Rebuild model_input
  CREATE OR REPLACE TABLE `iowa_liquor_pipeline.model_input`
  PARTITION BY date
  CLUSTER BY store_number, category_name
  AS
  WITH cleaned AS (
    SELECT
      date, store_number,
      CASE store_number
        WHEN '2633' THEN 'HY-VEE #3 / DES MOINES'
        WHEN '3814' THEN 'COSTCO WHOLESALE #788 / WDM'
        WHEN '4829' THEN 'CENTRAL CITY 2'
      END AS store_name,
      category_name,
      SUM(sale_dollars)       AS daily_sales,
      SUM(bottles_sold)       AS daily_bottles,
      SUM(volume_sold_liters) AS daily_liters
    FROM `iowa_liquor_pipeline.raw_iowa_sales`
    WHERE NOT (store_number = '4829' AND store_name = 'CENTRAL CITY LIQUOR, INC.')
    GROUP BY 1, 2, 3, 4
  ),
  date_spine AS (
    SELECT date
    FROM UNNEST(
      GENERATE_DATE_ARRAY('2017-01-01', '2024-12-31', INTERVAL 1 DAY)
    ) AS date
  ),
  full_grid AS (
    SELECT d.date, s.store_number, s.store_name, s.category_name
    FROM date_spine d
    CROSS JOIN (
      SELECT DISTINCT store_number, store_name, category_name FROM cleaned
    ) s
  )
  SELECT
    g.date, g.store_number, g.store_name, g.category_name,
    COALESCE(c.daily_sales,   0) AS daily_sales,
    COALESCE(c.daily_bottles, 0) AS daily_bottles,
    COALESCE(c.daily_liters,  0) AS daily_liters,
    IF(EXTRACT(DAYOFWEEK FROM g.date) IN (1, 7), 1, 0) AS is_weekend,
    IF(EXTRACT(DAYOFWEEK FROM g.date) = 1, 1, 0)       AS is_sunday,
    IF(EXTRACT(DAY FROM g.date) IN (1, 15), 1, 0)      AS is_payday,
    EXTRACT(MONTH FROM g.date) AS month,
    EXTRACT(YEAR FROM g.date)  AS year
  FROM full_grid g
  LEFT JOIN cleaned c
    ON g.date = c.date
    AND g.store_number = c.store_number
    AND g.category_name = c.category_name;

  SELECT CONCAT('build_model_input completed at ',
    CAST(CURRENT_TIMESTAMP() AS STRING)) AS status;
END;
