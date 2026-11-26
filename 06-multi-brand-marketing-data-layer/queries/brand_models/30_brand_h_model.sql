SELECT
  FORMAT_DATE('%Y-%m', date)          AS month_start,
  SUM(impressions)                    AS impression_count,
  SUM(first_quartile_views_video)     AS q25,
  SUM(midpoint_views_video)           AS q50,
  SUM(third_quartile_views_video)     AS q75,
  SUM(complete_views_video)           AS q100,
  SUM(trueview_views)                 AS trueview,
  ROUND(SAFE_DIVIDE(SUM(trueview_views), SUM(impressions)) * 100, 2) AS vtr_pct
FROM `your-project.marketing.dv360_campaign_v2`
WHERE campaign = 'Brand H_Video_Podcast_2026'
GROUP BY month_start
ORDER BY month_start;

CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_h` AS
SELECT
  v.date,
  'DV360'                     AS channel,
  d.initiative,
  SUM(v.revenue_advertiser)   AS spend,
  SUM(v.spend)                AS spend_base,
  SUM(v.clicks)               AS clicks,
  SUM(v.impressions)          AS impressions,

  SUM(v.first_quartile_views_video)   AS first_quartile_views_video,
  SUM(v.midpoint_views_video)         AS midpoint_views_video,
  SUM(v.third_quartile_views_video)   AS third_quartile_views_video,
  SUM(v.complete_views_video)         AS complete_views_video,

  SUM(v.trueview_views)               AS trueview_views
FROM `your-project.marketing.dv360_campaign_v2` v
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'DV360'
 AND  d.brand    = 'Brand H'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
GROUP BY v.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.mart_kpis_brand_h` AS
SELECT
  date,
  channel,
  initiative,
  spend,
  spend_base,
  clicks,
  impressions,
  first_quartile_views_video,
  midpoint_views_video,
  third_quartile_views_video,
  complete_views_video,
  trueview_views,
  SAFE_DIVIDE(clicks, impressions)                AS ctr,
  SAFE_DIVIDE(spend,  clicks)                     AS cpc,
  SAFE_DIVIDE(spend,  impressions) * 1000         AS cpm,

  SAFE_DIVIDE(trueview_views, impressions)        AS vtr,
  SAFE_DIVIDE(spend, trueview_views)              AS cpv,

  SAFE_DIVIDE(complete_views_video, impressions)  AS rate_view_complete,
  SAFE_DIVIDE(spend, complete_views_video)        AS cost_view_complete
FROM `your-project.marketing.stg_dv360_brand_h`;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_h` AS
SELECT
  'Brand H' AS brand,

  'Therapy Area 1' AS category,
  initiative,
  date AS report_date,
  channel,
  spend, spend_base, clicks, impressions,
  first_quartile_views_video,
  midpoint_views_video,
  third_quartile_views_video,
  complete_views_video,
  trueview_views,
  ctr, cpc, cpm,
  vtr, cpv,
  rate_view_complete, cost_view_complete,

  'brand_h_v2'           AS contract_version,
  'daily_channel_initiative' AS data_grain,

  FALSE AS has_funnel,
  FALSE AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,
  FALSE AS reconcilable_in_looker,
  'raw_platform_table' AS base_reconciliation,
  'trueview_views'         AS kpi_main,
  'revenue_advertiser'     AS base_spend,

  'trueview_views'         AS base_vtr,
  'trueview_views'         AS base_cpv
FROM `your-project.marketing.mart_kpis_brand_h`;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_h` AS
WITH base AS (
  SELECT report_date, channel, initiative, spend, spend_base, clicks, impressions,
         first_quartile_views_video, midpoint_views_video,
         third_quartile_views_video, complete_views_video, trueview_views
  FROM `your-project.marketing.vw_brand_h`
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
  'Brand H' AS brand,
  initiative,
  channel,
  SUM(spend)                AS spend,
  SUM(spend_base)           AS spend_base,
  SUM(clicks)               AS clicks,
  SUM(impressions)          AS impressions,
  SUM(first_quartile_views_video)  AS first_quartile_views_video,
  SUM(midpoint_views_video)        AS midpoint_views_video,
  SUM(third_quartile_views_video)  AS third_quartile_views_video,
  SUM(complete_views_video)        AS complete_views_video,
  SUM(trueview_views)              AS trueview_views,
  SAFE_DIVIDE(SUM(clicks), SUM(impressions))                   AS ctr,
  SAFE_DIVIDE(SUM(spend),  SUM(clicks))                        AS cpc,
  SAFE_DIVIDE(SUM(spend),  SUM(impressions)) * 1000            AS cpm,
  SAFE_DIVIDE(SUM(trueview_views), SUM(impressions))           AS vtr,
  SAFE_DIVIDE(SUM(spend),  SUM(trueview_views))                AS cpv,
  SAFE_DIVIDE(SUM(complete_views_video), SUM(impressions))     AS rate_view_complete,
  SAFE_DIVIDE(SUM(spend),  SUM(complete_views_video))          AS cost_view_complete
FROM base
CROSS JOIN UNNEST(['weekly','biweekly','monthly']) AS grain
GROUP BY grain, period_start, initiative, channel;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_h_rollup_weekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_h` WHERE grain = 'weekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_h_rollup_biweekly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_h` WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_h_rollup_monthly` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_h` WHERE grain = 'monthly';

SELECT
  FORMAT_DATE('%Y-%m', report_date) AS month_start,
  initiative,
  COUNT(DISTINCT report_date)     AS days,
  ROUND(SUM(spend), 2)      AS spent,
  SUM(impressions)          AS impression_count,
  SUM(clicks)               AS click_count,
  SUM(first_quartile_views_video)  AS q25,
  SUM(midpoint_views_video)        AS q50,
  SUM(third_quartile_views_video)  AS q75,
  SUM(complete_views_video)        AS q100,
  SUM(trueview_views)              AS trueview,
  ROUND(SAFE_DIVIDE(SUM(trueview_views), SUM(impressions)) * 100, 2)       AS vtr_pct,
  ROUND(SAFE_DIVIDE(SUM(spend), SUM(trueview_views)), 4)                   AS cpv,
  ROUND(SAFE_DIVIDE(SUM(complete_views_video), SUM(impressions)) * 100, 2) AS rate_view_complete_pct
FROM `your-project.marketing.vw_brand_h`
GROUP BY month_start, initiative
ORDER BY month_start;

SELECT
  period_start,
  impressions,
  trueview_views,
  ROUND(vtr * 100, 2) AS vtr_pct,
  ROUND(cpv, 4)       AS cpv
FROM `your-project.marketing.vw_brand_h_rollup_biweekly`
WHERE period_start >= '2026-07-01'
ORDER BY period_start;
