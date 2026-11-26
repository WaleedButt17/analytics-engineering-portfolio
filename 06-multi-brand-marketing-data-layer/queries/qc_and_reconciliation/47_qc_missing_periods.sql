CREATE OR REPLACE VIEW `your-project.marketing.qc_periods_missing` AS
WITH expected AS (
  SELECT 'weekly' AS grain, week_date AS period_start
  FROM UNNEST(GENERATE_DATE_ARRAY(
         DATE_TRUNC(DATE '2025-07-07', ISOWEEK),
         DATE_SUB(DATE_TRUNC(CURRENT_DATE('Etc/GMT+6'), ISOWEEK), INTERVAL 7 DAY),
         INTERVAL 7 DAY)) AS week_date
  UNION ALL
  SELECT 'monthly', month_start
  FROM UNNEST(GENERATE_DATE_ARRAY(
         DATE '2025-07-01',
         DATE_SUB(DATE_TRUNC(CURRENT_DATE('Etc/GMT+6'), MONTH), INTERVAL 1 MONTH),
         INTERVAL 1 MONTH)) AS month_start
)
SELECT e.grain, e.period_start
FROM expected e
LEFT JOIN (
  SELECT DISTINCT grain, period_start
  FROM `your-project.marketing.ga4_users_period`
) t USING (grain, period_start)
WHERE t.grain IS NULL
ORDER BY e.grain, e.period_start;
