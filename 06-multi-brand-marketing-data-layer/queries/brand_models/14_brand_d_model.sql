CREATE OR REPLACE VIEW `your-project.marketing.stg_meta_brand_d_v2` AS
SELECT
  f.date,
  'Meta'             AS channel,
  d.initiative,
  SUM(f.spend)       AS spend,
  SUM(f.clicks)      AS clicks,
  SUM(f.impressions) AS impressions,
  SUM(f.reach)       AS reach_daily,
  CAST(NULL AS BIGNUMERIC) AS complete_views_video
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.brand    = 'Brand D'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
GROUP BY f.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_d` AS
SELECT
  v.date,
  'DV360'                   AS channel,
  d.initiative,
  SUM(v.revenue_advertiser) AS spend,
  SUM(v.clicks)             AS clicks,
  SUM(v.impressions)        AS impressions,
  CAST(NULL AS BIGNUMERIC)  AS reach_daily,
  SUM(v.complete_views_video) AS complete_views_video
FROM `your-project.marketing.dv360_campaign_v2` v
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'DV360'
 AND  d.brand    = 'Brand D'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
GROUP BY v.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_d_v2` AS
WITH by_utm AS (

  SELECT date, source, campaign,
         MAX(sessions)                  AS sessions,
         MAX(average_session_duration)  AS avg_session_duration,
         SUM(IF(event_name = 'first_visit', event_count, 0)) AS new_users,
         SUM(IF(event_name = 'scroll',      event_count, 0)) AS scroll_events
  FROM `your-project.marketing.ga4_brand_d`
  GROUP BY date, source, campaign
)
SELECT
  u.date,
  CASE u.source
    WHEN 'meta'   THEN 'Meta'
    WHEN 'google' THEN 'Google'
    WHEN 'dv360'  THEN 'DV360'
  END AS channel,
  m.initiative,
  SUM(u.sessions)      AS sessions,
  SUM(u.new_users)     AS new_users,
  SUM(u.scroll_events) AS scroll_events,
  SAFE_DIVIDE(SUM(u.avg_session_duration * u.sessions), SUM(u.sessions)) AS avg_session_duration
FROM by_utm u
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = 'ga4_property_D'
 AND  m.traffic_source    = u.source
 AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(u.campaign), NFKC), r'\s+', ' ')
 AND  m.brand  = 'Brand D'
 AND  m.in_model
GROUP BY u.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_d_v2` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily, complete_views_video
  FROM `your-project.marketing.stg_meta_brand_d_v2`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily, complete_views_video
  FROM `your-project.marketing.stg_dv360_brand_d`
),
ga4 AS (
  SELECT date, channel, initiative, sessions, new_users, scroll_events, avg_session_duration
  FROM `your-project.marketing.stg_ga4_brand_d_v2`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  COALESCE(a.initiative, g.initiative) AS initiative,
  g.sessions,
  g.new_users,
  g.scroll_events,
  g.avg_session_duration,
  a.spend,
  a.clicks,
  a.impressions,
  a.reach_daily,
  a.complete_views_video,
  SAFE_DIVIDE(a.clicks, a.impressions)              AS ctr,
  SAFE_DIVIDE(a.spend,  a.clicks)                   AS cpc,
  SAFE_DIVIDE(a.spend,  a.impressions) * 1000       AS cpm,
  SAFE_DIVIDE(a.complete_views_video, a.impressions) AS vtr
FROM ads a
FULL OUTER JOIN ga4 g
  ON  a.date  = g.date
 AND  a.channel = g.channel
 AND  COALESCE(a.initiative, '(no initiative)')
    = COALESCE(g.initiative, '(no initiative)');

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
  FALSE AS total_users_is_additive
FROM `your-project.marketing.mart_kpis_brand_d_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_d` AS
WITH base AS (
  SELECT report_date, channel, initiative, sessions, new_users, scroll_events,
         avg_session_duration, spend, clicks, impressions, complete_views_video
  FROM `your-project.marketing.vw_brand_d_v2`
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
  'Brand D' AS brand,
  initiative,
  channel,
  SUM(sessions)             AS sessions,
  SUM(new_users)            AS new_users,
  SUM(scroll_events)        AS scroll_events,
  SUM(spend)                AS spend,
  SUM(clicks)               AS clicks,
  SUM(impressions)          AS impressions,
  SUM(complete_views_video) AS complete_views_video,
  SAFE_DIVIDE(SUM(clicks),  SUM(impressions))            AS ctr,
  SAFE_DIVIDE(SUM(spend),   SUM(clicks))                 AS cpc,
  SAFE_DIVIDE(SUM(spend),   SUM(impressions)) * 1000     AS cpm,
  SAFE_DIVIDE(SUM(complete_views_video), SUM(impressions)) AS vtr,
  SAFE_DIVIDE(SUM(avg_session_duration * sessions), SUM(sessions)) AS avg_session_duration,
  'NA' AS reach_daily_note
FROM base
CROSS JOIN UNNEST(['weekly','biweekly','monthly']) AS grain
GROUP BY grain, period_start, initiative, channel;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_d_rollup_weekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_d`
WHERE grain = 'weekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_d_rollup_biweekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_d`
WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_d_rollup_v2` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_d`
WHERE grain = 'monthly';
