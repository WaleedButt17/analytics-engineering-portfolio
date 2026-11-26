CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_contributor_activity` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  contributor_name,
  COUNTIF(event_name = 'upload_content') AS posts_created,
  SUM(CASE WHEN event_name = 'upload_content' THEN COALESCE(video_file_count, 0) END) AS videos_uploaded,
  SUM(CASE WHEN event_name = 'upload_content' THEN COALESCE(image_file_count, 0) END) AS images_uploaded,
  COUNTIF(event_name = 'deliver_order') AS orders_fulfilled,
  COUNT(DISTINCT CASE WHEN event_name = 'upload_content' THEN user_pseudo_id END) AS unique_contributors
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name IN ('upload_content', 'deliver_order')
GROUP BY event_date, platform, campaign, contributor_name;
