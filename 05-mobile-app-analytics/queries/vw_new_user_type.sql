CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_new_user_type` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  'Guest' AS user_type,
  COUNT(DISTINCT user_pseudo_id) AS new_users
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name = 'first_open'
GROUP BY event_date, platform, campaign

UNION ALL

SELECT
  PARSE_DATE('%Y%m%d', event_date),
  platform,
  traffic_source_name AS campaign,
  'Consumer',
  COUNT(DISTINCT user_pseudo_id)
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name = 'signup_completed'
GROUP BY event_date, platform, campaign

UNION ALL

SELECT
  PARSE_DATE('%Y%m%d', event_date),
  platform,
  traffic_source_name AS campaign,
  'Contributor',
  COUNT(DISTINCT user_pseudo_id)
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name = 'apply_contributor'
GROUP BY event_date, platform, campaign;
