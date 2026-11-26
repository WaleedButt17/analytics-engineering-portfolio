CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_interaction_count` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  CASE
    WHEN interaction_type = 'like' THEN 'Likes'
    WHEN interaction_type = 'unlike' THEN 'Unlikes'
    WHEN interaction_type = 'share' THEN 'Shares'
    WHEN interaction_type = 'save' THEN 'Saves'
    WHEN interaction_type = 'unsave' THEN 'Unsaves'
    WHEN interaction_type = 'comment' THEN 'Comments'
    WHEN interaction_type = 'comment_submit' THEN 'Comment Submit'
    WHEN interaction_type = 'report' THEN 'Reports'
    WHEN interaction_type = 'click' THEN 'Clicks'
  END AS interaction_type,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS total_users
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name = 'content_action'
  AND interaction_type IN (
    'like', 'unlike', 'share', 'save', 'unsave',
    'comment', 'comment_submit', 'report', 'click'
  )
GROUP BY event_date, platform, campaign, interaction_type;
