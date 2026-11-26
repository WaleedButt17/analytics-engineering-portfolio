CREATE OR REPLACE VIEW `your-project.marketing.stg_meta_brand_f` AS
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
 AND  d.brand    = 'Brand F'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
GROUP BY f.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_f` AS
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
 AND  d.brand    = 'Brand F'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
GROUP BY g.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_f` AS
WITH by_utm AS (
  SELECT
    date, source, campaign,
    MAX(sessions)                 AS sessions,
    MAX(average_session_duration) AS avg_session_duration,
    SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads,
    SUM(IF(event_name = 'first_visit',           event_count, 0)) AS new_users
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY date, source, campaign
)
SELECT
  p.date,
  CASE p.source WHEN 'meta' THEN 'Meta' WHEN 'google' THEN 'Google' END AS channel,
  m.initiative,
  SUM(p.leads)     AS leads,
  SUM(p.sessions)  AS sessions,
  SUM(p.new_users) AS new_users,
  SAFE_DIVIDE(SUM(p.avg_session_duration * p.sessions), SUM(p.sessions)) AS avg_session_duration
FROM by_utm p
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = 'ga4_property_E'
 AND  m.traffic_source    = p.source
 AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
 AND  m.brand  = 'Brand F'
 AND  m.in_model
WHERE p.source IN ('google', 'meta')
GROUP BY p.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_f` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_f`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_f`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users, avg_session_duration
  FROM `your-project.marketing.stg_ga4_brand_f`
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
  SAFE_DIVIDE(g.leads,  g.sessions)    AS conversion_rate_sessions
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
  initiative,
  date AS report_date,
  channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions, reach_daily,
  ctr, cpc, cpa,
  conversion_rate_sessions,

  'brand_f'             AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,

  FALSE AS reconcilable_in_looker,
  'platform_catalogue' AS base_reconciliation
FROM `your-project.marketing.mart_kpis_brand_f`;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_f` AS
WITH base AS (
  SELECT report_date, channel, initiative, leads, sessions, new_users,
         avg_session_duration, spend, clicks, impressions
  FROM `your-project.marketing.vw_brand_f`
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
  'Brand F' AS brand,
  initiative,
  channel,
  SUM(leads)       AS leads,
  SUM(sessions)    AS sessions,
  SUM(new_users)   AS new_users,
  SUM(spend)       AS spend,
  SUM(clicks)      AS clicks,
  SUM(impressions) AS impressions,
  SAFE_DIVIDE(SUM(clicks),  SUM(impressions)) AS ctr,
  SAFE_DIVIDE(SUM(spend),   SUM(clicks))      AS cpc,
  SAFE_DIVIDE(SUM(spend),   SUM(leads))       AS cpa,
  SAFE_DIVIDE(SUM(leads),   SUM(sessions))    AS conversion_rate_sessions,
  SAFE_DIVIDE(SUM(avg_session_duration * sessions), SUM(sessions)) AS avg_session_duration,
  'NA' AS reach_daily_note
FROM base
CROSS JOIN UNNEST(['weekly','biweekly','monthly']) AS grain
GROUP BY grain, period_start, initiative, channel;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_f_rollup_weekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_f` WHERE grain = 'weekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_f_rollup_biweekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_f` WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_f_rollup_monthly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_f` WHERE grain = 'monthly';

SELECT
  initiative, channel,
  COUNT(DISTINCT report_date) AS days,
  ROUND(SUM(spend), 2)  AS spend,
  SUM(sessions)         AS sessions,
  SUM(leads)            AS leads,
  MIN(report_date) AS since_date, MAX(report_date) AS until_date
FROM `your-project.marketing.vw_brand_f`
GROUP BY ROLLUP(initiative, channel)
ORDER BY initiative NULLS LAST, channel NULLS LAST;
