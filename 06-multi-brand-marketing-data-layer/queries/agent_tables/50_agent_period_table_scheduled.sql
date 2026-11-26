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
  brand = 'Brand G' AS brand_historical,
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
