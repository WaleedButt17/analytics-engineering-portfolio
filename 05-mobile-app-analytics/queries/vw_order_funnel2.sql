CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_order_funnel2` AS
WITH stage1 AS (
  SELECT
    user_pseudo_id, contributor_id, platform,
    traffic_source_name AS campaign,
    MIN(event_date) AS start_date,
    COUNTIF(event_name = 'view_contributor_profile') AS events
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'view_contributor_profile'
    AND contributor_id IS NOT NULL
  GROUP BY user_pseudo_id, contributor_id, platform, campaign
),
stage2 AS (
  SELECT
    user_pseudo_id, contributor_id,
    COUNTIF(event_name = 'request_video_click') AS events
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'request_video_click'
    AND contributor_id IS NOT NULL
  GROUP BY user_pseudo_id, contributor_id
),
stage3 AS (
  SELECT
    user_pseudo_id, contributor_id, order_id,
    COUNTIF(event_name = 'request_video_submit') AS events
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'request_video_submit'
    AND contributor_id IS NOT NULL
    AND order_id IS NOT NULL
  GROUP BY user_pseudo_id, contributor_id, order_id
),
stage4 AS (
  SELECT order_id,
    COUNTIF(event_name = 'payment_success') AS events
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'payment_success' AND order_id IS NOT NULL
  GROUP BY order_id
),
stage5 AS (
  SELECT order_id,
    COUNTIF(event_name = 'order_completed') AS events
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'order_completed' AND order_id IS NOT NULL
  GROUP BY order_id
),
funnel_base AS (
  SELECT
    s1.start_date, s1.platform, s1.campaign,
    s1.events AS stage1_events, s2.events AS stage2_events,
    s3.events AS stage3_events, s4.events AS stage4_events, s5.events AS stage5_events
  FROM stage1 s1
  LEFT JOIN stage2 s2 ON s1.user_pseudo_id = s2.user_pseudo_id AND s1.contributor_id = s2.contributor_id
  LEFT JOIN stage3 s3 ON s1.user_pseudo_id = s3.user_pseudo_id AND s1.contributor_id = s3.contributor_id
  LEFT JOIN stage4 s4 ON s3.order_id = s4.order_id
  LEFT JOIN stage5 s5 ON s3.order_id = s5.order_id
),
funnel_counts AS (
  SELECT
    start_date, platform, campaign,
    SUM(stage1_events) AS stage1_events, SUM(stage2_events) AS stage2_events,
    SUM(stage3_events) AS stage3_events, SUM(stage4_events) AS stage4_events,
    SUM(stage5_events) AS stage5_events
  FROM funnel_base
  GROUP BY start_date, platform, campaign
)

SELECT PARSE_DATE('%Y%m%d', start_date) AS event_date, platform, campaign,
  '1. Profile View' AS funnel_stage,
  stage1_events AS total_events, stage1_events AS prev_stage_events, 100.00 AS stage_pct
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '2. Start Request', stage2_events, stage1_events,
  ROUND(SAFE_DIVIDE(stage2_events, stage1_events) * 100, 2)
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '3. Submit Request', stage3_events, stage2_events,
  ROUND(SAFE_DIVIDE(stage3_events, stage2_events) * 100, 2)
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '4. Payment Completed', stage4_events, stage3_events,
  ROUND(SAFE_DIVIDE(stage4_events, stage3_events) * 100, 2)
FROM funnel_counts
UNION ALL
SELECT PARSE_DATE('%Y%m%d', start_date), platform, campaign,
  '5. Order Completed', stage5_events, stage4_events,
  ROUND(COALESCE(SAFE_DIVIDE(stage5_events, stage4_events) * 100, 0), 2)
FROM funnel_counts;
