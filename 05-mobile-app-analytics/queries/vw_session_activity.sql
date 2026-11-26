CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_session_activity` AS
WITH session_base AS (
  SELECT
    event_date, platform,
    traffic_source_name AS campaign,
    user_pseudo_id, session_id,
    user_first_touch_timestamp,
    COUNTIF(event_name = 'screen_view_manual') AS screen_views,
    SUM(engagement_time_msec) / 1000 AS session_duration_seconds,
    MAX(CASE WHEN event_name = 'session_start' THEN 1 ELSE 0 END) AS is_session
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  GROUP BY event_date, platform, campaign, user_pseudo_id, session_id, user_first_touch_timestamp
),

user_sessions AS (
  SELECT
    event_date, platform, campaign, user_pseudo_id,
    user_first_touch_timestamp,
    COUNT(DISTINCT session_id) AS user_session_count,
    SUM(screen_views) AS total_screen_views,
    SUM(session_duration_seconds) AS total_duration
  FROM session_base
  WHERE is_session = 1
  GROUP BY event_date, platform, campaign, user_pseudo_id, user_first_touch_timestamp
)

SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  platform, campaign,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  SUM(user_session_count) AS total_sessions,
  COUNTIF(
    DATE(TIMESTAMP_MICROS(user_first_touch_timestamp)) < PARSE_DATE('%Y%m%d', event_date)
  ) AS returning_users,
  SUM(total_screen_views) AS total_screen_views,
  SUM(total_duration) AS total_duration
FROM user_sessions
GROUP BY event_date, platform, campaign;
