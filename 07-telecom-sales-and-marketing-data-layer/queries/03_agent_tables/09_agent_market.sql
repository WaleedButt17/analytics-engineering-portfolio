CREATE OR REPLACE TABLE `your-project.client_dataset.agent_market`
PARTITION BY period_start
CLUSTER BY grain, market, subchannel
AS
WITH daily AS (
  SELECT
    'daily' AS grain,
    s.report_date  AS period_start,
    s.report_date  AS period_end,
    IFNULL(m.market, '(no market)') AS market,
    s.district,
    s.subchannel,
    SUM(s.sales)        AS sales,
    SUM(s.installs) AS installs,
    TRUE                 AS period_complete
  FROM `your-project.client_dataset.stg_salesforce_v2` s
  LEFT JOIN `your-project.client_dataset.dim_market_district` m
    USING (district)
  GROUP BY GROUPING SETS (
    (s.report_date, market, s.district, s.subchannel),
    (s.report_date, market, s.district)
  )
),
periods AS (
  SELECT
    p.grain, p.period_start, p.period_end,
    IFNULL(m.market, '(no market)') AS market,
    p.district, p.subchannel,
    p.sales, p.installs, p.period_complete
  FROM `your-project.client_dataset.vw_periods_district_v2` p
  LEFT JOIN `your-project.client_dataset.dim_market_district` m
    USING (district)
),
unified AS (
  SELECT grain, period_start, period_end, market, district,
         IFNULL(NULLIF(subchannel, ''), '(all)') AS subchannel,
         sales, installs, period_complete
  FROM daily
  UNION ALL
  SELECT grain, period_start, period_end, market, district, subchannel,
         sales, installs, period_complete
  FROM periods
)
SELECT
  grain,
  period_start,
  period_end,
  market,
  district,
  subchannel,
  CAST(sales        AS INT64) AS sales,
  CAST(installs AS INT64) AS installs,
  ROUND(SAFE_DIVIDE(installs, sales) * 100, 2) AS install_rate_pct,
  period_complete,
  subchannel = '(all)' AS is_total_row,
  FALSE AS is_audited_figure,
  CURRENT_TIMESTAMP() AS updated_at
FROM unified;
