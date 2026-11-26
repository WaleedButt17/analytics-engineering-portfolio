CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_video_share_stats` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  COUNT(*) AS total_video_shares,
  COUNT(DISTINCT user_pseudo_id) AS total_users_who_shared
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name = 'content_action'
AND interaction_type = 'share'
AND content_type = 'video'
GROUP BY event_date, platform, campaign;
