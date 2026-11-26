CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_order_completion_rate` AS
WITH funnel_base AS (
  SELECT
    event_date,
    platform,
    traffic_source_name AS campaign,
    user_pseudo_id,
    MAX(CASE WHEN event_name = 'payment_success' THEN 1 ELSE 0 END) AS payment_started,
    MAX(CASE WHEN event_name = 'order_completed' THEN 1 ELSE 0 END) AS order_done
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  GROUP BY event_date, platform, campaign, user_pseudo_id
)

SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform,
  campaign,
  COUNTIF(payment_started = 1) AS orders_started,
  COUNTIF(order_done = 1) AS orders_completed,
  ROUND(SAFE_DIVIDE(
    COUNTIF(order_done = 1),
    COUNTIF(payment_started = 1)
  ), 4) AS completion_rate
FROM funnel_base
GROUP BY event_date, platform, campaign;
