CREATE OR REPLACE VIEW `your-project.staging.v_raw_spend` AS
SELECT
  date,
  'google' AS platform,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign_name,
  NULL AS adset_name,
  CAST(NULL AS STRING) AS adset_id,
  CAST(spend AS FLOAT64) AS spend,
  CAST(impressions AS FLOAT64) AS impressions,
  CAST(clicks AS FLOAT64) AS clicks,
  CAST(conversions AS FLOAT64) AS conversions,
  CAST(conversion_value AS FLOAT64) AS conversion_value,
  geo_target_region AS state
FROM `your-project`.Windsor.`Google Ads`
UNION ALL
SELECT
  date,
  'meta' AS platform,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign AS campaign_name,
  adset_name,
  CAST(adset_id AS STRING) AS adset_id,
  CAST(spend AS FLOAT64) AS spend,
  CAST(impressions AS FLOAT64) AS impressions,
  CAST(clicks AS FLOAT64) AS clicks,
  CAST(actions_lead AS FLOAT64) AS conversions,
  CAST(cost_per_action_type_lead AS FLOAT64) AS conversion_value,
  region AS state
FROM `your-project`.Windsor.Meta
UNION ALL
SELECT
  date,
  'microsoft' AS platform,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign AS campaign_name,
  NULL AS adset_name,
  CAST(NULL AS STRING) AS adset_id,
  CAST(spend AS FLOAT64) AS spend,
  CAST(impressions AS FLOAT64) AS impressions,
  CAST(clicks AS FLOAT64) AS clicks,
  CAST(conversions AS FLOAT64) AS conversions,
  CAST(revenue AS FLOAT64) AS conversion_value,
  state AS state
FROM `your-project`.Windsor.Microsoft
UNION ALL
SELECT
  date,
  'quora' AS platform,
  campaign_id,
  campaign_name,
  NULL AS adset_name,
  CAST(NULL AS STRING) AS adset_id,
  spend,
  CAST(impressions AS FLOAT64) AS impressions,
  CAST(clicks AS FLOAT64) AS clicks,
  CAST(conversions AS FLOAT64) AS conversions,
  cost_per_lead AS conversion_value,
  NULL AS state
FROM `your-project`.n8n.Quora
UNION ALL
SELECT
  date,
  'nextdoor' AS platform,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign_name,
  NULL AS adset_name,
  CAST(NULL AS STRING) AS adset_id,
  CAST(spend AS FLOAT64) AS spend,
  CAST(impressions AS INT64) AS impressions,
  CAST(clicks AS INT64) AS clicks,
  CAST(conversions AS INT64) AS conversions,
  NULL AS conversion_value,
  NULL AS state
FROM `your-project`.n8n.Nextdoor
UNION ALL
SELECT
  date,
  'tiktok' AS platform,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign AS campaign_name,
  adset_name,
  CAST(NULL AS STRING) AS adset_id,
  CAST(spend AS FLOAT64) AS spend,
  CAST(impressions AS FLOAT64) AS impressions,
  CAST(clicks AS FLOAT64) AS clicks,
  CAST(conversions AS FLOAT64) AS conversions,
  CAST(cost_per_conversion AS FLOAT64) AS conversion_value,
  NULL AS state
FROM `your-project`.Windsor.Tiktok
UNION ALL
SELECT
  date,
  'taboola' AS platform,
  CAST(campaign AS STRING) AS campaign_id,
  campaign AS campaign_name,
  NULL AS adset_name,
  CAST(NULL AS STRING) AS adset_id,
  CAST(spend AS FLOAT64) AS spend,
  CAST(impressions AS FLOAT64) AS impressions,
  CAST(clicks AS FLOAT64) AS clicks,
  CAST(cpa_actions_num AS FLOAT64) AS conversions,
  CAST(cpa AS FLOAT64) AS conversion_value,
  NULL AS state
FROM `your-project`.Windsor.Taboola
WHERE account_name = 'client-ad-account';
