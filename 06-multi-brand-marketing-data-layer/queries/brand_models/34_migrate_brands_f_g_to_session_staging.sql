CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_f_v2` AS
SELECT
  s.date,
  CASE s.source WHEN 'meta' THEN 'Meta' WHEN 'google' THEN 'Google' END AS channel,
  m.initiative,
  SUM(IFNULL(e.leads, 0)) AS leads,
  SUM(s.sessions)         AS sessions,
  SUM(s.new_users)        AS new_users,
  IF(LOGICAL_AND(s.media_cte = 1), SUM(s.total_users), NULL) AS total_users,
  SUM(s.total_users_bound_upper) AS total_users_bound_upper,
  SAFE_DIVIDE(SUM(s.avg_session_duration * s.sessions), SUM(s.sessions)) AS avg_session_duration,
  SAFE_DIVIDE(SUM(s.bounce_rate     * s.sessions), SUM(s.sessions)) AS bounce_rate,
  SAFE_DIVIDE(SUM(s.engagement_rate * s.sessions), SUM(s.sessions)) AS engagement_rate
FROM `your-project.marketing.stg_ga4_sessions_base` s
LEFT JOIN `your-project.marketing.stg_ga4_events_base` e
  ON  e.property = s.property AND e.date = s.date
 AND  e.source    = s.source    AND e.utm_key = s.utm_key
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = s.property
 AND  m.traffic_source    = s.source
 AND  m.utm_key   = s.utm_key
 AND  m.brand  = 'Brand F'
 AND  m.in_model
WHERE s.property = 'ga4_property_E'
GROUP BY s.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_f` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_f`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_f`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users,
         total_users, total_users_bound_upper,
         avg_session_duration, bounce_rate, engagement_rate
  FROM `your-project.marketing.stg_ga4_brand_f_v2`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  COALESCE(a.initiative, g.initiative) AS initiative,
  g.leads, g.sessions, g.new_users, g.avg_session_duration,
  a.spend, a.clicks, a.impressions, a.reach_daily,
  SAFE_DIVIDE(a.clicks, a.impressions) AS ctr,
  SAFE_DIVIDE(a.spend,  a.clicks)      AS cpc,
  SAFE_DIVIDE(a.spend,  g.leads)       AS cpa,
  SAFE_DIVIDE(g.leads,  g.sessions)    AS conversion_rate_sessions,
  g.total_users,
  g.total_users_bound_upper,
  g.bounce_rate,
  g.engagement_rate
FROM ads a
FULL OUTER JOIN ga4 g
  ON  a.date  = g.date
 AND  a.channel = g.channel
 AND  COALESCE(a.initiative, '(no initiative)')
    = COALESCE(g.initiative, '(no initiative)');

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_g_v2` AS
SELECT
  s.date,
  CASE s.source WHEN 'meta' THEN 'Meta' WHEN 'google' THEN 'Google' END AS channel,
  m.initiative,
  SUM(IFNULL(e.leads, 0)) AS leads,
  SUM(s.sessions)         AS sessions,
  SUM(s.new_users)        AS new_users,
  IF(LOGICAL_AND(s.media_cte = 1), SUM(s.total_users), NULL) AS total_users,
  SUM(s.total_users_bound_upper) AS total_users_bound_upper,
  SAFE_DIVIDE(SUM(s.avg_session_duration * s.sessions), SUM(s.sessions)) AS avg_session_duration,
  SAFE_DIVIDE(SUM(s.bounce_rate     * s.sessions), SUM(s.sessions)) AS bounce_rate,
  SAFE_DIVIDE(SUM(s.engagement_rate * s.sessions), SUM(s.sessions)) AS engagement_rate
FROM `your-project.marketing.stg_ga4_sessions_base` s
LEFT JOIN `your-project.marketing.stg_ga4_events_base` e
  ON  e.property = s.property AND e.date = s.date
 AND  e.source    = s.source    AND e.utm_key = s.utm_key
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = s.property
 AND  m.traffic_source    = s.source
 AND  m.utm_key   = s.utm_key
 AND  m.brand  = 'Brand G'
 AND  m.in_model
WHERE s.property = 'ga4_property_E'
GROUP BY s.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_g` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_g`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_g`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users,
         total_users, total_users_bound_upper,
         avg_session_duration, bounce_rate, engagement_rate
  FROM `your-project.marketing.stg_ga4_brand_g_v2`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  COALESCE(a.initiative, g.initiative) AS initiative,
  g.leads, g.sessions, g.new_users, g.avg_session_duration,
  a.spend, a.clicks, a.impressions, a.reach_daily,
  SAFE_DIVIDE(a.clicks, a.impressions) AS ctr,
  SAFE_DIVIDE(a.spend,  a.clicks)      AS cpc,
  SAFE_DIVIDE(a.spend,  g.leads)       AS cpa,
  SAFE_DIVIDE(g.leads,  g.sessions)    AS conversion_rate_sessions,
  g.total_users,
  g.total_users_bound_upper,
  g.bounce_rate,
  g.engagement_rate
FROM ads a
FULL OUTER JOIN ga4 g
  ON  a.date  = g.date
 AND  a.channel = g.channel
 AND  COALESCE(a.initiative, '(no initiative)')
    = COALESCE(g.initiative, '(no initiative)');

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_f` AS
SELECT
  'Brand F' AS brand,
  'Therapy Area 2'  AS category,
  initiative, date AS report_date, channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions, reach_daily,
  ctr, cpc, cpa, conversion_rate_sessions,
  'brand_f'             AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,

  FALSE AS reconcilable_in_looker,
  'raw_platform_table' AS base_reconciliation,
  total_users, total_users_bound_upper, bounce_rate, engagement_rate
FROM `your-project.marketing.mart_kpis_brand_f`;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_g` AS
SELECT
  'Brand G'    AS brand,
  'Therapy Area 1' AS category,
  initiative, date AS report_date, channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions, reach_daily,
  ctr, cpc, cpa, conversion_rate_sessions,
  'brand_g'                 AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,
  FALSE AS reconcilable_in_looker,
  'raw_platform_table' AS base_reconciliation,
  TRUE  AS is_historical,
  DATE '2025-12-12' AS last_day_active,
  total_users, total_users_bound_upper, bounce_rate, engagement_rate
FROM `your-project.marketing.mart_kpis_brand_g`;

SELECT
  brand,
  ROUND(SUM(spend), 2) AS spend,
  SUM(sessions)        AS sessions,
  SUM(leads)           AS leads,
  COUNTIF(total_users     IS NOT NULL) AS with_total_users,
  COUNTIF(bounce_rate     IS NOT NULL) AS with_bounce,
  COUNT(*)             AS n_rows
FROM (
  SELECT brand, spend, sessions, leads, total_users, bounce_rate
  FROM `your-project.marketing.vw_brand_f`
  UNION ALL
  SELECT brand, spend, sessions, leads, total_users, bounce_rate
  FROM `your-project.marketing.vw_brand_g`
)
GROUP BY brand ORDER BY brand;
