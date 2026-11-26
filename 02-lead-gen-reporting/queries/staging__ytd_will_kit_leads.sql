CREATE OR REPLACE VIEW `your-project.staging.ytd_will_kit_leads` AS
WITH will_kit_leads AS (
  SELECT
    SUM(leads_sold) AS ytd_leads
  FROM `your-project`.staging.v_leads_by_advertiser
  WHERE product IN ('Veteran Kit', 'No Cost Law')
    AND advertiser IN ('Advertiser A', 'N/A')
    AND date >= '2025-12-29'
)

SELECT
  ytd_leads,
  CASE
    WHEN ytd_leads <= 70000  THEN 1.00
    WHEN ytd_leads <= 90000  THEN 0.80
    WHEN ytd_leads <= 110000 THEN 0.60
    WHEN ytd_leads <= 130000 THEN 0.40
    WHEN ytd_leads <= 183752 THEN 0.25
    ELSE                          0.65
  END AS royalty_rate_per_lead
FROM will_kit_leads;
