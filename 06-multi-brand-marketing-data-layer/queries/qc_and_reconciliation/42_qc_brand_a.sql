CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_a_freshness` AS
SELECT
  table_id                                        AS source_table,
  TIMESTAMP_MILLIS(last_modified_time)            AS last_write,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),
                 TIMESTAMP_MILLIS(last_modified_time), HOUR) AS hours
FROM `your-project.marketing.__TABLES__`
WHERE table_id IN (
        'ga4_brand_a_traffic_v2',
        'ga4_brand_a_buttons_v2',
        'ga4_brand_a_videos_v2',
        'ga4_brand_a_orientation_v3',
        'dv360_campaign_v2',
        'google_ads_campaigns_v2',
        'facebook_ads_campaigns')
  AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),
                     TIMESTAMP_MILLIS(last_modified_time), HOUR) > 30;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_a_week_incomplete` AS
SELECT
  DATE_TRUNC(date, ISOWEEK) AS week_date,
  COUNT(DISTINCT date)      AS days,
  SUM(sessions)             AS session_count
FROM `your-project.marketing.ga4_brand_a_traffic_v2`
WHERE date < DATE_TRUNC(CURRENT_DATE('Etc/GMT+6'), ISOWEEK)
  AND date >= '2026-06-01'
GROUP BY week_date
HAVING COUNT(DISTINCT date) < 7;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_a_orientation_excluded` AS
SELECT
  date,
  COUNT(*)         AS n_rows,
  SUM(event_count) AS events_in_risk
FROM `your-project.marketing.ga4_brand_a_orientation_v3`
WHERE date >= DATE_SUB(CURRENT_DATE('Etc/GMT+6'), INTERVAL 90 DAY)
  AND (TRIM(COALESCE(session_source_medium, '')) = ''
    OR TRIM(COALESCE(campaign, ''))              = '')
GROUP BY date
HAVING SUM(event_count) > 0;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_a_users_greater` AS
SELECT
  date,
  session_source_medium,
  SUM(sessions)   AS session_count,
  SUM(totalusers) AS user_count
FROM `your-project.marketing.ga4_brand_a_traffic_v2`
WHERE date >= DATE_SUB(CURRENT_DATE('Etc/GMT+6'), INTERVAL 90 DAY)
GROUP BY date, session_source_medium
HAVING SUM(totalusers) > SUM(sessions) * 1.05
   AND SUM(totalusers) - SUM(sessions) > 5;

SELECT 'freshness' AS control, COUNT(*) AS n_rows
FROM `your-project.marketing.qc_brand_a_freshness`
UNION ALL SELECT 'incomplete_week',    COUNT(*) FROM `your-project.marketing.qc_brand_a_week_incomplete`
UNION ALL SELECT 'orientation_excluded', COUNT(*) FROM `your-project.marketing.qc_brand_a_orientation_excluded`
UNION ALL SELECT 'users_greater',     COUNT(*) FROM `your-project.marketing.qc_brand_a_users_greater`
ORDER BY control;
