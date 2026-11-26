CREATE OR REPLACE VIEW `your-project.marketing.vw_conversion_users_utm` AS
WITH events_cte AS (
  SELECT 'ga4_property_E' AS property, date,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
         SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY date, utm_key
  UNION ALL
  SELECT 'ga4_property_D' AS property, date,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
         SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads
  FROM `your-project.marketing.ga4_brand_d`
  GROUP BY date, utm_key
),

property_measures_leads AS (
  SELECT property, SUM(leads) > 0 AS measures_leads
  FROM events_cte
  GROUP BY property
)
SELECT
  p.grain,
  p.period_start,
  p.period_end,
  m.brand,
  m.initiative,
  p.utm_campaign,
  p.property,

  p.sessions,
  p.total_users,
  p.new_users,
  IF(ANY_VALUE(f.measures_leads), SUM(e.leads), NULL) AS leads,

  IF(ANY_VALUE(f.measures_leads),
     SAFE_DIVIDE(SUM(e.leads), p.total_users), NULL) AS conversion_rate_users,
  IF(ANY_VALUE(f.measures_leads),
     SAFE_DIVIDE(SUM(e.leads), p.sessions),    NULL) AS conversion_rate_sessions,
  ANY_VALUE(f.measures_leads) AS property_measures_leads,

  'windsor_api_no_threshold' AS base_users,
  TRUE  AS users_is_exact,
  FALSE AS users_is_additive,
  'Looker publishes a figure with GA4 thresholding applied, so it is lower. '
  || 'This figure is higher and will not match the dashboard.' AS note_divergence
FROM `your-project.marketing.ga4_users_period` p
JOIN `your-project.marketing.dim_utm_by_property` m
  ON  m.property = p.property
 AND  m.utm_key   = p.utm_key
JOIN property_measures_leads f
  ON  f.property = p.property
LEFT JOIN events_cte e
  ON  e.property = p.property
 AND  e.utm_key   = p.utm_key
 AND  e.date BETWEEN p.period_start AND p.period_end
GROUP BY
  p.grain, p.period_start, p.period_end, m.brand, m.initiative,
  p.utm_campaign, p.property, p.sessions, p.total_users, p.new_users;

CREATE OR REPLACE VIEW `your-project.marketing.vw_conversion_users_initiative` AS
WITH base AS (
  SELECT
    grain, period_start, period_end, brand, initiative,
    property, utm_campaign, sessions, total_users, leads, property_measures_leads
  FROM `your-project.marketing.vw_conversion_users_utm`
)
SELECT
  grain,
  period_start,
  ANY_VALUE(period_end) AS period_end,
  brand,
  initiative,

  SUM(sessions) AS sessions,
  IF(LOGICAL_OR(property_measures_leads), SUM(leads), NULL) AS leads,

  IF(COUNT(DISTINCT FORMAT('%t|%t', property, utm_campaign)) = 1,
     SUM(total_users), NULL)                       AS total_users,
  SUM(total_users)                                 AS total_users_bound_upper,
  COUNT(DISTINCT FORMAT('%t|%t', property, utm_campaign)) AS populations_in_period,
  COUNT(DISTINCT FORMAT('%t|%t', property, utm_campaign)) = 1 AS users_is_exact,

  IF(COUNT(DISTINCT FORMAT('%t|%t', property, utm_campaign)) = 1
       AND LOGICAL_OR(property_measures_leads),
     SAFE_DIVIDE(SUM(leads), SUM(total_users)), NULL) AS conversion_rate_users,
  IF(LOGICAL_OR(property_measures_leads),
     SAFE_DIVIDE(SUM(leads), SUM(sessions)), NULL)    AS conversion_rate_sessions,

  'windsor_api_no_threshold' AS base_users,
  FALSE AS users_is_additive
FROM base
GROUP BY grain, period_start, brand, initiative;

CREATE OR REPLACE VIEW `your-project.marketing.qc_threshold_windsor` AS
WITH daily AS (
  SELECT 'ga4_property_E' AS property,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
         date, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY utm_key, date, source, campaign
  UNION ALL
  SELECT 'ga4_property_D' AS property,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
         date, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_d`
  GROUP BY utm_key, date, source, campaign
)
SELECT
  p.grain,
  p.period_start,
  m.brand,
  p.property,
  p.utm_campaign,
  p.sessions                   AS sessions_period,
  SUM(d.sessions)              AS sessions_sum_daily,
  SUM(d.sessions) - p.sessions AS difference,
  ROUND(SAFE_DIVIDE(SUM(d.sessions) - p.sessions, p.sessions) * 100, 2) AS pct
FROM `your-project.marketing.ga4_users_period` p
JOIN `your-project.marketing.dim_utm_by_property` m
  ON  m.property = p.property
 AND  m.utm_key   = p.utm_key
JOIN daily d
  ON  d.property = p.property
 AND  d.utm_key   = p.utm_key
 AND  d.date BETWEEN p.period_start AND p.period_end
WHERE p.grain = 'monthly'
GROUP BY p.grain, p.period_start, m.brand, p.property,
         p.utm_campaign, p.sessions
HAVING ABS(SAFE_DIVIDE(SUM(d.sessions) - p.sessions, p.sessions)) > 0.10
ORDER BY ABS(pct) DESC;
