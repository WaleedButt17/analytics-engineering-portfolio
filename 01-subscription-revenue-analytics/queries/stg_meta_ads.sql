CREATE OR REPLACE VIEW `your-project.staging.stg_meta_ads`
AS WITH combined AS (
  SELECT
    date AS ad_date,
    account_id,
    account_name,
    campaign_id,
    campaign_name,
    country,
    region,
    impressions,
    reach,
    frequency,
    spend,
    link_clicks,
    unique_outbound_clicks,
    ctr,
    cpc,
    cpm,
    landing_page_views,
    cost_per_landing_page_view,
    click_to_lpv_dropoff_pct
  FROM `your-project.raw.historical_meta`

  UNION ALL

  SELECT
    date AS ad_date,
    account_id,
    account_name,
    campaign_id,
    campaign_name,
    country,
    region,
    impressions,
    reach,
    frequency,
    spend,
    link_clicks,
    unique_outbound_clicks,
    ctr,
    cpc,
    cpm,
    landing_page_views,
    cost_per_landing_page_view,
    click_to_lpv_dropoff_pct
  FROM `your-project.raw.daily_meta`
  WHERE date >= '2026-05-31'
)

SELECT
  ad_date,
  account_id,
  account_name,
  campaign_id,
  campaign_name,
  country,
  region,
  SUM(impressions) AS impressions,
  SUM(reach) AS reach,
  AVG(frequency) AS frequency,
  SUM(spend) AS spend,
  SUM(link_clicks) AS link_clicks,
  SUM(unique_outbound_clicks) AS unique_outbound_clicks,
  SAFE_DIVIDE(SUM(link_clicks), SUM(impressions)) AS ctr,
  SAFE_DIVIDE(SUM(spend), SUM(link_clicks)) AS cpc,
  SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS cpm,
  SUM(landing_page_views) AS landing_page_views,
  SAFE_DIVIDE(SUM(spend), SUM(landing_page_views)) AS cost_per_landing_page_view,
  SAFE_DIVIDE(SUM(unique_outbound_clicks) - SUM(landing_page_views), SUM(unique_outbound_clicks)) AS click_to_lpv_dropoff_pct
FROM combined
GROUP BY ad_date, account_id, account_name, campaign_id, campaign_name, country, region;
