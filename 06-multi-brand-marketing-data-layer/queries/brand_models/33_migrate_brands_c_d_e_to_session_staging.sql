CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_c_v2` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_c_v2`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_c_v2`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users,
         total_users, total_users_bound_upper,
         avg_session_duration, bounce_rate, engagement_rate
  FROM `your-project.marketing.stg_ga4_brand_c_v3`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  NULLIF(COALESCE(a.initiative, g.initiative), '(no initiative)') AS initiative,
  g.leads, g.sessions, g.new_users, g.avg_session_duration,
  a.spend, a.clicks, a.impressions, a.reach_daily,
  SAFE_DIVIDE(a.clicks, a.impressions) AS ctr,
  SAFE_DIVIDE(a.spend,  a.clicks)      AS cpc,
  SAFE_DIVIDE(a.spend,  g.leads)       AS cpa,
  SAFE_DIVIDE(g.leads,  g.sessions)    AS conversion_rate_sessions,

  CAST(NULL AS FLOAT64)                AS conversion_rate_users,

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

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_c_v2` AS
SELECT
  'Brand C' AS brand,
  'Therapy Area 1' AS category,
  initiative,
  date AS report_date,
  channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions,
  reach_daily,
  ctr, cpc, cpa,
  conversion_rate_sessions,
  conversion_rate_users,

  'brand_c_v2'                 AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,

  total_users,
  total_users_bound_upper,
  bounce_rate,
  engagement_rate
FROM `your-project.marketing.mart_kpis_brand_c_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_e_v2` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_e_v2`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_e_v2`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users,
         total_users, total_users_bound_upper,
         avg_session_duration, bounce_rate, engagement_rate
  FROM `your-project.marketing.stg_ga4_brand_e_v3`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  NULLIF(COALESCE(a.initiative, g.initiative), '(no initiative)') AS initiative,
  g.leads, g.sessions, g.new_users, g.avg_session_duration,
  a.spend, a.clicks, a.impressions, a.reach_daily,
  SAFE_DIVIDE(a.clicks, a.impressions) AS ctr,
  SAFE_DIVIDE(a.spend,  a.clicks)      AS cpc,
  SAFE_DIVIDE(a.spend,  g.leads)       AS cpa,
  SAFE_DIVIDE(g.leads,  g.sessions)    AS conversion_rate_sessions,

  CAST(NULL AS FLOAT64)                AS conversion_rate_users,

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

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_e_v2` AS
SELECT
  'Brand E' AS brand,
  CAST(NULL AS STRING) AS category,
  initiative,
  date AS report_date,
  channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions,
  reach_daily,
  ctr, cpc, cpa,
  conversion_rate_sessions,
  conversion_rate_users,

  'brand_e_v2'                 AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,

  total_users,
  total_users_bound_upper,
  bounce_rate,
  engagement_rate
FROM `your-project.marketing.mart_kpis_brand_e_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_d_v2` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily, complete_views_video
  FROM `your-project.marketing.stg_meta_brand_d_v2`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily, complete_views_video
  FROM `your-project.marketing.stg_dv360_brand_d`
),
ga4 AS (
  SELECT date, channel, initiative, sessions, new_users,
         total_users, total_users_bound_upper,
         avg_session_duration, bounce_rate, engagement_rate
  FROM `your-project.marketing.stg_ga4_brand_d_v3`
),
scroll AS (
  SELECT date, channel, initiative, scroll_events
  FROM `your-project.marketing.stg_ga4_brand_d_v2`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  COALESCE(a.initiative, g.initiative) AS initiative,
  g.sessions,
  g.new_users,
  s.scroll_events,
  g.avg_session_duration,
  a.spend, a.clicks, a.impressions, a.reach_daily, a.complete_views_video,
  SAFE_DIVIDE(a.clicks, a.impressions)               AS ctr,
  SAFE_DIVIDE(a.spend,  a.clicks)                    AS cpc,
  SAFE_DIVIDE(a.spend,  a.impressions) * 1000        AS cpm,
  SAFE_DIVIDE(a.complete_views_video, a.impressions) AS vtr,

  g.total_users,
  g.total_users_bound_upper,
  g.bounce_rate,
  g.engagement_rate
FROM ads a
FULL OUTER JOIN ga4 g
  ON  a.date  = g.date
 AND  a.channel = g.channel
 AND  COALESCE(a.initiative, '(no initiative)')
    = COALESCE(g.initiative, '(no initiative)')
LEFT JOIN scroll s
  ON  s.date  = COALESCE(a.date, g.date)
 AND  s.channel = COALESCE(a.channel, g.channel)
 AND  COALESCE(s.initiative, '(no initiative)')
    = COALESCE(a.initiative, g.initiative, '(no initiative)');

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_d_v2` AS
SELECT
  'Brand D' AS brand,
  CAST(NULL AS STRING) AS category,
  initiative,
  date AS report_date,
  channel,
  sessions, new_users, scroll_events, avg_session_duration,
  spend, clicks, impressions,
  reach_daily, complete_views_video,
  ctr, cpc, cpm, vtr,

  'brand_d_v2'                AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  FALSE AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,

  total_users,
  total_users_bound_upper,
  bounce_rate,
  engagement_rate
FROM `your-project.marketing.mart_kpis_brand_d_v2`;

SELECT
  brand, channel,
  ROUND(SUM(spend), 2) AS spend,
  SUM(sessions)        AS sessions,
  SUM(leads)           AS leads,
  COUNTIF(total_users     IS NOT NULL) AS with_total_users,
  COUNTIF(bounce_rate     IS NOT NULL) AS with_bounce,
  COUNTIF(engagement_rate IS NOT NULL) AS with_engagement
FROM (
  SELECT brand, channel, spend, sessions, leads, total_users, bounce_rate, engagement_rate, report_date
  FROM `your-project.marketing.vw_brand_c_v2`
  UNION ALL
  SELECT brand, channel, spend, sessions, leads, total_users, bounce_rate, engagement_rate, report_date
  FROM `your-project.marketing.vw_brand_e_v2`
  UNION ALL
  SELECT brand, channel, spend, sessions, CAST(NULL AS INT64), total_users, bounce_rate, engagement_rate, report_date
  FROM `your-project.marketing.vw_brand_d_v2`
)
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY brand, channel
ORDER BY brand, channel;
