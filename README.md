# Iowa Liquor Sales Forecasting — BigQuery ML

End-to-end sales forecasting pipeline using **ARIMA_PLUS_XREG** on the 
Iowa Liquor Sales public dataset in Google Cloud BigQuery.

##  Architecture
```
BigQuery Public Dataset (Iowa Liquor Sales)
↓
raw_iowa_sales         ← partitioned staging table
↓
model_input            ← daily cleaned + feature engineered
↓
model_input_weekly     ← aggregated to weekly
↓
arima_iowa_model       ← ARIMA_PLUS_XREG trained model
↓
future_regressors_weekly ← holiday + payday regressors
↓
sales_forecast         ← 12-week production forecast
```
##  Dataset
- **Source:** `bigquery-public-data.iowa_liquor_sales.sales`
- **Stores:** HY-VEE #3 (2633), Central City 2 (4829)
- **Categories:** American Vodkas, Canadian Whiskies, Straight Bourbon Whiskies
- **Training period:** 2017–2024
- **Forecast horizon:** 12 weeks

##  How to Run
1. Create a GCP project and enable APIs 
2. Open BigQuery Console
3. Run SQL files in order 

##  Model Performance (MAPE on Oct–Dec 2024 holdout)
| Store | Category | MAPE |
|---|---|---|
| Central City 2 | Canadian Whiskies | 13.73% |
| Central City 2 | American Vodkas | 19.50% |
| Central City 2 | Straight Bourbon | 24.90% |
| HY-VEE #3 | Straight Bourbon | 44.06% |
| HY-VEE #3 | Canadian Whiskies | 57.96% |
| HY-VEE #3 | American Vodkas | 116.55% |

##  Key Learnings
- Daily sparse data (60–88% zero days) - aggregate to weekly for better ARIMA results
- Stores with bulk ordering patterns (Costco) are not suitable for ARIMA

##  Tech Stack
- Google Cloud Platform (GCP)
- BigQuery ML (ARIMA_PLUS_XREG)
- Cloud Shell
- SQL
