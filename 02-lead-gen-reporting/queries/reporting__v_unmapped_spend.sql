CREATE OR REPLACE VIEW `your-project.reporting.v_unmapped_spend` AS
SELECT
  date,
  platform,
  campaign_id,
  campaign_name,
  adset_name,
  COALESCE(NULLIF(adset_name, ''), campaign_name) AS unmapped_name,
  region,
  phase,
  spend,
  impressions,
  clicks
FROM `your-project`.staging.v_spend_by_campaign
WHERE product = 'Unknown';
