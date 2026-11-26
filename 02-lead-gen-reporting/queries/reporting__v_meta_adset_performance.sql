CREATE OR REPLACE VIEW `your-project.reporting.v_meta_adset_performance` AS
WITH spend AS (
  SELECT
    date,
    product,
    region,
    adset_name,
    REGEXP_EXTRACT(adset_name, r'^([A-Z]{2})/') AS adset_state,
    SUM(spend) AS spend,
    SUM(main_spend) AS main_spend,
    SUM(research_spend) AS research_spend,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks
  FROM `your-project`.staging.v_spend_by_campaign
  WHERE platform = 'meta'
  AND adset_name IS NOT NULL
  GROUP BY 1, 2, 3, 4, 5
),

leads AS (
  SELECT
    date,
    product,
    region,
    state,
    SUM(leads_sold) AS leads_sold,
    SUM(leads_sold_paid) AS leads_sold_paid
  FROM `your-project`.staging.v_leads_by_product_state
  WHERE platform = 'meta'
  GROUP BY 1, 2, 3, 4
)

SELECT
  s.date,
  s.product,
  s.region,
  s.adset_name,
  s.adset_state,
  COALESCE(s.spend, 0) AS spend,
  COALESCE(s.main_spend, 0) AS main_spend,
  COALESCE(s.research_spend, 0) AS research_spend,
  COALESCE(s.impressions, 0) AS impressions,
  COALESCE(s.clicks, 0) AS clicks,
  COALESCE(l.leads_sold, 0) AS leads_sold,
  COALESCE(l.leads_sold_paid, 0) AS leads_sold_paid,
  CASE
    WHEN COALESCE(l.leads_sold_paid, 0) > 0
    THEN ROUND(s.main_spend / l.leads_sold_paid, 2)
    ELSE NULL
  END AS cpl
FROM spend s
LEFT JOIN leads l
  ON s.date = l.date
  AND s.product = l.product
  AND s.region = l.region
  AND s.adset_state = l.state;
