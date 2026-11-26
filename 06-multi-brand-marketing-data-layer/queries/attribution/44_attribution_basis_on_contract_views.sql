CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_c_v2` AS
SELECT
  'Brand C' AS brand,
  'Therapy Area 1' AS category,
  initiative,
  date AS report_date,
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
  FALSE AS total_users_is_additive,
  total_users,
  total_users_bound_upper,
  bounce_rate,
  engagement_rate,
  'session' AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_c_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_e_v2` AS
SELECT
  'Brand E' AS brand,
  CAST(NULL AS STRING) AS category,
  initiative,
  date AS report_date,
  channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions,
  reach_daily,
  ctr, cpc, cpa,
  conversion_rate_sessions,
  conversion_rate_users,
  'brand_e_v2'           AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,
  total_users,
  total_users_bound_upper,
  bounce_rate,
  engagement_rate,
  'session' AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_e_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_d_v2` AS
SELECT
  'Brand D' AS brand,
  CAST(NULL AS STRING) AS category,
  initiative,
  date AS report_date,
  channel,
  sessions, new_users, scroll_events, avg_session_duration,
  spend, clicks, impressions,
  reach_daily, complete_views_video,
  ctr, cpc, cpm, vtr,
  'brand_d_v2'                AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  FALSE AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,
  total_users,
  total_users_bound_upper,
  bounce_rate,
  engagement_rate,
  'session' AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_d_v2`;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_f` AS
SELECT
  'Brand F' AS brand,
  'Therapy Area 2'  AS category,
  initiative, date AS report_date, channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions, reach_daily,
  ctr, cpc, cpa, conversion_rate_sessions,
  'brand_f'             AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,
  FALSE AS reconcilable_in_looker,
  'raw_platform_table' AS base_reconciliation,
  total_users, total_users_bound_upper, bounce_rate, engagement_rate,
  'session' AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_f`;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_g` AS
SELECT
  'Brand G'    AS brand,
  'Therapy Area 1' AS category,
  initiative, date AS report_date, channel,
  leads, sessions, new_users, avg_session_duration,
  spend, clicks, impressions, reach_daily,
  ctr, cpc, cpa, conversion_rate_sessions,
  'brand_g'                 AS contract_version,
  'daily_channel_initiative' AS data_grain,
  TRUE  AS has_funnel,
  TRUE  AS has_leads,
  FALSE AS reach_is_additive,
  FALSE AS total_users_is_additive,
  FALSE AS reconcilable_in_looker,
  'raw_platform_table' AS base_reconciliation,
  TRUE  AS is_historical,
  DATE '2025-12-12' AS last_day_active,
  total_users, total_users_bound_upper, bounce_rate, engagement_rate,
  'session' AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_g`;

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
  FALSE AS reach_is_additive,
  'complete_views_video' AS base_vtr,
  'session'               AS base_attribution
FROM `your-project.marketing.rpt_brand_a_v3`;

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
  FALSE AS total_users_is_additive,
  'session' AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_b_v3`
WHERE included_in_report;

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
  'trueview_views'         AS base_cpv,
  CAST(NULL AS STRING)     AS base_attribution
FROM `your-project.marketing.mart_kpis_brand_h`;
