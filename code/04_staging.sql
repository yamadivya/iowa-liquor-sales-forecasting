CREATE OR REPLACE TABLE `iowa_liquor_pipeline.raw_iowa_sales`
PARTITION BY date
CLUSTER BY store_number, category_name
AS
SELECT
  date,
  store_number,
  store_name,
  city,
  county,
  category_name,
  bottles_sold,
  sale_dollars,
  volume_sold_liters
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE
  EXTRACT(YEAR FROM date) BETWEEN 2017 AND 2024
  AND store_number IN ('2633', '4829', '3814')
  AND category_name IN (
    'AMERICAN VODKAS',
    'CANADIAN WHISKIES',
    'STRAIGHT BOURBON WHISKIES'
  );

  SELECT
  store_number,
  store_name,
  category_name,
  COUNT(*)                    AS total_rows,
  MIN(date)                   AS earliest,
  MAX(date)                   AS latest,
  ROUND(SUM(sale_dollars), 2) AS total_sales
FROM `iowa_liquor_pipeline.raw_iowa_sales`
GROUP BY 1, 2, 3
ORDER BY 1, 3;
/*Store 3814 — Costco name change:

COSTCO WHOLESALE #788 (2017–early 2018) and COSTCO WHOLESALE #788 / WDM (2018–2024) are the same physical store, just renamed. We need to merge them.

Store 4829 — Duplicate store name:

CENTRAL CITY LIQUOR, INC. appears briefly on just one day (2022-10-27) with tiny sales — likely a data entry error. We need to exclude it. */
CREATE OR REPLACE TABLE `iowa_liquor_pipeline.model_input`
PARTITION BY date
CLUSTER BY store_number, category_name
AS
WITH cleaned AS (
  SELECT
    date,
    store_number,
    -- Normalize store names
    CASE store_number
      WHEN '2633' THEN 'HY-VEE #3 / DES MOINES'
      WHEN '3814' THEN 'COSTCO WHOLESALE #788 / WDM'
      WHEN '4829' THEN 'CENTRAL CITY 2'
    END AS store_name,
    category_name,
    SUM(sale_dollars)      AS daily_sales,
    SUM(bottles_sold)      AS daily_bottles,
    SUM(volume_sold_liters) AS daily_liters
  FROM `iowa_liquor_pipeline.raw_iowa_sales`
  WHERE
    -- Exclude the one-day data entry error for store 4829
    NOT (store_number = '4829' AND store_name = 'CENTRAL CITY LIQUOR, INC.')
  GROUP BY 1, 2, 3, 4
),

-- Build a complete date spine (no gaps)
/*What it does:

Generates every single calendar date from 2017-01-01 to 2024-12-31
This gives us 2,922 dates — a complete backbone of time

Why we need it:
The raw data only has rows for days when sales happened. Days with no sales simply don't exist in the data. ARIMA needs a continuous unbroken time series — no missing dates allowed.*/
date_spine AS (
  SELECT date
  FROM UNNEST(
    GENERATE_DATE_ARRAY('2017-01-01', '2024-12-31', INTERVAL 1 DAY)
  ) AS date
),

-- Cross join to ensure every store+category has every date
full_grid AS (
  SELECT
    d.date,
    s.store_number,
    s.store_name,
    s.category_name
  FROM date_spine d
  CROSS JOIN (
    SELECT DISTINCT store_number, store_name, category_name
    FROM cleaned
  ) s
)

-- Final join: fill missing days with 0 sales (store was closed / no sales)
SELECT
  g.date,
  g.store_number,
  g.store_name,
  g.category_name,
  COALESCE(c.daily_sales,   0) AS daily_sales,
  COALESCE(c.daily_bottles, 0) AS daily_bottles,
  COALESCE(c.daily_liters,  0) AS daily_liters,

  -- Time-based regressors
  IF(EXTRACT(DAYOFWEEK FROM g.date) IN (1, 7), 1, 0) AS is_weekend,
  IF(EXTRACT(DAYOFWEEK FROM g.date) = 1, 1, 0)       AS is_sunday,

  -- US Federal Holidays
  IF(g.date IN (
    '2017-01-01','2018-01-01','2019-01-01','2020-01-01',
    '2021-01-01','2022-01-01','2023-01-01','2024-01-01',
    '2017-07-04','2018-07-04','2019-07-04','2020-07-04',
    '2021-07-05','2022-07-04','2023-07-04','2024-07-04',
    '2017-11-23','2018-11-22','2019-11-28','2020-11-26',
    '2021-11-25','2022-11-24','2023-11-23','2024-11-28', -- Thanksgiving
    '2017-12-25','2018-12-25','2019-12-25','2020-12-25',
    '2021-12-24','2022-12-26','2023-12-25','2024-12-25'  -- Christmas
  ), 1, 0) AS is_holiday,

  -- Pay period regressor (spending spikes mid & end of month)
  IF(EXTRACT(DAY FROM g.date) IN (1, 15), 1, 0) AS is_payday,

  -- Month number for seasonality context
  EXTRACT(MONTH FROM g.date) AS month,
  EXTRACT(YEAR FROM g.date)  AS year

FROM full_grid g
LEFT JOIN cleaned c
  ON g.date           = c.date
  AND g.store_number  = c.store_number
  AND g.category_name = c.category_name;


SELECT
  store_number,
  store_name,
  category_name,
  COUNT(*)                   AS total_rows,
  MIN(date)                  AS earliest,
  MAX(date)                  AS latest,
  ROUND(SUM(daily_sales), 2) AS total_sales,
  COUNTIF(daily_sales = 0)   AS zero_sales_days
FROM `iowa_liquor_pipeline.model_input`
GROUP BY 1, 2, 3
ORDER BY 1, 3;
