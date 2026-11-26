CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_notification_interaction` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  traffic_source_name AS campaign,
  COUNTIF(event_name = 'notification_receive') AS notifications_received,
  COUNTIF(event_name = 'notification_open') AS notifications_opened,
  COUNTIF(event_name = 'click_notification') AS notifications_clicked,
  COUNTIF(event_name = 'notification_dismiss') AS notifications_dismissed
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE event_name IN (
  'notification_receive', 'notification_open',
  'click_notification', 'notification_dismiss'
)
GROUP BY event_date, platform, campaign;
