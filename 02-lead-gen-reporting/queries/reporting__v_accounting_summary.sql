CREATE OR REPLACE VIEW `your-project.reporting.v_accounting_summary` AS
SELECT
  date,
  platform,
  campaign_id,
  CASE
    WHEN platform = 'meta' AND adset_name IS NOT NULL AND adset_name != ''
    THEN adset_name
    ELSE campaign_name
  END AS campaign_name,
  product,
  region,
  phase,
  spend,
  main_spend,
  research_spend,
  impressions,
  clicks,
  conversions,
  conversion_value
FROM `your-project`.staging.v_spend_by_campaign;
