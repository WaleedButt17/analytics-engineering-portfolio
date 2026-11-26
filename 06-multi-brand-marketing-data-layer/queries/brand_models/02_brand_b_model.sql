CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_b_v3` AS
SELECT
  g.date,
  'Google'        AS channel,
  'Brand B AON' AS initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions
FROM `your-project.marketing.google_ads_campaigns` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
  AND (d.id_account  = g.account_id OR g.account_id IS NULL)
WHERE d.brand = 'Brand B'
GROUP BY g.date;

CREATE OR REPLACE VIEW `your-project.marketing.stg_meta_brand_b_v3` AS
SELECT
  f.date,
  'Meta'          AS channel,
  'Brand B AON' AS initiative,
  SUM(f.spend)       AS spend,
  SUM(f.clicks)      AS clicks,
  SUM(f.impressions) AS impressions
FROM `your-project.marketing.facebook_ads_campaigns` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
  AND (d.id_account  = f.account_id OR f.account_id IS NULL)
WHERE d.brand = 'Brand B'
GROUP BY f.date;

CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_b_v3` AS
SELECT
  v.date,
  'DV360'         AS channel,
  'Brand B AON' AS initiative,
  SUM(v.revenue_advertiser) AS spend,
  SUM(v.clicks)             AS clicks,
  SUM(v.impressions)        AS impressions
FROM `your-project.marketing.dv360_campaign_v2` v
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'DV360'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
WHERE d.brand = 'Brand B'
GROUP BY v.date;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_b_v3` AS
WITH traffic_base AS (
  SELECT
    date,
    CASE
      WHEN STARTS_WITH(LOWER(session_source_medium), 'dv360 /')            THEN 'DV360'
      WHEN LOWER(session_source_medium) = 'google / cpc'                   THEN 'Google'
      WHEN REGEXP_CONTAINS(LOWER(session_source_medium),
           r'^(meta|facebook|instagram|fb) / (cpc|cpm|cpa|paid)$')         THEN 'Meta'
      WHEN LOWER(session_source_medium) = '(direct) / (none)'              THEN 'Direct'
      WHEN LOWER(session_source_medium) LIKE '%organic%'                   THEN 'Organic'
      ELSE 'Other'
    END AS channel,
    sessions,
    average_session_duration,
    totalusers,
    newusers,
    bounce_rate,
    engagement_rate
  FROM `your-project.marketing.ga4_brand_b_traffic_v2`
  WHERE LOWER(session_source_medium) != 'tagassistant.google.com / referral'
),

traffic AS (
  SELECT
    date,
    channel,
    SUM(sessions) AS sessions,

    SAFE_DIVIDE(
      SUM(CAST(average_session_duration AS FLOAT64) * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS avg_session_duration,
    SUM(SAFE_CAST(totalusers AS NUMERIC)) AS total_users,
    SUM(SAFE_CAST(newusers   AS NUMERIC)) AS new_users,
    SAFE_DIVIDE(
      SUM(SAFE_CAST(bounce_rate AS FLOAT64) * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS bounce_rate,
    SAFE_DIVIDE(
      SUM(SAFE_CAST(engagement_rate AS FLOAT64) * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS engagement_rate
  FROM traffic_base
  GROUP BY date, channel
),

events_base AS (
  SELECT
    date,
    CASE
      WHEN STARTS_WITH(LOWER(session_source_medium), 'dv360 /')            THEN 'DV360'
      WHEN LOWER(session_source_medium) = 'google / cpc'                   THEN 'Google'
      WHEN REGEXP_CONTAINS(LOWER(session_source_medium),
           r'^(meta|facebook|instagram|fb) / (cpc|cpm|cpa|paid)$')         THEN 'Meta'
      WHEN LOWER(session_source_medium) = '(direct) / (none)'              THEN 'Direct'
      WHEN LOWER(session_source_medium) LIKE '%organic%'                   THEN 'Organic'
      ELSE 'Other'
    END AS channel,
    event_name, event_count,
    customevent_video_title, customevent_video_action,
    customevent_button_label, customevent_association_url
  FROM `your-project.marketing.ga4_brand_b_events_v2`
  WHERE LOWER(session_source_medium) != 'tagassistant.google.com / referral'
),

events AS (
  SELECT
    date, channel,
    SUM(IF(event_name = 'click_association'
       AND LOWER(customevent_association_url) LIKE '%partner-org-1.example%',       event_count, 0)) AS clicks_partner_1,
    SUM(IF(event_name = 'click_association'
       AND LOWER(customevent_association_url) LIKE '%partner-org-2.example%', event_count, 0)) AS clicks_partner_2,
    SUM(IF(event_name = 'video_engagement' AND customevent_video_action = 'play'
       AND customevent_video_title = 'PARTNER VIDEO 1',             event_count, 0)) AS video_1,
    SUM(IF(event_name = 'video_engagement' AND customevent_video_action = 'play'
       AND customevent_video_title = 'VIDEOPARTNER_FAMILY_2',          event_count, 0)) AS video_2,
    SUM(IF(event_name = 'click_home_buttons'
       AND customevent_button_label = 'Button B',                        event_count, 0)) AS button_b,
    SUM(IF(event_name = 'click_home_buttons'
       AND customevent_button_label = 'Button A',               event_count, 0)) AS button_a
  FROM events_base
  GROUP BY date, channel
)

SELECT
  COALESCE(traffic.date,  events.date)  AS date,
  COALESCE(traffic.channel, events.channel) AS channel,
  'Brand B AON' AS initiative,
  COALESCE(traffic.sessions, 0)       AS sessions,
  traffic.avg_session_duration,
  traffic.total_users,
  traffic.new_users,
  traffic.bounce_rate,
  traffic.engagement_rate,
  COALESCE(events.clicks_partner_1, 0)   AS clicks_partner_1,
  COALESCE(events.clicks_partner_2, 0)    AS clicks_partner_2,
  COALESCE(events.video_1, 0)   AS video_1,
  COALESCE(events.video_2, 0) AS video_2,
  COALESCE(events.button_b, 0)      AS button_b,
  COALESCE(events.button_a, 0)  AS button_a,

  COALESCE(traffic.channel, events.channel) IN ('Google','DV360','Meta','Direct','Organic') AS included_in_report

FROM traffic
FULL OUTER JOIN events USING (date, channel);

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
  COALESCE(ads.channel, ga4.channel) IN ('Google','DV360','Meta','Direct','Organic') AS included_in_report
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
  cvr_micro_events
FROM `your-project.marketing.mart_kpis_brand_b_v3`
WHERE included_in_report;
