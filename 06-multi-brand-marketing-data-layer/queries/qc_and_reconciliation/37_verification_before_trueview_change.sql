SELECT column_name, data_type
FROM `your-project.marketing.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'dv360_campaign_v2'
ORDER BY ordinal_position;

SELECT
  account_name,
  MIN(date)                 AS first_day,
  MAX(date)                 AS last_day,
  COUNT(*)                  AS n_rows,
  COUNT(DISTINCT campaign)  AS campaign_names
FROM `your-project.marketing.dv360_campaign_v2`
GROUP BY account_name
ORDER BY n_rows DESC;

SELECT
  table_name,
  view_definition
FROM `your-project.marketing.INFORMATION_SCHEMA.VIEWS`
WHERE table_name IN (
  'stg_dv360_brand_h',
  'mart_kpis_brand_h',
  'vw_brand_h',
  'rollup_base_brand_h'
)
ORDER BY table_name;

SELECT
  FORMAT_DATE('%Y-%m', report_date) AS month_start,
  SUM(impressions)                   AS impression_count,
  SUM(complete_views_video)          AS views_100pct,
  ROUND(SUM(spend), 2)               AS spent,
  ROUND(AVG(vtr) * 100, 2)           AS vtr_daily_avg_pct,
  ROUND(SAFE_DIVIDE(SUM(complete_views_video), SUM(impressions)) * 100, 2)
                                     AS vtr_current_pct,
  ROUND(SAFE_DIVIDE(SUM(spend), SUM(complete_views_video)), 4)
                                     AS cpv_current
FROM `your-project.marketing.vw_brand_h`
GROUP BY month_start
ORDER BY month_start;
