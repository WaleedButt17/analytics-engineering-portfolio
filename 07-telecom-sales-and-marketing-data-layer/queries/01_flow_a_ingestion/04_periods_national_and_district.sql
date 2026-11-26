CREATE OR REPLACE VIEW `your-project.client_dataset.vw_periods_national_v2` AS
WITH base AS (
  SELECT report_date, subchannel, sales, installs, reconciles
  FROM `your-project.client_dataset.vw_national_v2_validated`
),
bounds AS (SELECT MAX(report_date) AS max_date FROM base),
expanded AS (
  SELECT g.grain, g.range_start, g.range_end,
         b.report_date, b.subchannel, b.sales, b.installs, b.reconciles
  FROM base b,
  UNNEST([
    STRUCT('weekly' AS grain,
           DATE_TRUNC(b.report_date, WEEK(MONDAY)) AS range_start,
           DATE_ADD(DATE_TRUNC(b.report_date, WEEK(MONDAY)), INTERVAL 6 DAY) AS range_end),
    STRUCT('biweekly',
           IF(EXTRACT(DAY FROM b.report_date) <= 15, DATE_TRUNC(b.report_date, MONTH),
              DATE_ADD(DATE_TRUNC(b.report_date, MONTH), INTERVAL 15 DAY)),
           IF(EXTRACT(DAY FROM b.report_date) <= 15,
              DATE_ADD(DATE_TRUNC(b.report_date, MONTH), INTERVAL 14 DAY), LAST_DAY(b.report_date))),
    STRUCT('monthly', DATE_TRUNC(b.report_date, MONTH), LAST_DAY(b.report_date))
  ]) AS g
  UNION ALL
  SELECT 'month_to_date', DATE_TRUNC(b.report_date, MONTH), l.max_date,
         b.report_date, b.subchannel, b.sales, b.installs, b.reconciles
  FROM base b CROSS JOIN bounds l
  WHERE DATE_TRUNC(b.report_date, MONTH) = DATE_TRUNC(l.max_date, MONTH)
),
grouped AS (
  SELECT grain, range_start AS period_start, range_end AS period_end, subchannel,
         SUM(sales) AS sales, SUM(installs) AS installs,
         COUNT(DISTINCT report_date) AS days_with_data,
         DATE_DIFF(range_end, range_start, DAY) + 1 AS days_in_period,
         LOGICAL_AND(reconciles) AS reconciles
  FROM expanded
  GROUP BY GROUPING SETS (
    (grain, range_start, range_end, subchannel),
    (grain, range_start, range_end)
  )
)
SELECT grain, period_start, period_end,
       IFNULL(NULLIF(subchannel, ''), '(all)') AS subchannel,
       sales, installs,
       ROUND(SAFE_DIVIDE(installs, sales) * 100, 2) AS install_rate_pct,
       days_with_data, days_in_period,
       days_with_data = days_in_period AS period_complete,
       reconciles
FROM grouped;

CREATE OR REPLACE VIEW `your-project.client_dataset.vw_periods_district_v2` AS
WITH base AS (
  SELECT report_date, district, subchannel, sales, installs
  FROM `your-project.client_dataset.stg_salesforce_v2`
),
bounds AS (SELECT MAX(report_date) AS max_date FROM base),
expanded AS (
  SELECT g.grain, g.range_start, g.range_end,
         b.report_date, b.district, b.subchannel, b.sales, b.installs
  FROM base b,
  UNNEST([
    STRUCT('weekly' AS grain,
           DATE_TRUNC(b.report_date, WEEK(MONDAY)) AS range_start,
           DATE_ADD(DATE_TRUNC(b.report_date, WEEK(MONDAY)), INTERVAL 6 DAY) AS range_end),
    STRUCT('biweekly',
           IF(EXTRACT(DAY FROM b.report_date) <= 15, DATE_TRUNC(b.report_date, MONTH),
              DATE_ADD(DATE_TRUNC(b.report_date, MONTH), INTERVAL 15 DAY)),
           IF(EXTRACT(DAY FROM b.report_date) <= 15,
              DATE_ADD(DATE_TRUNC(b.report_date, MONTH), INTERVAL 14 DAY), LAST_DAY(b.report_date))),
    STRUCT('monthly', DATE_TRUNC(b.report_date, MONTH), LAST_DAY(b.report_date))
  ]) AS g
  UNION ALL
  SELECT 'month_to_date', DATE_TRUNC(b.report_date, MONTH), l.max_date,
         b.report_date, b.district, b.subchannel, b.sales, b.installs
  FROM base b CROSS JOIN bounds l
  WHERE DATE_TRUNC(b.report_date, MONTH) = DATE_TRUNC(l.max_date, MONTH)
),
grouped AS (
  SELECT grain, range_start AS period_start, range_end AS period_end, district, subchannel,
         SUM(sales) AS sales, SUM(installs) AS installs,
         COUNT(DISTINCT report_date) AS days_with_data,
         DATE_DIFF(range_end, range_start, DAY) + 1 AS days_in_period
  FROM expanded
  GROUP BY GROUPING SETS (
    (grain, range_start, range_end, district, subchannel),
    (grain, range_start, range_end, district)
  )
)
SELECT grain, period_start, period_end, district,
       IFNULL(NULLIF(subchannel, ''), '(all)') AS subchannel,
       sales, installs,
       days_with_data, days_in_period,
       days_with_data = days_in_period AS period_complete
FROM grouped;
