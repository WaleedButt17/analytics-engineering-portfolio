CREATE OR REPLACE VIEW `your-project.reporting.v_leads_by_product_state` AS
WITH campaign_product AS (
  SELECT DISTINCT date, platform, campaign_id, adset_name, product
  FROM `your-project`.staging.v_spend_by_campaign
),
spend_by_state AS (
  SELECT
    r.date,
    r.platform,
    COALESCE(m.state_code, 'Other') AS state,
    cp.product,
    SUM(r.spend) AS spend
  FROM `your-project`.staging.v_raw_spend r
  LEFT JOIN `your-project`.Mapping.state_mapping m
    ON LOWER(r.state) = LOWER(m.state_name)
  LEFT JOIN campaign_product cp
    ON r.date = cp.date
    AND r.platform = cp.platform
    AND r.campaign_id = cp.campaign_id
    AND COALESCE(r.adset_name, '') = COALESCE(cp.adset_name, '')
  WHERE r.state IS NOT NULL AND r.state != ''
  GROUP BY 1, 2, 3, 4
)
SELECT
  l.date,
  l.product,
  l.platform,
  l.region,
  l.state,
  SUM(l.leads_accepted) AS leads_accepted,
  SUM(l.leads_sold) AS leads_sold,
  SUM(l.leads_sold_paid) AS leads_sold_paid,
  SUM(l.leads_sold_advertiser_a) AS leads_sold_advertiser_a,
  SUM(l.revenue) AS revenue,
  MAX(l.advertiser) AS advertiser,
  MAX(l.contract_name) AS contract_name,
  COALESCE(SUM(s.spend), 0) AS spend,
  CASE
    WHEN SUM(l.leads_sold_advertiser_a) > 0 AND SUM(s.spend) > 0
    THEN ROUND(SUM(s.spend) / SUM(l.leads_sold_advertiser_a), 2)
    ELSE NULL
  END AS cpl
FROM `your-project`.staging.v_leads_by_product_state l
LEFT JOIN spend_by_state s
  ON l.date = s.date
  AND l.product = s.product
  AND l.platform = s.platform
  AND l.state = s.state
GROUP BY 1, 2, 3, 4, 5;
