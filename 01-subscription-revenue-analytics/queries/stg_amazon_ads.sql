CREATE OR REPLACE VIEW `your-project.staging.stg_amazon_ads`
AS SELECT
  report_date,
  campaign_id,
  campaign_name,
  impressions,
  clicks,
  cost AS spend,
  purchases_1d,
  purchases_7d,
  purchases_14d,
  sales_1d,
  sales_7d,
  sales_14d,
  ingested_at
FROM `your-project.raw.daily_amazon_ads`
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY report_date, campaign_id
  ORDER BY ingested_at DESC
) = 1;
