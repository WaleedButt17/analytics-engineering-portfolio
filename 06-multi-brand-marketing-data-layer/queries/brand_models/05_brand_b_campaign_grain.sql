CREATE OR REPLACE VIEW `your-project.marketing.dim_content_brand_b` AS
SELECT * FROM UNNEST([
  STRUCT('native'    AS content, 'Native Ads Brand B 2026'  AS campaign_name, 'DV360'  AS channel),
  STRUCT('demand',        'Demand Gen 2026 Brand B',   'DV360'),
  STRUCT('outstream',     'Video Outstream Brand B',   'DV360'),
  STRUCT('oustream',      'Video Outstream Brand B',   'DV360'),
  STRUCT('(not set)',     'PMax - Therapy Area 3 2026',      'Google')
]);

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_b_campaign_v3` AS
WITH base AS (
  SELECT
    date,
    session_source_medium,
    CASE
      WHEN STARTS_WITH(LOWER(session_source_medium), 'dv360 /') THEN 'DV360'
      WHEN LOWER(session_source_medium) = 'google / cpc'        THEN 'Google'
      WHEN REGEXP_CONTAINS(LOWER(session_source_medium),
           r'^(meta|facebook|instagram|fb) / (cpc|cpm|cpa|paid)$') THEN 'Meta'
      ELSE 'Other'
    END AS channel,
    session_manual_ad_content AS content,
    event_name,
    customevent_video_action,
    customevent_button_label,
    event_count
  FROM `your-project.marketing.ga4_brand_b_events_content`
  WHERE LOWER(session_source_medium) != 'tagassistant.google.com / referral'
)
SELECT
  b.date,
  d.campaign_name,
  d.channel,
  SUM(IF(b.event_name = 'click_association', b.event_count, 0))    AS clicks_associations,
  SUM(IF(b.event_name = 'video_engagement', b.event_count, 0))    AS clicks_video_start,
  SUM(IF(b.event_name = 'click_home_buttons'
     AND b.customevent_button_label = 'Button A',
         b.event_count, 0))                                        AS clicks_button_a,
  SUM(IF(b.event_name = 'click_home_buttons'
     AND b.customevent_button_label = 'Button B',
         b.event_count, 0))                                        AS clicks_button_b
FROM base b
JOIN `your-project.marketing.dim_content_brand_b` d
  ON  d.content = b.content
 AND  d.channel     = b.channel
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW `your-project.marketing.stg_media_brand_b_campaign_v3` AS

SELECT date, campaign AS campaign_platform, 'DV360' AS channel,
  SUM(revenue_advertiser) AS spend_amount, SUM(impressions) AS impression_count,
  SUM(clicks) AS click_count, CAST(NULL AS FLOAT64) AS reach_count,
  SUM(complete_views_video) AS views
FROM `your-project.marketing.dv360_campaign_v2`
WHERE campaign IN (SELECT campaign_platform FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2
UNION ALL
SELECT date, campaign, 'Google',
  SUM(spend), SUM(impressions), SUM(clicks),
  CAST(NULL AS FLOAT64), CAST(NULL AS INT64)
FROM `your-project.marketing.google_ads_campaigns_v2`
WHERE campaign IN (SELECT campaign_platform FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2;

CREATE OR REPLACE VIEW `your-project.marketing.stg_sessions_brand_b_campaign_v3` AS
SELECT
  b.date,
  d.campaign_name,
  SUM(IF(b.event_name = 'session_start', b.event_count, 0)) AS session_count
FROM (
  SELECT date, session_manual_ad_content AS content, event_name, event_count,
    CASE
      WHEN STARTS_WITH(LOWER(session_source_medium), 'dv360 /') THEN 'DV360'
      WHEN LOWER(session_source_medium) = 'google / cpc'        THEN 'Google'
      ELSE 'Other'
    END AS channel
  FROM `your-project.marketing.ga4_brand_b_events_content`
) b
JOIN `your-project.marketing.dim_content_brand_b` d
  ON d.content = b.content AND d.channel = b.channel
GROUP BY 1, 2;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_campaign_v3` AS
SELECT
  COALESCE(m.date, e.date)       AS report_date,
  COALESCE(m.campaign_name, e.campaign_name) AS campaign_name,
  COALESCE(m.channel, e.channel)     AS channel,
  c.objective,
  COALESCE(m.spend_amount, 0)           AS spend_amount,
  COALESCE(m.impression_count, 0)     AS impression_count,
  COALESCE(m.click_count, 0)           AS click_count,
  m.reach_count,
  m.views,
  COALESCE(s.session_count, 0)            AS session_count,
  COALESCE(e.clicks_associations, 0)  AS clicks_associations,
  COALESCE(e.clicks_video_start, 0)   AS clicks_video_start,
  COALESCE(e.clicks_button_a, 0)      AS clicks_button_a,
  COALESCE(e.clicks_button_b, 0)          AS clicks_button_b
FROM `your-project.marketing.stg_media_brand_b_campaign_v3` m
FULL OUTER JOIN `your-project.marketing.stg_ga4_brand_b_campaign_v3` e
  USING (date, campaign_name, channel)
LEFT JOIN `your-project.marketing.stg_sessions_brand_b_campaign_v3` s
  ON s.date = COALESCE(m.date, e.date) AND s.campaign_name = COALESCE(m.campaign_name, e.campaign_name)
LEFT JOIN `your-project.marketing.dim_campaign` c
  ON c.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(COALESCE(m.campaign_name, e.campaign_name)), NFKC), r'\s+', ' ');

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
  SUM(reach_count) AS reach_count, SUM(views) AS views, SUM(session_count) AS session_count,
  SUM(clicks_associations) AS clicks_associations,
  SUM(clicks_video_start)  AS clicks_video_start,
  SUM(clicks_button_a)     AS clicks_button_a,
  SUM(clicks_button_b)         AS clicks_button_b
FROM expanded
GROUP BY grain, period_start, period_end, campaign_name, channel;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_campaign_biweekly_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_brand_b_campaign_v3` WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_campaign_monthly_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_brand_b_campaign_v3` WHERE grain = 'monthly';

CREATE OR REPLACE TABLE FUNCTION `your-project.marketing.tf_brand_b_campaign`(
  date_start DATE, date_end DATE
) AS
SELECT
  channel,
  campaign_name,
  ANY_VALUE(objective)         AS objective,
  date_start                AS period_start,
  date_end                   AS period_end,
  SUM(spend_amount)                  AS spend_amount,
  SUM(impression_count)            AS impression_count,
  SUM(click_count)                  AS click_count,
  SUM(reach_count)                AS reach_count,
  SUM(views)                  AS views,
  SUM(session_count)               AS session_count,
  SUM(clicks_associations)     AS clicks_associations,
  SUM(clicks_video_start)      AS clicks_video_start,
  SUM(clicks_button_a)         AS clicks_button_a,
  SUM(clicks_button_b)             AS clicks_button_b
FROM `your-project.marketing.vw_brand_b_campaign_v3`
WHERE report_date BETWEEN date_start AND date_end
  AND date_end >= date_start
  AND DATE_DIFF(date_end, date_start, DAY) <= 31
GROUP BY channel, campaign_name
ORDER BY channel, campaign_name;

CREATE OR REPLACE TABLE FUNCTION `your-project.marketing.tf_brand_b_micro_events`(
  date_start DATE, date_end DATE
) AS
SELECT
  campaign_name,
  SUM(clicks_associations) AS associations,
  SUM(clicks_video_start)  AS video_start,
  SUM(clicks_button_a)     AS button_a_clicks,
  SUM(clicks_button_b)         AS button_b_clicks
FROM `your-project.marketing.vw_brand_b_campaign_v3`
WHERE report_date BETWEEN date_start AND date_end
  AND date_end >= date_start
GROUP BY campaign_name
ORDER BY campaign_name;
