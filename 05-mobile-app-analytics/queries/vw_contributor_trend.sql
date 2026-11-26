CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_contributor_trend` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  COUNT(DISTINCT CASE WHEN event_name = 'Apply_Contributor' THEN user_pseudo_id END) AS new_contributors,
  COUNT(DISTINCT CASE WHEN event_name = 'upload_content' THEN user_pseudo_id END) AS active_contributors
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
GROUP BY event_date, platform, campaign;
