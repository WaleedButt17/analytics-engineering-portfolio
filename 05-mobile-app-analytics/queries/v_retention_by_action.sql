CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.v_retention_by_action` AS
WITH last_day AS (
  SELECT MAX(PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8))) AS d
  FROM `your-project.analytics_XXXXXXXXX.INFORMATION_SCHEMA.TABLES`
  WHERE REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}$')
),

ev AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS activity_date,
    event_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'type') AS action_type
  FROM `your-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND platform IN ('ANDROID', 'IOS')
    AND user_pseudo_id IS NOT NULL
    AND event_name NOT IN (
      'notification_receive', 'notification_dismiss', 'app_remove',
      'app_clear_data', 'os_update', 'app_update'
    )
),

user_actions AS (
  SELECT DISTINCT user_pseudo_id, activity_date, 'Any activity' AS action
  FROM ev

  UNION DISTINCT

  SELECT DISTINCT
    user_pseudo_id,
    activity_date,
    CASE
      WHEN event_name = 'first_open' THEN 'Install'
      WHEN event_name = 'signup_completed' THEN 'Sign up'
      WHEN event_name = 'login_completed' THEN 'Login'
      WHEN event_name IN ('post_view', 'video_view') THEN 'View'
      WHEN event_name = 'video_watch_10s' THEN 'Watch video 10s'
      WHEN event_name = 'upload_content' THEN 'Post'
      WHEN event_name IN ('video_comment', 'video_comment_fyp') THEN 'Comment'
      WHEN event_name = 'content_action' AND action_type = 'comment_submit' THEN 'Comment'
      WHEN event_name = 'content_action' AND action_type = 'like' THEN 'Like'
      WHEN event_name = 'content_action' AND action_type = 'share' THEN 'Share'
      WHEN event_name = 'follow_contributor' THEN 'Follow'
      WHEN event_name = 'send_message' THEN 'Message'
      WHEN event_name = 'search_started' THEN 'Search'
    END AS action
  FROM ev
  WHERE event_name IN (
      'first_open', 'signup_completed', 'login_completed', 'post_view', 'video_view',
      'video_watch_10s', 'upload_content', 'video_comment', 'video_comment_fyp',
      'follow_contributor', 'send_message', 'search_started'
    )
    OR (event_name = 'content_action' AND action_type IN ('comment_submit', 'like', 'share'))
),

starts AS (
  SELECT
    user_pseudo_id,
    action AS start_action,
    activity_date AS cohort_date
  FROM user_actions
),

cohort_sizes AS (
  SELECT start_action, cohort_date, COUNT(DISTINCT user_pseudo_id) AS cohort_users
  FROM starts
  GROUP BY 1, 2
),

return_actions AS (
  SELECT DISTINCT action AS return_action
  FROM user_actions
  WHERE action != 'Install'
),

returns AS (
  SELECT
    s.start_action,
    a.action AS return_action,
    s.cohort_date,
    DATE_DIFF(a.activity_date, s.cohort_date, DAY) AS day_number,
    COUNT(DISTINCT s.user_pseudo_id) AS returning_users
  FROM starts s
  JOIN user_actions a
    ON a.user_pseudo_id = s.user_pseudo_id
   AND a.action != 'Install'
   AND DATE_DIFF(a.activity_date, s.cohort_date, DAY) BETWEEN 1 AND 30
  GROUP BY 1, 2, 3, 4
),

grid AS (
  SELECT
    c.start_action,
    r.return_action,
    c.cohort_date,
    c.cohort_users,
    day_number
  FROM cohort_sizes c
  CROSS JOIN return_actions r
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 30)) AS day_number
),

filled AS (
  SELECT
    g.start_action,
    g.return_action,
    g.cohort_date,
    g.day_number,
    g.cohort_users,
    CASE
      WHEN g.day_number = 0 THEN g.cohort_users
      WHEN DATE_ADD(g.cohort_date, INTERVAL g.day_number DAY) <= l.d THEN COALESCE(r.returning_users, 0)
      ELSE NULL
    END AS returning_users
  FROM grid g
  CROSS JOIN last_day l
  LEFT JOIN returns r
    ON r.start_action = g.start_action
   AND r.return_action = g.return_action
   AND r.cohort_date = g.cohort_date
   AND r.day_number = g.day_number
  WHERE g.cohort_date <= l.d
)

SELECT
  start_action,
  return_action,
  cohort_date AS install_date,
  day_number,
  returning_users,
  cohort_users,
  ROUND(SAFE_DIVIDE(returning_users, cohort_users) * 100, 2) AS retention_pct
FROM filled;
