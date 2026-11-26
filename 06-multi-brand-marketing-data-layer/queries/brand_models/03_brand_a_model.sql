CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_a_v3` AS
SELECT
  date,
  'dv360' AS source,
  CAST(campaign_id AS STRING) AS campaign_id,
  campaign,
  SUM(clicks)             AS clicks,
  SUM(impressions)        AS impressions,
  SUM(revenue_advertiser) AS spend
FROM `your-project.marketing.dv360_campaign_v2`
WHERE CAST(campaign_id AS STRING) IN ('DV360_CAMPAIGN_ID_2', 'DV360_CAMPAIGN_ID_1', 'DV360_CAMPAIGN_ID_3')
GROUP BY date, campaign_id, campaign;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_a_traffic_v3` AS
SELECT
  date,
  CASE
    WHEN LOWER(session_source_medium) = 'google / cpc'          THEN 'google'
    WHEN REGEXP_CONTAINS(LOWER(session_source_medium),
         r'^(meta|facebook|instagram|fb) / (cpc|cpm|cpa|paid)$') THEN 'meta'
    WHEN STARTS_WITH(LOWER(session_source_medium), 'dv360 /')   THEN 'dv360'
    ELSE 'other'
  END AS source,
  CAST(SUM(sessions) AS INT64)   AS sessions,
  CAST(SUM(newusers) AS INT64)   AS new_users,

  CAST(SUM(totalusers) AS INT64) AS total_users_daily,
  SAFE_DIVIDE(
    SUM(average_session_duration * sessions),
    SUM(sessions)
  ) AS avg_session_duration
FROM `your-project.marketing.ga4_brand_a_traffic_v2`
WHERE LOWER(session_source_medium) NOT IN (
  'tagassistant.google.com / referral',
  '(not set)',
  '(data not available)'
)
GROUP BY date, source;

CREATE OR REPLACE VIEW `your-project.marketing.rpt_brand_a_v3` AS
WITH traffic AS (
  SELECT * FROM `your-project.marketing.stg_ga4_brand_a_traffic_v3`
),
events AS (
  SELECT * FROM `your-project.marketing.stg_ga4_brand_a_events_v2`
),
meta_daily AS (
  SELECT date, 'meta' AS source,
         SUM(clicks) AS clicks, SUM(impressions) AS impressions, SUM(spend) AS spend
  FROM `your-project.marketing.stg_meta_brand_a`
  GROUP BY date
),
google_daily AS (
  SELECT date, 'google' AS source,
         SUM(clicks) AS clicks, SUM(impressions) AS impressions, SUM(spend) AS spend
  FROM `your-project.marketing.stg_google_brand_a`
  GROUP BY date
),
dv360_daily AS (
  SELECT date, 'dv360' AS source,
         SUM(clicks) AS clicks, SUM(impressions) AS impressions, SUM(spend) AS spend
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
  END AS media_data_status
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
  'brand_a_v3'    AS contract_version
FROM `your-project.marketing.rpt_brand_a_v3`;

CREATE OR REPLACE TABLE FUNCTION `your-project.marketing.tf_brand_a_weekly_orientation_v2`(
  p_week_start DATE,
  p_week_end   DATE
) AS (
  SELECT
    p_week_start AS week_start,
    p_week_end   AS week_end,

    LOWER(COALESCE(NULLIF(TRIM(session_source_medium), ''), '(not set)')) AS source_medium,

    COALESCE(NULLIF(TRIM(campaign), ''), '(not set)') AS campaign,

    COALESCE(
      NULLIF(REGEXP_EXTRACT(page_location, r'(?i)^https?://[^/]+([^?#]*)'), ''),
      '/'
    ) AS click_origin,

    CAST(COALESCE(SUM(event_count), 0) AS INT64) AS clicks

  FROM `your-project.marketing.ga4_brand_a_orientation_v3`

  WHERE date BETWEEN p_week_start AND p_week_end

    AND DATE_DIFF(p_week_end, p_week_start, DAY) = 6
    AND EXTRACT(DAYOFWEEK FROM p_week_start) = 2
    AND EXTRACT(DAYOFWEEK FROM p_week_end) = 1
    AND event_name = 'click_orientation'
    AND customevent_cta_name = 'orientation'
    AND customevent_item_id = '(not set)'
    AND customevent_association_name = '(not set)'
    AND customevent_form_id = '(not set)'

  GROUP BY week_start, week_end, source_medium, campaign, click_origin
);
