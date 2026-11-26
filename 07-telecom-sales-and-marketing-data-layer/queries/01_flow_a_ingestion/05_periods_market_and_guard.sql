CREATE OR REPLACE VIEW `your-project.client_dataset.vw_periods_market_v2` AS
WITH base AS (
  SELECT s.report_date, IFNULL(m.market, '(no market)') AS market,
         s.subchannel, s.sales, s.installs
  FROM `your-project.client_dataset.stg_salesforce_v2` s
  LEFT JOIN `your-project.client_dataset.dim_market_district` m USING (district)
),
bounds AS (SELECT MAX(report_date) AS max_date FROM base),
expanded AS (
  SELECT g.grain, g.range_start, g.range_end, b.report_date, b.market, b.subchannel, b.sales, b.installs
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
         b.report_date, b.market, b.subchannel, b.sales, b.installs
  FROM base b CROSS JOIN bounds l
  WHERE DATE_TRUNC(b.report_date, MONTH) = DATE_TRUNC(l.max_date, MONTH)
),
grouped AS (
  SELECT grain, range_start AS period_start, range_end AS period_end, market, subchannel,
         SUM(sales) AS sales, SUM(installs) AS installs,
         COUNT(DISTINCT report_date) AS days_with_data,
         DATE_DIFF(range_end, range_start, DAY) + 1 AS days_in_period
  FROM expanded
  GROUP BY GROUPING SETS (
    (grain, range_start, range_end, market, subchannel),
    (grain, range_start, range_end, market)
  )
)
SELECT grain, period_start, period_end, market,
       IFNULL(NULLIF(subchannel, ''), '(all)') AS subchannel,
       sales, installs,
       ROUND(SAFE_DIVIDE(installs, sales) * 100, 2) AS install_rate_pct,
       days_with_data, days_in_period,
       days_with_data = days_in_period AS period_complete
FROM grouped;

CREATE OR REPLACE VIEW `your-project.client_dataset.qc_districts_without_market_v2` AS
SELECT
  d.district,
  MIN(d.report_date) AS first_seen,
  MAX(d.report_date) AS last_seen,
  SUM(d.sales) AS sales_affected
FROM `your-project.client_dataset.stg_salesforce_v2` d
LEFT JOIN `your-project.client_dataset.dim_market_district` m
  USING (district)
WHERE m.market IS NULL
GROUP BY d.district;
