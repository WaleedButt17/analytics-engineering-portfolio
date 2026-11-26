CREATE OR REPLACE TABLE `your-project.marketing.agent_daily`
PARTITION BY report_date
CLUSTER BY brand, channel
AS
WITH unified AS (

  SELECT
    'Brand C'             AS brand,
    category,
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    reach_daily,
    CAST(NULL AS NUMERIC) AS complete_views_video,
    sessions,
    new_users,
    total_users           AS daily_total_users,
    leads,
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64) AS cpm,
    CAST(NULL AS FLOAT64) AS vtr,
    CAST(NULL AS FLOAT64) AS cpv,
    conversion_rate_sessions,
    has_funnel,
    contract_version
  FROM `your-project.marketing.vw_brand_c_v2`

  UNION ALL

  SELECT
    'Brand D',
    category,
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    reach_daily,
    complete_views_video,
    sessions,
    new_users,
    total_users,
    CAST(NULL AS INT64),
    avg_session_duration,
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    cpm,
    vtr,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    has_funnel,
    contract_version
  FROM `your-project.marketing.vw_brand_d_v2`

  UNION ALL

  SELECT
    'Brand E',
    category,
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    reach_daily,
    CAST(NULL AS NUMERIC),
    sessions,
    new_users,
    total_users,
    leads,
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    conversion_rate_sessions,
    has_funnel,
    contract_version
  FROM `your-project.marketing.vw_brand_e_v2`

  UNION ALL

  SELECT
    'Brand A',
    CAST(NULL AS STRING),
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    CAST(NULL AS NUMERIC),
    complete_views_video,
    sessions,
    new_users,
    total_users_daily,
    leads,
    avg_session_duration,
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    vtr,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    TRUE,
    contract_version
  FROM `your-project.marketing.vw_brand_a_v3`

  UNION ALL

  SELECT
    'Brand B',
    CAST(NULL AS STRING),
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    reach_daily,
    CAST(NULL AS NUMERIC),
    sessions,
    new_users,
    total_users,
    CAST(NULL AS INT64),
    avg_session_duration,
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    TRUE,
    'brand_b_v3'
  FROM `your-project.marketing.vw_brand_b_v3`

  UNION ALL

  SELECT
    'Brand F',
    category,
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    reach_daily,
    CAST(NULL AS NUMERIC),
    sessions,
    new_users,
    CAST(NULL AS INT64),
    leads,
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    conversion_rate_sessions,
    has_funnel,
    contract_version
  FROM `your-project.marketing.vw_brand_f`

  UNION ALL

  SELECT
    'Brand G',
    category,
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    reach_daily,
    CAST(NULL AS NUMERIC),
    sessions,
    new_users,
    CAST(NULL AS INT64),
    leads,
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    conversion_rate_sessions,
    has_funnel,
    contract_version
  FROM `your-project.marketing.vw_brand_g`

  UNION ALL

  SELECT
    'Brand H',
    category,
    initiative,
    report_date,
    channel,
    spend,
    clicks,
    impressions,
    CAST(NULL AS NUMERIC),
    complete_views_video,
    CAST(NULL AS INT64),
    CAST(NULL AS INT64),
    CAST(NULL AS INT64),
    CAST(NULL AS INT64),
    CAST(NULL AS FLOAT64),
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    cpm,
    vtr,
    cpv,
    CAST(NULL AS FLOAT64),
    has_funnel,
    contract_version
  FROM `your-project.marketing.vw_brand_h`
)
SELECT
  report_date, brand, category, initiative, channel,

  CAST(spend       AS NUMERIC) AS spend,
  CAST(clicks      AS INT64)   AS clicks,
  CAST(impressions AS INT64)   AS impressions,
  CAST(reach_daily         AS NUMERIC) AS reach_daily,
  CAST(complete_views_video AS NUMERIC) AS complete_views_video,

  CAST(sessions           AS INT64) AS sessions,
  CAST(new_users          AS INT64) AS new_users,
  CAST(daily_total_users AS INT64) AS daily_total_users,
  CAST(leads              AS INT64) AS leads,
  CAST(avg_session_duration AS FLOAT64) AS avg_session_duration,

  CAST(ctr AS FLOAT64) AS ctr,
  CAST(cpc AS FLOAT64) AS cpc,
  CAST(cpa AS FLOAT64) AS cpa,
  CAST(cpm AS FLOAT64) AS cpm,
  CAST(vtr AS FLOAT64) AS vtr,

  CASE
    WHEN vtr IS NULL              THEN NULL
    WHEN brand = 'Brand H' THEN 'trueview_views'
    ELSE 'complete_views_video'
  END AS base_vtr,
  CAST(cpv AS FLOAT64) AS cpv,
  CAST(conversion_rate_sessions AS FLOAT64) AS conversion_rate_sessions,

  has_funnel,
  FALSE AS reach_is_additive,
  FALSE AS users_is_additive,
  DATE_DIFF(CURRENT_DATE('Etc/GMT+6'), report_date, DAY) <= 2
    AS data_provisional,
  'daily_channel_initiative' AS grain,
  contract_version,
  CURRENT_TIMESTAMP() AS updated_at
FROM unified;

CREATE OR REPLACE TABLE `your-project.marketing.agent_period`
CLUSTER BY brand, grain
AS

WITH unified AS (

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    new_users,
    leads,
    CAST(NULL AS NUMERIC) AS complete_views_video,
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64) AS cpm,
    CAST(NULL AS FLOAT64) AS vtr,
    CAST(NULL AS FLOAT64) AS cpv,
    conversion_rate_sessions AS rate_conversion,
    'leads / sessions'    AS base_conversion
  FROM `your-project.marketing.rollup_base_brand_c`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    new_users,
    CAST(NULL AS INT64),
    complete_views_video,
    avg_session_duration,
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    cpm,
    vtr,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS STRING)
  FROM `your-project.marketing.rollup_base_brand_d`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    new_users,
    leads,
    CAST(NULL AS NUMERIC),
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    conversion_rate_sessions,
    'leads / sessions'
  FROM `your-project.marketing.rollup_base_brand_e`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    new_users,
    leads,
    CAST(NULL AS NUMERIC),
    CAST(avg_session_duration AS BIGNUMERIC),
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    rate_conversion,
    'leads / orientation_clicks'
  FROM `your-project.marketing.rollup_base_brand_a_v3`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    CAST(NULL AS INT64),
    CAST(NULL AS INT64),
    CAST(NULL AS NUMERIC),
    avg_session_duration,
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    cvr_micro_events,
    'micro_events / sessions'
  FROM `your-project.marketing.rollup_base_brand_b_v3`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    new_users,
    leads,
    CAST(NULL AS NUMERIC),
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    conversion_rate_sessions,
    'leads / sessions'
  FROM `your-project.marketing.rollup_base_brand_f`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    sessions,
    new_users,
    leads,
    CAST(NULL AS NUMERIC),
    avg_session_duration,
    ctr,
    cpc,
    cpa,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    CAST(NULL AS FLOAT64),
    conversion_rate_sessions,
    'leads / sessions'
  FROM `your-project.marketing.rollup_base_brand_g`

  UNION ALL

  SELECT
    grain,
    period_start,
    brand,
    initiative,
    channel,
    spend,
    clicks,
    impressions,
    CAST(NULL AS INT64),
    CAST(NULL AS INT64),
    CAST(NULL AS INT64),
    complete_views_video,
    CAST(NULL AS FLOAT64),
    ctr,
    cpc,
    CAST(NULL AS FLOAT64),
    cpm,
    vtr,
    cpv,
    CAST(NULL AS FLOAT64),
    CAST(NULL AS STRING)
  FROM `your-project.marketing.rollup_base_brand_h`
)
SELECT
  grain,
  period_start,
  CASE grain
    WHEN 'weekly'   THEN DATE_ADD(period_start, INTERVAL 6 DAY)
    WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM period_start) = 1,
                            DATE_ADD(period_start, INTERVAL 14 DAY),
                            LAST_DAY(period_start))
    WHEN 'monthly'  THEN LAST_DAY(period_start)
  END AS period_end,
  brand, initiative, channel,

  CAST(spend       AS NUMERIC) AS spend,
  CAST(clicks      AS INT64)   AS clicks,
  CAST(impressions AS INT64)   AS impressions,
  CAST(sessions    AS INT64)   AS sessions,
  CAST(new_users   AS INT64)   AS new_users,
  CAST(leads       AS INT64)   AS leads,
  CAST(complete_views_video AS NUMERIC) AS complete_views_video,
  CAST(avg_session_duration AS FLOAT64) AS avg_session_duration,
  CAST(ctr AS FLOAT64) AS ctr,
  CAST(cpc AS FLOAT64) AS cpc,
  CAST(cpa AS FLOAT64) AS cpa,
  CAST(cpm AS FLOAT64) AS cpm,
  CAST(vtr AS FLOAT64) AS vtr,

  CASE
    WHEN vtr IS NULL              THEN NULL
    WHEN brand = 'Brand H' THEN 'trueview_views'
    ELSE 'complete_views_video'
  END AS base_vtr,
  CAST(cpv AS FLOAT64) AS cpv,
  CAST(rate_conversion AS FLOAT64) AS rate_conversion,
  base_conversion,

  DATE_DIFF(
    CURRENT_DATE('Etc/GMT+6'),
    CASE grain
      WHEN 'weekly'   THEN DATE_ADD(period_start, INTERVAL 6 DAY)
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM period_start) = 1,
                              DATE_ADD(period_start, INTERVAL 14 DAY),
                              LAST_DAY(period_start))
      WHEN 'monthly'  THEN LAST_DAY(period_start)
    END, DAY) <= 2 AS data_provisional,

  FALSE AS reach_is_additive,
  FALSE AS users_is_additive,
  CURRENT_TIMESTAMP() AS updated_at
FROM unified;

CREATE OR REPLACE VIEW `your-project.marketing.qc_agent_freshness` AS
WITH source_table AS (
  SELECT
    brand,
    COUNT(*)                  AS rows_table,
    ROUND(SUM(spend), 2)      AS spend_table,
    MAX(report_date)                AS last_date_table,
    MAX(updated_at)       AS updated_at
  FROM `your-project.marketing.agent_daily`
  GROUP BY brand
),
view_value AS (
  SELECT 'Brand C' AS brand, COUNT(*) AS n_rows, ROUND(SUM(spend),2) AS spend, MAX(report_date) AS last_date
  FROM `your-project.marketing.vw_brand_c_v2`
  UNION ALL
  SELECT 'Brand D', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_d_v2`
  UNION ALL
  SELECT 'Brand E', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_e_v2`
  UNION ALL
  SELECT 'Brand A', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_a_v3`
  UNION ALL
  SELECT 'Brand B', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_b_v3`
  UNION ALL
  SELECT 'Brand F', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_f`
  UNION ALL
  SELECT 'Brand G', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_g`
  UNION ALL
  SELECT 'Brand H', COUNT(*), ROUND(SUM(spend),2), MAX(report_date)
  FROM `your-project.marketing.vw_brand_h`
)
SELECT
  v.brand,
  t.rows_table, v.n_rows AS rows_view,
  t.spend_table, v.spend AS spend_view,
  ROUND(IFNULL(t.spend_table, 0) - IFNULL(v.spend, 0), 2) AS difference_spend,
  t.last_date_table, v.last_date AS last_date_view,
  t.updated_at,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), t.updated_at, HOUR) AS hours_since_refresh,
  CASE
    WHEN t.brand IS NULL                                          THEN 'BRAND ABSENT FROM TABLE'
    WHEN t.rows_table != v.n_rows                                    THEN 'ROW COUNT DIFFERS'
    WHEN ABS(IFNULL(t.spend_table,0) - IFNULL(v.spend,0)) > 0.01     THEN 'SPEND DIFFERS'
    WHEN t.last_date_table != v.last_date                      THEN 'LAST DATE DIFFERS'
    WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), t.updated_at, HOUR) > 30
                                                                     THEN 'REFRESH STOPPED'
  END AS problem
FROM view_value v
LEFT JOIN source_table t USING (brand)
WHERE t.brand IS NULL
   OR t.rows_table != v.n_rows
   OR ABS(IFNULL(t.spend_table,0) - IFNULL(v.spend,0)) > 0.01
   OR t.last_date_table != v.last_date
   OR TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), t.updated_at, HOUR) > 30;
