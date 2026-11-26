WITH cat AS (
  SELECT DISTINCT content, campaign_sheet, channel, campaign_platform
  FROM `your-project.marketing.dim_content_brand_b`
),
events_cte AS (
  SELECT campaign_platform, channel,
         COUNT(DISTINCT date)      AS days_with_events,
         SUM(clicks_associations)   AS associations,
         SUM(clicks_video_start)    AS video_start,
         SUM(clicks_button_a)       AS button_a_clicks,
         SUM(clicks_button_b)           AS button_b_clicks
  FROM `your-project.marketing.stg_ga4_brand_b_campaign_v3`
  WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY 1,2
),
media_cte AS (
  SELECT campaign_platform, channel,
         COUNT(DISTINCT date) AS days_with_ads,
         SUM(impression_count)     AS impression_count
  FROM `your-project.marketing.stg_media_brand_b_campaign_v3`
  WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY 1,2
)
SELECT
  c.campaign_sheet,
  c.content,
  c.channel,
  COALESCE(m.days_with_ads, 0)   AS days_with_ads,
  COALESCE(m.impression_count, 0)      AS impression_count,
  COALESCE(e.days_with_events, 0) AS days_with_events,
  e.associations,
  e.video_start,
  e.button_a_clicks,
  e.button_b_clicks,
  CASE
    WHEN COALESCE(m.days_with_ads, 0) = 0        THEN 'did not run in the period'
    WHEN COALESCE(e.days_with_events, 0) = 0      THEN 'RAN AND WAS NOT MEASURED'
    ELSE 'measured'
  END AS verdict
FROM cat c
LEFT JOIN events_cte e ON e.campaign_platform = c.campaign_platform AND e.channel = c.channel
LEFT JOIN media_cte  m ON m.campaign_platform = c.campaign_platform AND m.channel = c.channel
ORDER BY c.channel, c.campaign_sheet;

CREATE OR REPLACE VIEW `your-project.marketing.stg_media_brand_b_campaign_v3` AS
SELECT date, campaign AS campaign_platform, 'DV360' AS channel,
  SUM(revenue_advertiser) AS spend_amount, SUM(impressions) AS impression_count,
  SUM(clicks) AS click_count, CAST(NULL AS FLOAT64) AS reach_count,
  SUM(trueview_views)       AS views,
  SUM(complete_views_video) AS views_complete
FROM `your-project.marketing.dv360_campaign_v2`
WHERE campaign IN (SELECT campaign_platform FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2
UNION ALL

SELECT date, campaign, 'Google',
  SUM(spend), SUM(impressions), SUM(clicks),
  CAST(NULL AS FLOAT64), CAST(NULL AS INT64), CAST(NULL AS INT64)
FROM `your-project.marketing.google_ads_campaigns_v2`
WHERE campaign IN (SELECT campaign_platform FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_campaign_v3` AS
SELECT
  COALESCE(m.date, e.date)     AS report_date,
  d.campaign_sheet              AS campaign_name,
  d.campaign_platform,
  COALESCE(m.channel, e.channel)   AS channel,
  d.objective,
  COALESCE(m.spend_amount, 0)         AS spend_amount,
  COALESCE(m.impression_count, 0)   AS impression_count,
  COALESCE(m.click_count, 0)         AS click_count,
  m.reach_count,
  m.views,
  COALESCE(s.session_count, 0)            AS session_count,
  COALESCE(e.clicks_associations, 0)  AS clicks_associations,
  COALESCE(e.clicks_video_start, 0)   AS clicks_video_start,
  COALESCE(e.clicks_button_a, 0)      AS clicks_button_a,
  COALESCE(e.clicks_button_b, 0)          AS clicks_button_b,

  m.views_complete,
  'trueview_views'          AS base_views,

  'windsor_direct_period' AS base_reach
FROM `your-project.marketing.stg_media_brand_b_campaign_v3` m
FULL OUTER JOIN `your-project.marketing.stg_ga4_brand_b_campaign_v3` e
  USING (date, campaign_platform, channel)
LEFT JOIN `your-project.marketing.stg_sessions_brand_b_campaign_v3` s
  ON s.date = COALESCE(m.date, e.date)
 AND s.campaign_platform = COALESCE(m.campaign_platform, e.campaign_platform)
JOIN (SELECT DISTINCT campaign_platform, campaign_sheet, objective
      FROM `your-project.marketing.dim_content_brand_b`) d
  ON d.campaign_platform = COALESCE(m.campaign_platform, e.campaign_platform);

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
  SUM(clicks_button_b)         AS clicks_button_b,
  SUM(views_complete)    AS views_complete,
  ANY_VALUE(base_views)   AS base_views,
  ANY_VALUE(base_reach) AS base_reach
FROM expanded
GROUP BY grain, period_start, period_end, campaign_name, channel;

CREATE OR REPLACE TABLE FUNCTION
`your-project.marketing.tf_brand_b_campaign`(date_start DATE, date_end DATE) AS (
  SELECT
    channel,
    campaign_name,
    ANY_VALUE(objective)         AS objective,
    SUM(spend_amount)                  AS spend_amount,
    SUM(impression_count)            AS impression_count,
    SUM(click_count)                  AS click_count,
    CAST(NULL AS FLOAT64)       AS reach_count,
    SUM(views)                  AS views,
    SUM(session_count)               AS session_count,
    SUM(clicks_associations)     AS clicks_associations,
    SUM(clicks_video_start)      AS clicks_video_start,
    SUM(clicks_button_a)         AS clicks_button_a,
    SUM(clicks_button_b)             AS clicks_button_b,
    ANY_VALUE(campaign_platform) AS campaign_platform,

    SUM(views_complete)        AS views_complete,
    ANY_VALUE(base_views)       AS base_views,
    ANY_VALUE(base_reach)     AS base_reach
  FROM `your-project.marketing.vw_brand_b_campaign_v3`
  WHERE report_date BETWEEN date_start AND date_end
    AND date_end >= date_start
    AND DATE_DIFF(date_end, date_start, DAY) <= 31
  GROUP BY channel, campaign_name
  ORDER BY channel, campaign_name
);

SELECT channel, campaign_name, spend_amount, impression_count, click_count, views, views_complete,
       clicks_associations, clicks_video_start, clicks_button_a, clicks_button_b,
       base_views, base_reach
FROM `your-project.marketing.tf_brand_b_campaign`('2026-07-16','2026-07-31')
ORDER BY channel, campaign_name;
