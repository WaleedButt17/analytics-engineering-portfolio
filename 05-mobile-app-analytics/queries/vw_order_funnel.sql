CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_order_funnel` AS
WITH funnel_base AS (
  SELECT
    user_pseudo_id,
    contributor_id,
    platform,
    traffic_source_name AS campaign,
    MIN(CASE WHEN event_name = 'view_contributor_profile' THEN event_date END) AS start_date,
    MAX(CASE WHEN event_name = 'view_contributor_profile' THEN 1 ELSE 0 END) AS viewed_profile,
    MAX(CASE WHEN event_name = 'request_video_click' THEN 1 ELSE 0 END) AS started_request,
    MAX(CASE WHEN event_name = 'request_video_submit' THEN 1 ELSE 0 END) AS submitted_request,
    MAX(CASE WHEN event_name = 'payment_success' THEN 1 ELSE 0 END) AS payment_completed,
    MAX(CASE WHEN event_name = 'order_completed' THEN 1 ELSE 0 END) AS order_completed
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE contributor_id IS NOT NULL
  GROUP BY user_pseudo_id, contributor_id, platform, campaign
),

funnel_counts AS (
  SELECT
    start_date, platform, campaign,
    COUNTIF(viewed_profile = 1) AS stage1_users,
    COUNTIF(viewed_profile = 1 AND started_request = 1) AS stage2_users,
    COUNTIF(viewed_profile = 1 AND started_request = 1 AND submitted_request = 1) AS stage3_users,
    COUNTIF(viewed_profile = 1 AND started_request = 1 AND submitted_request = 1 AND payment_completed = 1) AS stage4_users,
    COUNTIF(viewed_profile = 1 AND started_request = 1 AND submitted_request = 1 AND payment_completed = 1 AND order_completed = 1) AS stage5_users
  FROM funnel_base
  GROUP BY start_date, platform, campaign
)

SELECT PARSE_DATE('%Y%m%d', start_date) AS event_date, platform, campaign,
  '1. Profile View' AS funnel_stage, stage1_users AS total_users, stage1_users AS prev_stage_users,
  ROUND(SAFE_DIVIDE(stage1_users, stage1_users) * 100, 2) AS stage_pct
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '2. Start Request', stage2_users, stage1_users,
  ROUND(SAFE_DIVIDE(stage2_users, stage1_users) * 100, 2)
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '3. Submit Request', stage3_users, stage2_users,
  ROUND(SAFE_DIVIDE(stage3_users, stage2_users) * 100, 2)
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '4. Payment Completed', stage4_users, stage3_users,
  ROUND(SAFE_DIVIDE(stage4_users, stage3_users) * 100, 2)
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '5. Order Completed', stage5_users, stage4_users,
  ROUND(COALESCE(SAFE_DIVIDE(stage5_users, stage4_users) * 100, 0), 2)
FROM funnel_counts;
