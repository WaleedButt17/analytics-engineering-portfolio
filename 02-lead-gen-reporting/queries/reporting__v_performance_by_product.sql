CREATE OR REPLACE VIEW `your-project.reporting.v_performance_by_product` AS
WITH spend_agg AS (
  SELECT
    date,
    product,
    platform,
    region,
    MAX(phase) AS phase,
    SUM(spend) AS spend,
    SUM(main_spend) AS main_spend,
    SUM(research_spend) AS research_spend,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    SUM(conversions) AS ad_conversions
  FROM `your-project`.staging.v_spend_by_campaign
  WHERE product NOT IN ('Unknown', 'All Products')
  GROUP BY 1, 2, 3, 4
),

leads_agg AS (
  SELECT
    date,
    product,
    platform,
    region,
    leads_accepted,
    leads_sold,
    leads_sold_paid,
    leads_sold_advertiser_a,
    leads_sold_na,
    leads_sold_advertiser_a_na,
    leads_sold_advertiser_a_paid,
    leads_sold_na_paid,
    leads_sold_partner_b,
    revenue
  FROM `your-project`.staging.v_leads_by_product
)

SELECT
  COALESCE(s.date, l.date) AS date,
  COALESCE(s.product, l.product) AS product,
  COALESCE(s.platform, l.platform) AS platform,
  COALESCE(s.region, l.region, 'US') AS region,
  COALESCE(s.phase, 'Regular Spend') AS phase,
  COALESCE(s.spend, 0) AS spend,
  COALESCE(s.main_spend, 0) AS main_spend,
  COALESCE(s.research_spend, 0) AS research_spend,
  COALESCE(s.impressions, 0) AS impressions,
  COALESCE(s.clicks, 0) AS clicks,
  COALESCE(s.ad_conversions, 0) AS ad_conversions,
  COALESCE(l.leads_accepted, 0) AS leads_accepted,
  COALESCE(l.leads_sold, 0) AS leads_sold,
  COALESCE(l.leads_sold_paid, 0) AS leads_sold_paid,
  COALESCE(l.leads_sold_advertiser_a, 0) AS leads_sold_advertiser_a,
  COALESCE(l.leads_sold_na, 0) AS leads_sold_na,
  COALESCE(l.leads_sold_advertiser_a_na, 0) AS leads_sold_advertiser_a_na,
  COALESCE(l.leads_sold_advertiser_a_paid, 0) AS leads_sold_advertiser_a_paid,
  COALESCE(l.leads_sold_na_paid, 0) AS leads_sold_na_paid,
  COALESCE(l.leads_sold_partner_b, 0) AS leads_sold_partner_b,
  COALESCE(l.revenue, 0) AS revenue,
  CASE
    WHEN COALESCE(l.leads_sold_paid, 0) > 0
    THEN ROUND(COALESCE(s.main_spend, 0) / l.leads_sold_paid, 2)
    ELSE NULL
  END AS cpl,
  CASE
    WHEN COALESCE(s.spend, 0) > 0
      OR COALESCE(l.leads_sold, 0) > 0
      OR COALESCE(s.impressions, 0) > 0
    THEN 1
    ELSE 0
  END AS has_data
FROM spend_agg s
FULL OUTER JOIN leads_agg l
  ON s.date = l.date
  AND s.product = l.product
  AND s.platform = l.platform
  AND s.region = l.region;
