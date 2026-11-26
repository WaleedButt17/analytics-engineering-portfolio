CREATE OR REPLACE TABLE `your-project.client_dataset.agent_national`
PARTITION BY period_start
CLUSTER BY grain, subchannel
AS
WITH daily AS (
  SELECT
    'daily' AS grain,
    report_date    AS period_start,
    report_date    AS period_end,
    subchannel,
    SUM(sales)        AS sales,
    SUM(installs) AS installs,
    TRUE               AS period_complete,
    LOGICAL_AND(reconciles) AS reconciles
  FROM `your-project.client_dataset.vw_national_v2_validated`
  GROUP BY GROUPING SETS ((report_date, subchannel), (report_date))
),
periods AS (
  SELECT grain, period_start, period_end, subchannel,
         sales, installs, period_complete, reconciles
  FROM `your-project.client_dataset.vw_periods_national_v2`
),
unified AS (
  SELECT grain, period_start, period_end,
         IFNULL(NULLIF(subchannel, ''), '(all)') AS subchannel,
         sales, installs, period_complete, reconciles
  FROM daily
  UNION ALL
  SELECT grain, period_start, period_end, subchannel,
         sales, installs, period_complete, reconciles
  FROM periods
)
SELECT
  grain,
  period_start,
  period_end,
  subchannel,
  CAST(sales        AS INT64) AS sales,
  CAST(installs AS INT64) AS installs,
  ROUND(SAFE_DIVIDE(installs, sales) * 100, 2) AS install_rate_pct,
  period_complete,
  reconciles,
  subchannel = '(all)' AS is_total_row,
  'sheet consolidated Total row' AS national_figure_basis,
  CURRENT_TIMESTAMP() AS updated_at
FROM unified;
