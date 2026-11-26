CREATE OR REPLACE VIEW `your-project.marketing.stg_meta_brand_e_v2` AS
SELECT
  f.date,
  'Meta'             AS channel,
  d.initiative,
  SUM(f.spend)       AS spend,
  SUM(f.clicks)      AS clicks,
  SUM(f.impressions) AS impressions,
  SUM(f.reach)       AS reach_daily
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.brand    = 'Brand E'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
GROUP BY f.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_e_v2` AS
SELECT
  g.date,
  'Google'           AS channel,
  d.initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
 AND  d.brand    = 'Brand E'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
GROUP BY g.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_e_v2` AS
SELECT
  g.date,
  CASE g.source WHEN 'meta' THEN 'Meta' WHEN 'google' THEN 'Google' END AS channel,
  m.initiative,
  SUM(IF(g.event_name = 'registration_complete', g.event_count, 0)) AS leads,
  SUM(IF(g.event_name = 'session_start',         g.event_count, 0)) AS sessions,
  SUM(IF(g.event_name = 'first_visit',           g.event_count, 0)) AS new_users,
  SAFE_DIVIDE(
    SUM(IF(g.event_name = 'session_start', g.average_session_duration * g.event_count, 0)),
    SUM(IF(g.event_name = 'session_start', g.event_count, 0))
  ) AS avg_session_duration
FROM `your-project.marketing.ga4_brand_e` g
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = 'ga4_property_E'
 AND  m.traffic_source    = g.source
 AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
 AND  m.brand  = 'Brand E'
 AND  m.in_model
WHERE g.source IN ('google', 'meta')
GROUP BY g.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_e_v2` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_e_v2`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_e_v2`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users, avg_session_duration
  FROM `your-project.marketing.stg_ga4_brand_e_v2`
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

  CAST(NULL AS FLOAT64)                AS conversion_rate_users
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
  spend, clicks, impressions, reach_daily,
  ctr, cpc, cpa,
  conversion_rate_sessions, conversion_rate_users,

  'brand_e_v2'           AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive
FROM `your-project.marketing.mart_kpis_brand_e_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_e` AS
WITH base AS (
  SELECT report_date, channel, initiative, leads, sessions, new_users,
         avg_session_duration, spend, clicks, impressions
  FROM `your-project.marketing.vw_brand_e_v2`
  WHERE initiative IS NOT NULL
)
SELECT
  grain,
  CASE grain
    WHEN 'weekly'   THEN DATE_TRUNC(report_date, ISOWEEK)
    WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                            DATE_TRUNC(report_date, MONTH),
                            DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 15 DAY))
    WHEN 'monthly'  THEN DATE_TRUNC(report_date, MONTH)
  END AS period_start,
  'Brand E' AS brand,
  initiative, channel,
  SUM(leads)       AS leads,
  SUM(sessions)    AS sessions,
  SUM(new_users)   AS new_users,
  SUM(spend)       AS spend,
  SUM(clicks)      AS clicks,
  SUM(impressions) AS impressions,
  SAFE_DIVIDE(SUM(clicks), SUM(impressions)) AS ctr,
  SAFE_DIVIDE(SUM(spend),  SUM(clicks))      AS cpc,
  SAFE_DIVIDE(SUM(spend),  SUM(leads))       AS cpa,
  SAFE_DIVIDE(SUM(leads),  SUM(sessions))    AS conversion_rate_sessions,
  SAFE_DIVIDE(SUM(avg_session_duration * sessions), SUM(sessions)) AS avg_session_duration,
  'NA' AS reach_daily_note
FROM base
CROSS JOIN UNNEST(['weekly','biweekly','monthly']) AS grain
GROUP BY grain, period_start, initiative, channel;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_e_rollup_weekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_e`
WHERE grain = 'weekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_e_rollup_biweekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_e`
WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_e_rollup_v2` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_e`
WHERE grain = 'monthly';
