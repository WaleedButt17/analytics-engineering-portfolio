CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.v_dau_wau_mau` AS
WITH daily_users AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS activity_date,
    user_pseudo_id
  FROM `your-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN
    FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  GROUP BY activity_date, user_pseudo_id
),

date_spine AS (
  SELECT day AS activity_date
  FROM UNNEST(GENERATE_DATE_ARRAY(
    DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), CURRENT_DATE()
  )) AS day
)

SELECT
  d.activity_date,
  COUNT(DISTINCT IF(du.activity_date = d.activity_date, du.user_pseudo_id, NULL)) AS dau,
  COUNT(DISTINCT IF(du.activity_date BETWEEN DATE_SUB(d.activity_date, INTERVAL 6 DAY) AND d.activity_date, du.user_pseudo_id, NULL)) AS wau,
  COUNT(DISTINCT IF(du.activity_date BETWEEN DATE_SUB(d.activity_date, INTERVAL 29 DAY) AND d.activity_date, du.user_pseudo_id, NULL)) AS mau
FROM date_spine d
JOIN daily_users du
  ON du.activity_date BETWEEN DATE_SUB(d.activity_date, INTERVAL 29 DAY) AND d.activity_date
GROUP BY d.activity_date
ORDER BY d.activity_date;
