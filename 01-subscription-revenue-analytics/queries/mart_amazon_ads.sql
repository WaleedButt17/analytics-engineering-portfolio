CREATE OR REPLACE VIEW `your-project.marts.mart_amazon_ads`
AS SELECT
  report_date AS date,
  campaign_id,
  campaign_name,
  impressions,
  clicks,
  spend,
  purchases_1d,
  purchases_7d,
  purchases_14d,
  sales_1d,
  sales_7d,
  sales_14d,
  SAFE_DIVIDE(spend, NULLIF(clicks, 0)) AS cpc,
  SAFE_DIVIDE(sales_1d, NULLIF(spend, 0)) AS roas_1d,
  SAFE_DIVIDE(spend, NULLIF(sales_1d, 0)) AS acos_1d,
  SAFE_DIVIDE(sales_7d, NULLIF(spend, 0)) AS roas_7d,
  SAFE_DIVIDE(spend, NULLIF(sales_7d, 0)) AS acos_7d,
  SAFE_DIVIDE(sales_14d, NULLIF(spend, 0)) AS roas_14d,
  SAFE_DIVIDE(spend, NULLIF(sales_14d, 0)) AS acos_14d,
  ingested_at
FROM `your-project.staging.stg_amazon_ads`;
