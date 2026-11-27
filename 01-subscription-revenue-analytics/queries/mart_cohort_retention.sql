CREATE OR REPLACE VIEW `your-project.marts.mart_cohort_retention`
AS WITH

loop_subs AS (
  SELECT
    CAST(subscription_id AS STRING) AS subscription_id,
    CAST(customer_email AS STRING) AS customer_email,
    'loop' AS platform,
    created_date,
    cancelled_date,
    CAST(status AS STRING) AS status,
    CAST(UPPER(country_code) AS STRING) AS country_code,
    CAST(total_line_item_discounted_price AS FLOAT64) AS monthly_value
  FROM `your-project.staging.stg_loop_subscriptions`
),

cc_subs AS (
  SELECT
    CAST(purchase_id AS STRING) AS subscription_id,
    CAST(NULL AS STRING) AS customer_email,
    'checkoutchamp' AS platform,
    DATE(date_created) AS created_date,
    CAST(last_cancellation_date AS DATE) AS cancelled_date,
    CAST(CASE
      WHEN status IN ('ACTIVE', 'RECYCLE_FAILED', 'RECYCLE_BILLING') THEN 'ACTIVE'
      WHEN status IN ('CANCELLED', 'COMPLETE') THEN 'CANCELLED'
      ELSE status
    END AS STRING) AS status,
    CAST(UPPER(country) AS STRING) AS country_code,
    CAST(price AS FLOAT64) AS monthly_value
  FROM `your-project.staging.stg_cc_purchases`
),

all_subs AS (
  SELECT * FROM loop_subs
  UNION ALL
  SELECT * FROM cc_subs
),

cohort_base AS (
  SELECT
    subscription_id, customer_email, platform, country_code, monthly_value,
    created_date, cancelled_date, status,
    DATE_TRUNC(created_date, MONTH) AS cohort_month
  FROM all_subs
  WHERE created_date IS NOT NULL
),

sub_months AS (
  SELECT
    c.subscription_id, c.platform, c.country_code, c.cohort_month, c.monthly_value,
    DATE_DIFF(
      DATE_TRUNC(CASE WHEN c.cancelled_date IS NULL THEN CURRENT_DATE() ELSE c.cancelled_date END, MONTH),
      c.cohort_month, MONTH
    ) AS active_months
  FROM cohort_base c
),

cohort_data AS (
  SELECT
    s.cohort_month, month_number,
    COUNT(DISTINCT s.subscription_id) AS subscribers,
    SUM(s.monthly_value) AS revenue,
    s.platform
  FROM sub_months s
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 12)) AS month_number
  WHERE month_number <= s.active_months
  GROUP BY s.cohort_month, month_number, s.platform
),

running_m0 AS (
  SELECT
    cohort_month,
    platform,
    COUNT(DISTINCT subscription_id) AS total_subscribers,
    COUNT(DISTINCT CASE
      WHEN cancelled_date IS NULL
        OR cancelled_date >= DATE_ADD(cohort_month, INTERVAL 1 MONTH)
      THEN subscription_id
    END) AS still_active_today
  FROM cohort_base
  GROUP BY cohort_month, platform
)

SELECT
  cd.platform,
  cd.cohort_month AS cohort_month_date,
  FORMAT_DATE('%b %Y', cd.cohort_month) AS cohort_month_label,
  SUM(CASE WHEN month_number = 0 THEN subscribers END) AS total_subscribers,
  ROUND(SAFE_DIVIDE(r.still_active_today, r.total_subscribers), 3) AS running_m0_retention,
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
  SUM(CASE WHEN month_number = 12 THEN revenue END) AS M12_revenue,
  SUM(CASE WHEN month_number = 1 THEN subscribers END) AS M1_subscribers,
  SUM(CASE WHEN month_number = 2 THEN subscribers END) AS M2_subscribers,
  SUM(CASE WHEN month_number = 3 THEN subscribers END) AS M3_subscribers,
  SUM(CASE WHEN month_number = 4 THEN subscribers END) AS M4_subscribers,
  SUM(CASE WHEN month_number = 5 THEN subscribers END) AS M5_subscribers,
  SUM(CASE WHEN month_number = 6 THEN subscribers END) AS M6_subscribers,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 1 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M1_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 2 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M2_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 3 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M3_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 4 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M4_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 5 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M5_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 6 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M6_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 7 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M7_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 8 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M8_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 9 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M9_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 10 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M10_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 11 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M11_retention,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN month_number = 12 THEN subscribers END), SUM(CASE WHEN month_number = 0 THEN subscribers END)), 3) AS M12_retention
FROM cohort_data cd
LEFT JOIN running_m0 r ON cd.cohort_month = r.cohort_month AND cd.platform = r.platform
GROUP BY cd.platform, cd.cohort_month, r.still_active_today, r.total_subscribers
ORDER BY cd.platform, cd.cohort_month;
