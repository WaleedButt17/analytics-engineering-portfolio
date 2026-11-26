CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_post_engagement` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  post_id,
  contributor_name,
  COUNTIF(event_name IN ('video_view', 'post_view')) AS views,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'like') AS likes,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'unlike') AS unlikes,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'comment') AS comments,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'comment_submit') AS comment_submits,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'share') AS shares,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'save') AS saves,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'unsave') AS unsaves,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'report') AS reports,
  COUNTIF(event_name = 'content_action' AND interaction_type = 'click') AS clicks
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE post_id IS NOT NULL
GROUP BY event_date, platform, campaign, post_id, contributor_name;
