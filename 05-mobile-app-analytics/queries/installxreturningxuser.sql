CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.InstallXReturningXuser` AS
WITH last_day AS (
  SELECT MAX(PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8))) AS d
  FROM `your-project.analytics_XXXXXXXXX.INFORMATION_SCHEMA.TABLES`
  WHERE REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}$')
),

installs AS (
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date)) AS install_date
  FROM `your-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20260401' AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND event_name = 'first_open'
    AND platform IN ('ANDROID', 'IOS')
  GROUP BY user_pseudo_id
),

recent_installs AS (
  SELECT *
  FROM installs
  WHERE install_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
),

active_days AS (
  SELECT DISTINCT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS activity_date
  FROM `your-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
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

cohort_sizes AS (
  SELECT
    install_date,
    COUNT(*) AS cohort_users
  FROM recent_installs
  GROUP BY install_date
),

returns AS (
  SELECT
    i.install_date,
    DATE_DIFF(a.activity_date, i.install_date, DAY) AS day_number,
    COUNT(DISTINCT i.user_pseudo_id) AS returning_users
  FROM recent_installs i
  JOIN active_days a
    ON a.user_pseudo_id = i.user_pseudo_id
   AND DATE_DIFF(a.activity_date, i.install_date, DAY) BETWEEN 1 AND 30
  GROUP BY 1, 2
),

grid AS (
  SELECT
    c.install_date,
    c.cohort_users,
    day_number
  FROM cohort_sizes c
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 30)) AS day_number
),

filled AS (
  SELECT
    g.install_date,
    g.day_number,
    g.cohort_users,
    CASE
      WHEN g.day_number = 0 THEN g.cohort_users
      WHEN DATE_ADD(g.install_date, INTERVAL g.day_number DAY) <= l.d THEN COALESCE(r.returning_users, 0)
      ELSE NULL
    END AS returning_users
  FROM grid g
  CROSS JOIN last_day l
  LEFT JOIN returns r
    ON r.install_date = g.install_date
   AND r.day_number = g.day_number
  WHERE g.install_date <= l.d
)

SELECT
  install_date,
  day_number,
  returning_users,
  cohort_users,
  ROUND(SAFE_DIVIDE(returning_users, cohort_users) * 100, 2) AS retention_pct
FROM filled;
