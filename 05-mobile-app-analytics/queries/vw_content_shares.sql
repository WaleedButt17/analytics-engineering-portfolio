CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_content_shares` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date)  AS event_date,
  user_id,
  user_name,
  contributor_id,
  contributor_name,
  post_id,
  platform,
  country,
  device_category
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name = 'content_action'
  AND interaction_type = 'share'
  AND contributor_id IS NOT NULL
  AND user_id IS NOT NULL;
