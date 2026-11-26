CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_c_v2` AS
WITH by_utm AS (

  SELECT 'ga4_property_E' AS property, date, source, campaign,
         MAX(sessions)                 AS sessions,
         MAX(average_session_duration) AS avg_session_duration,
         SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads,
         SUM(IF(event_name = 'first_visit',           event_count, 0)) AS new_users
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY date, source, campaign
  UNION ALL
  SELECT 'ga4_property_D', date, source, campaign,
         MAX(sessions), MAX(average_session_duration),
         SUM(IF(event_name = 'registration_complete', event_count, 0)),
         SUM(IF(event_name = 'first_visit',           event_count, 0))
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
  SUM(u.leads)     AS leads,
  SUM(u.sessions)  AS sessions,
  SUM(u.new_users) AS new_users,
  SAFE_DIVIDE(SUM(u.avg_session_duration * u.sessions), SUM(u.sessions)) AS avg_session_duration
FROM by_utm u
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = u.property
 AND  m.traffic_source    = u.source
 AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(u.campaign), NFKC), r'\s+', ' ')
 AND  m.brand  = 'Brand C'
 AND  m.in_model
GROUP BY u.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_c_v2` AS
WITH ads AS (
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_meta_brand_c_v2`
  UNION ALL
  SELECT date, channel, initiative, spend, clicks, impressions, reach_daily
  FROM `your-project.marketing.stg_google_brand_c_v2`
),
ga4 AS (
  SELECT date, channel, initiative, leads, sessions, new_users, avg_session_duration
  FROM `your-project.marketing.stg_ga4_brand_c_v2`
)
SELECT
  COALESCE(a.date,  g.date)  AS date,
  COALESCE(a.channel, g.channel) AS channel,
  NULLIF(COALESCE(a.initiative, g.initiative), '(no initiative)') AS initiative,
  g.leads,
  g.sessions,
  g.new_users,
  g.avg_session_duration,
  a.spend,
  a.clicks,
  a.impressions,
  a.reach_daily,
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

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_c_v2` AS
SELECT
  'Brand C'     AS brand,
  'Therapy Area 1' AS category,
  initiative,
  date          AS report_date,
  channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions,
  reach_daily,
  ctr, cpc, cpa,
  conversion_rate_sessions,
  conversion_rate_users,

  'brand_c_v2'               AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive
FROM `your-project.marketing.mart_kpis_brand_c_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_c` AS
WITH base AS (
  SELECT
    report_date, channel, initiative,
    leads, sessions, new_users, avg_session_duration, spend, clicks, impressions
  FROM `your-project.marketing.vw_brand_c_v2`
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
  'Brand C' AS brand,
  initiative,
  channel,
  SUM(leads)       AS leads,
  SUM(sessions)    AS sessions,
  SUM(new_users)   AS new_users,
  SUM(spend)       AS spend,
  SUM(clicks)      AS clicks,
  SUM(impressions) AS impressions,

  SAFE_DIVIDE(SUM(clicks),      SUM(impressions)) AS ctr,
  SAFE_DIVIDE(SUM(spend),       SUM(clicks))      AS cpc,
  SAFE_DIVIDE(SUM(spend),       SUM(leads))       AS cpa,
  SAFE_DIVIDE(SUM(leads),       SUM(sessions))    AS conversion_rate_sessions,
  SAFE_DIVIDE(SUM(avg_session_duration * sessions), SUM(sessions)) AS avg_session_duration,
  'NA' AS reach_daily_note
FROM base
CROSS JOIN UNNEST(['weekly','biweekly','monthly']) AS grain
GROUP BY grain, period_start, initiative, channel;

SELECT
  d.brand,
  COUNT(DISTINCT f.campaign)   AS campaign_names,
  COUNT(*)                     AS n_rows,
  COUNTIF(f.reach IS NOT NULL) AS rows_with_reach,
  MIN(f.date)                  AS since_date,
  MAX(f.date)                  AS until_date
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
GROUP BY d.brand
ORDER BY d.brand;

SELECT
  channel,
  ROUND(SUM(spend), 2) AS spend,
  SUM(clicks)          AS clicks,
  SUM(sessions)        AS sessions,
  SUM(new_users)       AS new_users,
  SUM(leads)           AS leads,
  COUNT(*)             AS n_rows,
  COUNT(DISTINCT FORMAT('%t|%t|%t', report_date, channel, initiative)) AS combinations
FROM `your-project.marketing.vw_brand_c_v2`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY channel
ORDER BY channel;

CREATE OR REPLACE VIEW `your-project.marketing.stg_meta_brand_b_v3` AS
SELECT
  f.date,
  'Meta'          AS channel,
  'Brand B AON' AS initiative,
  SUM(f.spend)       AS spend,
  SUM(f.clicks)      AS clicks,
  SUM(f.impressions) AS impressions,
  SUM(f.reach)       AS reach_daily
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
WHERE d.brand = 'Brand B'
GROUP BY f.date;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_b_v3` AS
SELECT
  g.date,
  'Google'        AS channel,
  'Brand B AON' AS initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
  AND (d.id_account  = g.account_id OR g.account_id IS NULL)
WHERE d.brand = 'Brand B'
GROUP BY g.date;

CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_b_v3` AS
SELECT
  v.date,
  'DV360'         AS channel,
  'Brand B AON' AS initiative,
  SUM(v.revenue_advertiser) AS spend,
  SUM(v.clicks)             AS clicks,
  SUM(v.impressions)        AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.dv360_campaign_v2` v
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'DV360'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
WHERE d.brand = 'Brand B'
GROUP BY v.date;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_b_v3` AS
WITH ads AS (
  SELECT * FROM `your-project.marketing.stg_google_brand_b_v3`
  UNION ALL
  SELECT * FROM `your-project.marketing.stg_meta_brand_b_v3`
  UNION ALL
  SELECT * FROM `your-project.marketing.stg_dv360_brand_b_v3`
),
ga4 AS (
  SELECT * FROM `your-project.marketing.stg_ga4_brand_b_v3`
)
SELECT
  COALESCE(ads.date, ga4.date)             AS date,
  COALESCE(ads.channel, ga4.channel)           AS channel,
  COALESCE(ads.initiative, ga4.initiative) AS initiative,
  COALESCE(ga4.sessions, 0)                AS sessions,
  CAST(ga4.avg_session_duration AS BIGNUMERIC) AS avg_session_duration,

  ga4.total_users,
  ga4.new_users,
  ga4.bounce_rate,
  ga4.engagement_rate,

  COALESCE(ga4.clicks_partner_1, 0)   AS clicks_partner_1,
  COALESCE(ga4.clicks_partner_2, 0)    AS clicks_partner_2,
  COALESCE(ga4.video_1, 0)   AS video_1,
  COALESCE(ga4.video_2, 0) AS video_2,
  COALESCE(ga4.button_b, 0)      AS button_b,
  COALESCE(ga4.button_a, 0)  AS button_a,
  COALESCE(ads.spend, 0)       AS spend,
  COALESCE(ads.clicks, 0)      AS clicks,
  COALESCE(ads.impressions, 0) AS impressions,
  SAFE_DIVIDE(ads.clicks, ads.impressions) AS ctr,
  SAFE_DIVIDE(ads.spend,  ads.clicks)      AS cpc,
  SAFE_DIVIDE(
    COALESCE(ga4.clicks_partner_1, 0) + COALESCE(ga4.clicks_partner_2, 0)
    + COALESCE(ga4.video_1, 0) + COALESCE(ga4.video_2, 0)
    + COALESCE(ga4.button_b, 0) + COALESCE(ga4.button_a, 0),
    ga4.sessions
  ) AS cvr_micro_events,
  COALESCE(ads.channel, ga4.channel) IN ('Google','DV360','Meta','Direct','Organic') AS included_in_report,

  ads.reach_daily
FROM ads
FULL OUTER JOIN ga4
  ON  ads.date       = ga4.date
 AND  ads.channel      = ga4.channel
 AND  ads.initiative = ga4.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_v3` AS
SELECT
  'Brand B' AS brand,
  initiative,
  date        AS report_date,
  channel,
  sessions,
  avg_session_duration,
  total_users,
  new_users,
  bounce_rate,
  engagement_rate,
  clicks_partner_1,
  clicks_partner_2,
  video_1,
  video_2,
  button_b,
  button_a,
  spend,
  clicks,
  impressions,
  ctr,
  cpc,
  cvr_micro_events,

  reach_daily,
  'brand_b_v3'             AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  FALSE AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive
FROM `your-project.marketing.mart_kpis_brand_b_v3`
WHERE included_in_report;

SELECT
  channel,
  ROUND(SUM(spend), 2)        AS spend,
  SUM(clicks)                 AS clicks,
  SUM(impressions)            AS impressions,
  SUM(sessions)               AS sessions,
  SUM(reach_daily)           AS reach_summed_do_not_use,
  COUNTIF(reach_daily IS NOT NULL) AS days_with_reach
FROM `your-project.marketing.vw_brand_b_v3`
WHERE report_date BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY channel
ORDER BY channel;

CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_a_v3` AS
SELECT
  date,
  'dv360' AS source,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign,
  SUM(clicks)             AS clicks,
  SUM(impressions)        AS impressions,
  SUM(revenue_advertiser) AS spend,
  SUM(complete_views_video) AS complete_views_video
FROM `your-project.marketing.dv360_campaign_v2`
WHERE CAST(campaign_id AS STRING) IN ('DV360_CAMPAIGN_ID_2', 'DV360_CAMPAIGN_ID_1', 'DV360_CAMPAIGN_ID_3')
GROUP BY date, campaign_id, campaign;

CREATE OR REPLACE VIEW `your-project.marketing.rpt_brand_a_v3` AS
WITH traffic AS (
  SELECT * FROM `your-project.marketing.stg_ga4_brand_a_traffic_v3`
),
events AS (
  SELECT * FROM `your-project.marketing.stg_ga4_brand_a_events_v2`
),
meta_daily AS (
  SELECT date, 'meta' AS source,
         SUM(clicks) AS clicks, SUM(impressions) AS impressions, SUM(spend) AS spend,
         CAST(NULL AS NUMERIC) AS complete_views_video
  FROM `your-project.marketing.stg_meta_brand_a`
  GROUP BY date
),
google_daily AS (
  SELECT date, 'google' AS source,
         SUM(clicks) AS clicks, SUM(impressions) AS impressions, SUM(spend) AS spend,
         CAST(NULL AS NUMERIC) AS complete_views_video
  FROM `your-project.marketing.stg_google_brand_a`
  GROUP BY date
),
dv360_daily AS (
  SELECT date, 'dv360' AS source,
         SUM(clicks) AS clicks, SUM(impressions) AS impressions, SUM(spend) AS spend,
         SUM(complete_views_video) AS complete_views_video
  FROM `your-project.marketing.stg_dv360_brand_a_v3`
  GROUP BY date
),
media AS (
  SELECT * FROM meta_daily
  UNION ALL
  SELECT * FROM google_daily
  UNION ALL
  SELECT * FROM dv360_daily
),
keys AS (
  SELECT date, source FROM traffic
  UNION DISTINCT
  SELECT date, source FROM events
  UNION DISTINCT
  SELECT date, source FROM media
)
SELECT
  k.date,
  k.source,
  COALESCE(m.clicks, 0)      AS clicks,
  COALESCE(m.impressions, 0) AS impressions,
  COALESCE(m.spend, 0)       AS spend,
  COALESCE(t.sessions, 0)          AS sessions,
  COALESCE(t.new_users, 0)         AS new_users,
  COALESCE(t.total_users_daily, 0) AS total_users_daily,
  t.avg_session_duration,
  COALESCE(e.clicks_orientation, 0)         AS clicks_orientation,
  COALESCE(e.clicks_buttons_total, 0)       AS clicks_buttons_total,
  COALESCE(e.clicks_segment_1, 0)     AS clicks_segment_1,
  COALESCE(e.clicks_segment_2, 0) AS clicks_segment_2,
  COALESCE(e.leads, 0)                      AS leads,
  COALESCE(e.clicks_assoc_org_1, 0)     AS clicks_assoc_org_1,
  COALESCE(e.clicks_assoc_org_3, 0) AS clicks_assoc_org_3,
  COALESCE(e.clicks_assoc_org_5, 0)    AS clicks_assoc_org_5,
  COALESCE(e.clicks_assoc_org_4, 0)     AS clicks_assoc_org_4,
  COALESCE(e.clicks_assoc_org_2, 0)     AS clicks_assoc_org_2,
  CASE
    WHEN k.source IN ('google', 'meta', 'dv360') THEN 'connected'
    ELSE 'not_applicable'
  END AS media_data_status,

  m.complete_views_video
FROM keys AS k
LEFT JOIN traffic AS t USING (date, source)
LEFT JOIN events  AS e USING (date, source)
LEFT JOIN media   AS m USING (date, source);

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_a_v3` AS
SELECT
  'Brand A' AS brand,
  'Brand A' AS initiative,
  date AS report_date,
  CASE source
    WHEN 'google' THEN 'Google'
    WHEN 'meta'   THEN 'Meta'
    WHEN 'dv360'  THEN 'DV360'
    ELSE 'Others'
  END AS channel,
  sessions,
  new_users,
  total_users_daily,
  FALSE AS total_users_is_additive,
  avg_session_duration,
  leads,
  clicks_orientation,
  clicks_buttons_total,
  clicks_segment_1,
  clicks_segment_2,
  clicks_assoc_org_1,
  clicks_assoc_org_3,
  clicks_assoc_org_5,
  clicks_assoc_org_4,
  clicks_assoc_org_2,
  spend,
  clicks,
  impressions,
  SAFE_DIVIDE(clicks, impressions) AS ctr,
  SAFE_DIVIDE(spend, clicks)       AS cpc,
  media_data_status,
  'daily_source' AS data_grain,
  'brand_a_v3'    AS contract_version,

  complete_views_video,
  SAFE_DIVIDE(complete_views_video, impressions) AS vtr,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive
FROM `your-project.marketing.rpt_brand_a_v3`;

SELECT
  channel,
  ROUND(SUM(spend), 2)          AS spend,
  SUM(clicks)                   AS clicks,
  SUM(impressions)              AS impressions,
  SUM(sessions)                 AS sessions,
  SUM(leads)                    AS leads,
  SUM(complete_views_video)     AS views_complete,
  ROUND(AVG(vtr) * 100, 2)      AS vtr_pct_do_not_use
FROM `your-project.marketing.vw_brand_a_v3`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY channel
ORDER BY channel;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_brand_b_campaign_v3` AS
WITH expanded AS (
  SELECT
    grain,
    CASE grain
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                              DATE_TRUNC(report_date, MONTH),
                              DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 15 DAY))
      WHEN 'monthly'  THEN DATE_TRUNC(report_date, MONTH)
    END AS period_start,
    CASE grain
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                              DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 14 DAY),
                              LAST_DAY(report_date))
      WHEN 'monthly'  THEN LAST_DAY(report_date)
    END AS period_end,
    v.*
  FROM `your-project.marketing.vw_brand_b_campaign_v3` v
  CROSS JOIN UNNEST(['biweekly', 'monthly']) AS grain
)
SELECT
  grain, period_start, period_end, campaign_name, channel, ANY_VALUE(objective) AS objective,
  SUM(spend_amount) AS spend_amount, SUM(impression_count) AS impression_count, SUM(click_count) AS click_count,

  CAST(NULL AS FLOAT64) AS reach_count,
  SUM(views) AS views, SUM(session_count) AS session_count,
  SUM(clicks_associations) AS clicks_associations,
  SUM(clicks_video_start)  AS clicks_video_start,
  SUM(clicks_button_a)     AS clicks_button_a,
  SUM(clicks_button_b)         AS clicks_button_b
FROM expanded
GROUP BY grain, period_start, period_end, campaign_name, channel;

SELECT
  grain,
  COUNT(*)                      AS n_rows,
  COUNTIF(reach_count IS NOT NULL)  AS reach_not_null,
  ROUND(SUM(spend_amount), 2)          AS spend_amount,
  SUM(views)                    AS views,
  SUM(session_count)                 AS session_count
FROM `your-project.marketing.rollup_brand_b_campaign_v3`
GROUP BY grain
ORDER BY grain;

SELECT routine_name, routine_type, routine_definition
FROM `your-project.marketing.INFORMATION_SCHEMA.ROUTINES`
WHERE routine_name = 'tf_brand_b_campaign';

SELECT ordinal_position, field_path, data_type
FROM `your-project.marketing.INFORMATION_SCHEMA.PARAMETERS`
WHERE specific_name = 'tf_brand_b_campaign'
ORDER BY ordinal_position;
