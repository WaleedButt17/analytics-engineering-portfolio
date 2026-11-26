CREATE OR REPLACE VIEW `your-project.marketing.qc_reach_missing` AS
WITH spend_amount AS (
  SELECT
    d.brand,
    DATE_TRUNC(f.date, MONTH) AS period_start,
    ROUND(SUM(f.spend), 2)    AS spend
  FROM `your-project.marketing.facebook_ads_campaigns_v2` f
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Meta'
   AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
  WHERE f.date >= '2025-07-01'
  GROUP BY d.brand, period_start
  HAVING SUM(f.spend) > 0
)
SELECT
  g.brand,
  g.period_start,
  LAST_DAY(g.period_start) AS period_end,
  g.spend,
  'no monthly reach row' AS problem
FROM spend_amount g
LEFT JOIN `your-project.marketing.vw_reach_period_brand` p
  ON  p.brand       = g.brand
 AND  p.period_start = g.period_start
 AND  p.grain          = 'monthly'
WHERE p.brand IS NULL

  AND DATE_ADD(LAST_DAY(g.period_start), INTERVAL 3 DAY)
      < CURRENT_DATE('Etc/GMT+6')
ORDER BY g.period_start DESC;

CREATE OR REPLACE VIEW `your-project.marketing.qc_utm_orphan_v2` AS
WITH observed AS (
  SELECT 'ga4_property_E' AS property, date, source AS traffic_source,
         campaign AS utm_campaign, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  WHERE date >= '2025-01-01'
  GROUP BY date, source, campaign
  UNION ALL
  SELECT 'ga4_property_D', date, source, campaign, MAX(sessions)
  FROM `your-project.marketing.ga4_brand_d`
  WHERE date >= '2025-01-01'
  GROUP BY date, source, campaign
),
aggregated AS (
  SELECT
    property, traffic_source, utm_campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ') AS utm_key,
    SUM(sessions) AS sessions,
    MIN(date) AS first_day,
    MAX(date) AS last_day
  FROM observed
  GROUP BY property, traffic_source, utm_campaign
),
known AS (
  SELECT property, traffic_source, utm_key
  FROM `your-project.marketing.dim_utm`
  UNION DISTINCT
  SELECT property, traffic_source,
         REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ')
  FROM `your-project.marketing.dim_utm_complement`
)
SELECT a.property, a.traffic_source, a.utm_campaign, a.sessions,
       a.first_day, a.last_day
FROM aggregated a
LEFT JOIN known c
  ON  c.property = a.property
 AND  c.traffic_source    = a.traffic_source
 AND  c.utm_key   = a.utm_key
WHERE c.property IS NULL
  AND a.sessions >= 100
ORDER BY a.sessions DESC;

SELECT
  source,
  campaign,
  MIN(date)              AS first_day,
  MAX(date)              AS last_day,
  COUNT(DISTINCT date)   AS days,
  SUM(sessions)          AS sessions
FROM (
  SELECT date, source, campaign, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY date, source, campaign
)
WHERE REGEXP_CONTAINS(LOWER(campaign), r'aon_brand_c|bc_condition')
GROUP BY source, campaign
ORDER BY sessions DESC;

SELECT channel, campaign_name, brand, initiative,
       active_since, active_until, spend_total
FROM `your-project.marketing.dim_campaign`
WHERE brand = 'Brand C'
ORDER BY active_since;

SELECT
  LOWER(TRIM(source)) AS source_normalised,
  COUNT(DISTINCT source) AS variants,
  STRING_AGG(DISTINCT source, ' | ') AS writes,
  SUM(sessions) AS sessions
FROM (
  SELECT date, source, campaign, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  WHERE date >= '2025-01-01'
  GROUP BY date, source, campaign
)
GROUP BY source_normalised
HAVING COUNT(DISTINCT source) > 1
ORDER BY sessions DESC;

SELECT
  u.brand,
  u.initiative,
  p.utm_campaign,
  p.sessions,
  p.total_users,
  p.new_users,
  ROUND(SAFE_DIVIDE(p.total_users, p.sessions), 3) AS users_by_session
FROM `your-project.marketing.ga4_users_period` p
JOIN `your-project.marketing.dim_utm_by_property` u
  ON  u.property = p.property
 AND  u.utm_key   = p.utm_key
WHERE p.grain = 'monthly'
  AND p.period_start = '2026-07-01'
ORDER BY p.sessions DESC;
