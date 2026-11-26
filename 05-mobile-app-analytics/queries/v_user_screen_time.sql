CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.v_user_screen_time` AS
WITH ev AS (
  SELECT
    user_pseudo_id,
    platform,
    PARSE_DATE('%Y%m%d', event_date) AS day,
    (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'user_name') AS user_name,
    (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'user_type') AS user_type,
    event_timestamp,
    event_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen_name') AS screen_name,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_ms
  FROM `your-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX NOT LIKE 'intraday%'
    AND platform IN ('ANDROID', 'IOS')
    AND event_name NOT IN (
      'notification_receive', 'notification_dismiss', 'app_remove',
      'app_clear_data', 'os_update', 'app_update'
    )
),

user_info AS (
  SELECT
    user_pseudo_id,
    ARRAY_AGG(user_name IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)] AS user_name,
    ARRAY_AGG(user_type IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)] AS user_type,
    ARRAY_AGG(platform ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)] AS platform,
    MAX(event_timestamp) AS last_ts
  FROM ev
  GROUP BY 1
),

boundaries AS (
  SELECT
    user_pseudo_id,
    day,
    event_timestamp,
    event_name,
    CASE
      WHEN event_name != 'screen_view_manual' THEN NULL
      WHEN screen_name LIKE 'AuthLoading%' THEN 'Loading'
      WHEN screen_name = 'Create Post' THEN 'CreatePost'
      WHEN screen_name IN ('OtherProfile', 'OtherProfile1') THEN 'Other User Profile'
      WHEN screen_name = 'Profile' THEN 'My Profile (Consumer)'
      WHEN screen_name = 'Contributor Profile' THEN 'My Profile (Contributor)'
      WHEN screen_name = 'Contributor' THEN 'Contributor Page'
      WHEN screen_name = 'FavoritesScreen' THEN 'Trending Feed'
      ELSE screen_name
    END AS screen_raw
  FROM ev
  WHERE event_name IN ('screen_view_manual', 'user_app_foreground', 'user_app_background', 'app_close')
),

with_screen AS (
  SELECT
    *,
    LAST_VALUE(screen_raw IGNORE NULLS) OVER (
      PARTITION BY user_pseudo_id ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS current_screen,
    LEAD(event_timestamp) OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp) AS next_ts
  FROM boundaries
),

segments AS (
  SELECT
    w.day,
    w.user_pseudo_id,
    w.current_screen AS screen_name,
    w.event_name AS segment_start,
    LEAST((COALESCE(w.next_ts, u.last_ts) - w.event_timestamp) / 1000000, 1800) AS seconds
  FROM with_screen w
  JOIN user_info u USING (user_pseudo_id)
  WHERE w.event_name IN ('screen_view_manual', 'user_app_foreground')
    AND w.current_screen IS NOT NULL
),

user_day_segments AS (
  SELECT day, user_pseudo_id, SUM(seconds) AS total_seconds
  FROM segments
  GROUP BY 1, 2
),

user_day_engagement AS (
  SELECT day, user_pseudo_id, SUM(engagement_ms) / 60000 AS engagement_minutes
  FROM ev
  GROUP BY 1, 2
  HAVING SUM(engagement_ms) > 0
),

allocated AS (
  SELECT
    s.day,
    s.user_pseudo_id,
    s.screen_name,
    s.segment_start,
    SAFE_DIVIDE(s.seconds, t.total_seconds) * e.engagement_minutes AS minutes
  FROM segments s
  JOIN user_day_segments t USING (day, user_pseudo_id)
  JOIN user_day_engagement e USING (day, user_pseudo_id)
)

SELECT
  a.day,
  a.user_pseudo_id,
  COALESCE(u.user_name, CONCAT('guest_', SUBSTR(a.user_pseudo_id, 1, 8))) AS user_name,
  COALESCE(u.user_type, 'unknown') AS user_type,
  u.platform,
  a.screen_name,
  COUNTIF(a.segment_start = 'screen_view_manual') AS views,
  ROUND(SUM(a.minutes), 2) AS minutes
FROM allocated a
JOIN user_info u USING (user_pseudo_id)
GROUP BY 1, 2, 3, 4, 5, 6;
