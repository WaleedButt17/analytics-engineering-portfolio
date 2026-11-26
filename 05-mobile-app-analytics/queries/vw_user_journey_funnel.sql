CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_user_journey_funnel` AS
WITH
consumers AS (
  SELECT DISTINCT
    user_pseudo_id, event_date, platform,
    traffic_source_name AS campaign
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE user_type_property = 'consumer'
),
appliers AS (
  SELECT DISTINCT user_pseudo_id
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'apply_contributor'
),
actives AS (
  SELECT DISTINCT user_pseudo_id
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'upload_content'
)

SELECT
  PARSE_DATE('%Y%m%d', c.event_date) AS event_date,
  c.platform, c.campaign,
  '1. Consumer' AS funnel_stage,
  COUNT(DISTINCT c.user_pseudo_id) AS total_users
FROM consumers c
GROUP BY c.event_date, c.platform, c.campaign

UNION ALL

SELECT
  PARSE_DATE('%Y%m%d', c.event_date),
  c.platform, c.campaign, '2. Apply Contributor',
  COUNT(DISTINCT CASE WHEN a.user_pseudo_id IS NOT NULL THEN c.user_pseudo_id END)
FROM consumers c
LEFT JOIN appliers a ON c.user_pseudo_id = a.user_pseudo_id
GROUP BY c.event_date, c.platform, c.campaign

UNION ALL

SELECT
  PARSE_DATE('%Y%m%d', c.event_date),
  c.platform, c.campaign, '3. Active Contributor',
  COUNT(DISTINCT CASE WHEN a.user_pseudo_id IS NOT NULL AND ac.user_pseudo_id IS NOT NULL THEN c.user_pseudo_id END)
FROM consumers c
LEFT JOIN appliers a ON c.user_pseudo_id = a.user_pseudo_id
LEFT JOIN actives ac ON c.user_pseudo_id = ac.user_pseudo_id
GROUP BY c.event_date, c.platform, c.campaign;
