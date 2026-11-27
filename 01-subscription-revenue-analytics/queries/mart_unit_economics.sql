CREATE OR REPLACE VIEW `your-project.marts.mart_unit_economics`
AS WITH
monthly_ad_spend AS (
  SELECT
    DATE_TRUNC(ad_date, MONTH) AS month,
    SUM(spend) AS total_spend
  FROM `your-project.staging.stg_meta_ads`
  GROUP BY DATE_TRUNC(ad_date, MONTH)
),
monthly_new_customers AS (
  SELECT
    DATE_TRUNC(date, MONTH) AS month,
    SUM(orders) AS new_customers
  FROM `your-project.marts.mart_customer_acquisition`
  WHERE customer_type = 'First-time'
  GROUP BY DATE_TRUNC(date, MONTH)
),
monthly_total_customers AS (
  SELECT
    DATE_TRUNC(date, MONTH) AS month,
    SUM(orders) AS total_customers
  FROM `your-project.marts.mart_customer_acquisition`
  GROUP BY DATE_TRUNC(date, MONTH)
),
ltv_data AS (
  SELECT
    cohort_month_date AS month,
    platform,
    total_customers AS ltv_customers,
    avg_ltv_d30, avg_ltv_d60, avg_ltv_d90, avg_ltv_d120, avg_ltv_overall,
    total_ltv_d30, total_ltv_d60, total_ltv_d90, total_ltv_d120, total_ltv_overall
  FROM `your-project.marts.mart_ltv`
)
SELECT
  m.month,
  FORMAT_DATE('%b %Y', m.month) AS month_label,
  m.total_spend AS ad_spend,
  nc.new_customers,
  tc.total_customers,
  SAFE_DIVIDE(m.total_spend, nc.new_customers) AS ncac,
  l.ltv_customers,
  l.avg_ltv_d30, l.avg_ltv_d60, l.avg_ltv_d90, l.avg_ltv_d120, l.avg_ltv_overall,
  l.total_ltv_d30, l.total_ltv_d60, l.total_ltv_d90, l.total_ltv_d120, l.total_ltv_overall,
  SAFE_DIVIDE(l.avg_ltv_d30,    SAFE_DIVIDE(m.total_spend, nc.new_customers)) AS ltv_cac_d30,
  SAFE_DIVIDE(l.avg_ltv_d60,    SAFE_DIVIDE(m.total_spend, nc.new_customers)) AS ltv_cac_d60,
  SAFE_DIVIDE(l.avg_ltv_d90,    SAFE_DIVIDE(m.total_spend, nc.new_customers)) AS ltv_cac_d90,
  SAFE_DIVIDE(l.avg_ltv_d120,   SAFE_DIVIDE(m.total_spend, nc.new_customers)) AS ltv_cac_d120,
  SAFE_DIVIDE(l.avg_ltv_overall, SAFE_DIVIDE(m.total_spend, nc.new_customers)) AS ltv_cac_overall,
  SAFE_DIVIDE(
    SAFE_DIVIDE(m.total_spend, nc.new_customers),
    SAFE_DIVIDE(l.avg_ltv_overall, 4)
  ) AS cac_payback_months
FROM monthly_ad_spend m
LEFT JOIN monthly_new_customers nc ON m.month = nc.month
LEFT JOIN monthly_total_customers tc ON m.month = tc.month
LEFT JOIN ltv_data l ON m.month = l.month AND l.platform = 'shopify'
ORDER BY m.month;
