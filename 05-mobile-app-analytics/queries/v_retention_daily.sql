CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.v_retention_daily` AS
WITH last_day AS (
  SELECT MAX(PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8))) AS d
  FROM `your-project.analytics_XXXXXXXXX.INFORMATION_SCHEMA.TABLES`
  WHERE REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}$')
),

app_events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS activity_date
  FROM `your-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20260401' AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND platform IN ('ANDROID', 'IOS')
    AND event_name NOT IN (
      'notification_receive',
      'notification_dismiss',
      'app_remove',
      'app_clear_data',
      'os_update',
      'app_update'
    )
),

cohorts AS (
  SELECT
    user_pseudo_id,
    MIN(activity_date) AS cohort_date
  FROM app_events
  GROUP BY user_pseudo_id
),

active_days AS (
  SELECT DISTINCT
    user_pseudo_id,
    activity_date
  FROM app_events
),

cohort_stats AS (
  SELECT
    c.cohort_date,
    COUNT(DISTINCT c.user_pseudo_id) AS cohort_users,
    COUNT(DISTINCT IF(DATE_DIFF(a.activity_date, c.cohort_date, DAY) = 1,  c.user_pseudo_id, NULL)) AS ret_day1,
    COUNT(DISTINCT IF(DATE_DIFF(a.activity_date, c.cohort_date, DAY) = 7,  c.user_pseudo_id, NULL)) AS ret_day7,
    COUNT(DISTINCT IF(DATE_DIFF(a.activity_date, c.cohort_date, DAY) = 30, c.user_pseudo_id, NULL)) AS ret_day30
  FROM cohorts c
  LEFT JOIN active_days a
    ON a.user_pseudo_id = c.user_pseudo_id
   AND DATE_DIFF(a.activity_date, c.cohort_date, DAY) IN (1, 7, 30)
  WHERE c.cohort_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY c.cohort_date
)

SELECT
  DATE_ADD(s.cohort_date, INTERVAL 1  DAY) AS day_1_return_date,
  DATE_ADD(s.cohort_date, INTERVAL 7  DAY) AS day_7_return_date,
  DATE_ADD(s.cohort_date, INTERVAL 30 DAY) AS day_30_return_date,
  s.cohort_date,
  s.cohort_users,
  s.ret_day1,
  s.ret_day7,
  s.ret_day30,
  IF(DATE_ADD(s.cohort_date, INTERVAL 1  DAY) <= l.d, ROUND(SAFE_DIVIDE(s.ret_day1,  s.cohort_users) * 100, 2), NULL) AS day_1_retention,
  IF(DATE_ADD(s.cohort_date, INTERVAL 7  DAY) <= l.d, ROUND(SAFE_DIVIDE(s.ret_day7,  s.cohort_users) * 100, 2), NULL) AS day_7_retention,
  IF(DATE_ADD(s.cohort_date, INTERVAL 30 DAY) <= l.d, ROUND(SAFE_DIVIDE(s.ret_day30, s.cohort_users) * 100, 2), NULL) AS day_30_retention
FROM cohort_stats s
CROSS JOIN last_day l
WHERE s.cohort_date <= l.d;
