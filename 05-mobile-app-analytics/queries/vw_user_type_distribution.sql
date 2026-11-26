CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_user_type_distribution` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  user_pseudo_id,
  CASE
    WHEN user_type_property = 'guest' THEN 'Guest'
    WHEN user_type_property = 'consumer' THEN 'Consumer'
    WHEN user_type_property = 'contributor' THEN 'Contributor'
  END AS user_type
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE user_type_property IS NOT NULL;
