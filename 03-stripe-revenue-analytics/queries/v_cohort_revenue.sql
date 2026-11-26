CREATE OR REPLACE VIEW `your-project.stripe.v_cohort_revenue` AS
WITH first_purchase AS (
  SELECT
    customer,
    DATE_TRUNC(MIN(created_date), MONTH) AS cohort_month
  FROM `your-project.stripe.stg_stripe_charges`
  WHERE status = 'succeeded'
  AND customer IS NOT NULL
  GROUP BY customer
),
cohort_data AS (
  SELECT
    f.cohort_month,
    DATE_DIFF(DATE_TRUNC(c.created_date, MONTH), f.cohort_month, MONTH) AS month_number,
    COUNT(DISTINCT c.customer) AS customers,
    ROUND(SUM(c.amount / 100.0), 2) AS revenue
  FROM `your-project.stripe.stg_stripe_charges` c
  JOIN first_purchase f ON c.customer = f.customer
  WHERE c.status = 'succeeded'
  GROUP BY 1, 2
)
SELECT
  cohort_month AS cohort_month_date,
  FORMAT_DATE('%b %Y', cohort_month) AS cohort_month,
  SUM(CASE WHEN month_number = 0 THEN customers END) AS total_customers,
  SUM(CASE WHEN month_number = 0 THEN revenue END) AS M0_revenue,
  SUM(CASE WHEN month_number = 1 THEN revenue END) AS M1_revenue,
  SUM(CASE WHEN month_number = 2 THEN revenue END) AS M2_revenue,
  SUM(CASE WHEN month_number = 3 THEN revenue END) AS M3_revenue,
  SUM(CASE WHEN month_number = 4 THEN revenue END) AS M4_revenue,
  SUM(CASE WHEN month_number = 5 THEN revenue END) AS M5_revenue,
  SUM(CASE WHEN month_number = 6 THEN revenue END) AS M6_revenue,
  SUM(CASE WHEN month_number = 7 THEN revenue END) AS M7_revenue,
  SUM(CASE WHEN month_number = 8 THEN revenue END) AS M8_revenue,
  SUM(CASE WHEN month_number = 9 THEN revenue END) AS M9_revenue,
  SUM(CASE WHEN month_number = 10 THEN revenue END) AS M10_revenue,
  SUM(CASE WHEN month_number = 11 THEN revenue END) AS M11_revenue,
  ROUND(SUM(CASE WHEN month_number = 1 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M1_retention,
  ROUND(SUM(CASE WHEN month_number = 2 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M2_retention,
  ROUND(SUM(CASE WHEN month_number = 3 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M3_retention,
  ROUND(SUM(CASE WHEN month_number = 4 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M4_retention,
  ROUND(SUM(CASE WHEN month_number = 5 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M5_retention,
  ROUND(SUM(CASE WHEN month_number = 6 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M6_retention,
  ROUND(SUM(CASE WHEN month_number = 7 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M7_retention,
  ROUND(SUM(CASE WHEN month_number = 8 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M8_retention,
  ROUND(SUM(CASE WHEN month_number = 9 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M9_retention,
  ROUND(SUM(CASE WHEN month_number = 10 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M10_retention,
  ROUND(SUM(CASE WHEN month_number = 11 THEN customers END) / SUM(CASE WHEN month_number = 0 THEN customers END), 3) AS M11_retention
FROM cohort_data
GROUP BY 1, 2
ORDER BY 1;
