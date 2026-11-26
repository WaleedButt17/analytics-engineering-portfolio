CREATE OR REPLACE TABLE `your-project.marketing.dim_episode_brand_h` AS
SELECT * FROM UNNEST([
  STRUCT('Chapter 1 Brand H' AS trueview_ad, 'Episode 1' AS episode, 1 AS sort_order),
  STRUCT('Chapter 2',              'Episode 2', 2),
  STRUCT('Chapter 3',              'Episode 3', 3),
  STRUCT('BH_Chapter 04',          'Episode 4', 4)
]);

CREATE OR REPLACE VIEW `your-project.marketing.stg_dv360_brand_h_episode` AS
SELECT
  t.date,
  d.episode,
  d.sort_order,
  SUM(t.impressions)     AS impressions,
  SUM(t.trueview_views)  AS trueview_views
FROM `your-project.marketing.dv360_trueview_ad` t
JOIN `your-project.marketing.dim_episode_brand_h` d
  ON REGEXP_REPLACE(NORMALIZE(TRIM(t.trueview_ad), NFKC), r'\s+', ' ') = d.trueview_ad
GROUP BY t.date, d.episode, d.sort_order;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_h_episode` AS
SELECT
  grain,
  CASE grain
    WHEN 'weekly'   THEN DATE_TRUNC(date, ISOWEEK)
    WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM date) <= 15,
                            DATE_TRUNC(date, MONTH),
                            DATE_ADD(DATE_TRUNC(date, MONTH), INTERVAL 15 DAY))
    WHEN 'monthly'  THEN DATE_TRUNC(date, MONTH)
  END AS period_start,
  episode,
  sort_order,
  SUM(impressions)    AS impressions,
  SUM(trueview_views) AS trueview_views
FROM `your-project.marketing.stg_dv360_brand_h_episode`
CROSS JOIN UNNEST(['weekly','biweekly','monthly']) AS grain
GROUP BY grain, period_start, episode, sort_order;

CREATE OR REPLACE TABLE FUNCTION
`your-project.marketing.tf_brand_h_episodes`(start_date DATE, end_date DATE) AS (
  SELECT
    episode,
    sort_order,
    SUM(impressions)     AS impression_count,
    SUM(trueview_views)  AS views
  FROM `your-project.marketing.stg_dv360_brand_h_episode`
  WHERE date BETWEEN start_date AND end_date
  GROUP BY episode, sort_order
  HAVING SUM(impressions) > 0
  ORDER BY sort_order
);

CREATE OR REPLACE TABLE FUNCTION
`your-project.marketing.tf_brand_h_campaign`(start_date DATE, end_date DATE) AS (
  SELECT
    'Brand H Video In-stream' AS campaign_name,
    ANY_VALUE(initiative)         AS initiative,
    SUM(spend)                    AS budget_spent,
    SUM(impressions)              AS impression_count,
    SUM(clicks)                   AS click_count,
    SUM(first_quartile_views_video)  AS q25,
    SUM(midpoint_views_video)        AS q50,
    SUM(third_quartile_views_video)  AS q75,
    SUM(complete_views_video)        AS q100,
    SUM(trueview_views)              AS trueview,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000   AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(trueview_views))       AS cpv,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))               AS cpc,
    SAFE_DIVIDE(SUM(trueview_views), SUM(impressions)) AS vtr
  FROM `your-project.marketing.vw_brand_h`
  WHERE report_date BETWEEN start_date AND end_date
);

CREATE OR REPLACE VIEW `your-project.marketing.qc_episode_orphan` AS
SELECT
  t.trueview_ad,
  MIN(t.date)            AS first_day,
  MAX(t.date)            AS last_day,
  SUM(t.impressions)     AS impression_count,
  SUM(t.trueview_views)  AS views
FROM `your-project.marketing.dv360_trueview_ad` t
LEFT JOIN `your-project.marketing.dim_episode_brand_h` d
  ON REGEXP_REPLACE(NORMALIZE(TRIM(t.trueview_ad), NFKC), r'\s+', ' ') = d.trueview_ad
WHERE d.trueview_ad IS NULL

  AND t.trueview_ad NOT IN ('Demand Gen Video Audience 1',
                            'LAL- Audience 2',
                            'LAL-Audience 3')
GROUP BY t.trueview_ad;

SELECT '1-15 Jul' AS period, * FROM `your-project.marketing.tf_brand_h_episodes`('2026-07-01','2026-07-15')
UNION ALL SELECT '16-31 Jul', * FROM `your-project.marketing.tf_brand_h_episodes`('2026-07-16','2026-07-31')
UNION ALL SELECT '1-15 Aug', * FROM `your-project.marketing.tf_brand_h_episodes`('2026-08-01','2026-08-15')
ORDER BY period, sort_order;

SELECT
  p.period,
  c.impression_count AS ep_impressions,
  c.views       AS ep_views,
  m.impression_count AS camp_impressions,
  m.trueview    AS camp_trueview,
  c.impression_count - m.impression_count AS diff_impressions,
  c.views       - m.trueview    AS diff_views
FROM UNNEST([
  STRUCT('1-15 Jul'  AS period, DATE '2026-07-01' AS i, DATE '2026-07-15' AS f),
  STRUCT('16-31 Jul', DATE '2026-07-16', DATE '2026-07-31'),
  STRUCT('1-15 Aug',  DATE '2026-08-01', DATE '2026-08-15')
]) p,
UNNEST([(SELECT AS STRUCT SUM(impression_count) AS impression_count, SUM(views) AS views
         FROM `your-project.marketing.tf_brand_h_episodes`(p.i, p.f))]) c,
UNNEST([(SELECT AS STRUCT impression_count, trueview
         FROM `your-project.marketing.tf_brand_h_campaign`(p.i, p.f))]) m
ORDER BY p.period;
