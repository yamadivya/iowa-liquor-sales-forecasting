# Query 1 — See what the raw data looks like:
SELECT * 
FROM `bigquery-public-data.iowa_liquor_sales.sales`
LIMIT 5;
# Query 2 — Understand the scale:
SELECT
  MIN(date)                        AS earliest_date,
  MAX(date)                        AS latest_date,
  COUNT(*)                         AS total_rows,
  COUNT(DISTINCT store_number)     AS total_stores,
  COUNT(DISTINCT category_name)    AS total_categories,
  ROUND(SUM(sale_dollars) / 1e9, 2) AS total_sales_billions
FROM `bigquery-public-data.iowa_liquor_sales.sales`;
# Query 3 — Find the top categories by revenue:
SELECT
  category_name,
  ROUND(SUM(sale_dollars), 2) AS total_sales,
  SUM(bottles_sold)           AS total_bottles
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE EXTRACT(YEAR FROM date) >= 2020
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;
# Query 4 — Top stores by revenue:
SELECT
  store_number,
  store_name,
  city,
  ROUND(SUM(sale_dollars), 2) AS total_sales
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE EXTRACT(YEAR FROM date) >= 2020
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 10;
# Query 5 — Check data consistency for our top 3 categories:
SELECT
  category_name,
  EXTRACT(YEAR FROM date) AS year,
  COUNT(DISTINCT store_number) AS active_stores,
  COUNT(DISTINCT date)         AS trading_days,
  ROUND(SUM(sale_dollars), 2)  AS annual_sales
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE category_name IN ('AMERICAN VODKAS', 'CANADIAN WHISKIES', 'STRAIGHT BOURBON WHISKIES')
GROUP BY 1, 2
ORDER BY 1, 2;
# 2016 and earlier — AMERICAN VODKAS only has 88 trading days (incomplete)
# 2026 — only 69 days so far (partial year)
# Training window: 2017–2024
SELECT
  store_number,
  store_name,
  city,
  ROUND(SUM(sale_dollars), 2) AS total_sales
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE 
  EXTRACT(YEAR FROM date) BETWEEN 2017 AND 2024
  AND category_name IN (
    'AMERICAN VODKAS', 
    'CANADIAN WHISKIES', 
    'STRAIGHT BOURBON WHISKIES'
  )
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 10;
