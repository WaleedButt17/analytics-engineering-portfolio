CREATE OR REPLACE VIEW `your-project.marts.mart_ltv`
AS WITH

shopify_customer_orders AS (
  SELECT
    customer_email,
    MIN(order_date) AS first_order_date,
    SUM(net_sales) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders
  FROM `your-project.staging.stg_shopify_orders`
  WHERE customer_email IS NOT NULL
  GROUP BY customer_email
),

shopify_ltv AS (
  SELECT
    f.customer_email,
    f.first_order_date,
    'shopify' AS platform,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 30 THEN o.net_sales ELSE 0 END) AS ltv_d30,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 60 THEN o.net_sales ELSE 0 END) AS ltv_d60,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 90 THEN o.net_sales ELSE 0 END) AS ltv_d90,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 120 THEN o.net_sales ELSE 0 END) AS ltv_d120,
    SUM(o.net_sales) AS ltv_overall
  FROM shopify_customer_orders f
  JOIN `your-project.staging.stg_shopify_orders` o
    ON f.customer_email = o.customer_email
  GROUP BY f.customer_email, f.first_order_date
),

cc_customer_orders AS (
  SELECT
    customer_id,
    MIN(order_date) AS first_order_date,
    SUM(total_amount) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders
  FROM `your-project.staging.stg_cc_orders`
  GROUP BY customer_id
),

cc_ltv AS (
  SELECT
    CAST(f.customer_id AS STRING) AS customer_email,
    f.first_order_date,
    'checkoutchamp' AS platform,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 30 THEN o.total_amount ELSE 0 END) AS ltv_d30,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 60 THEN o.total_amount ELSE 0 END) AS ltv_d60,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 90 THEN o.total_amount ELSE 0 END) AS ltv_d90,
    SUM(CASE WHEN DATE_DIFF(o.order_date, f.first_order_date, DAY) <= 120 THEN o.total_amount ELSE 0 END) AS ltv_d120,
    SUM(o.total_amount) AS ltv_overall
  FROM cc_customer_orders f
  JOIN `your-project.staging.stg_cc_orders` o
    ON f.customer_id = o.customer_id
  GROUP BY f.customer_id, f.first_order_date
),

all_ltv AS (
  SELECT * FROM shopify_ltv
  UNION ALL
  SELECT * FROM cc_ltv
),

ltv_by_cohort AS (
  SELECT
    platform,
    DATE_TRUNC(first_order_date, MONTH) AS cohort_month,
    COUNT(DISTINCT customer_email) AS total_customers,
    ROUND(AVG(ltv_d30), 2) AS avg_ltv_d30,
    ROUND(AVG(ltv_d60), 2) AS avg_ltv_d60,
    ROUND(AVG(ltv_d90), 2) AS avg_ltv_d90,
    ROUND(AVG(ltv_d120), 2) AS avg_ltv_d120,
    ROUND(AVG(ltv_overall), 2) AS avg_ltv_overall,
    ROUND(SUM(ltv_d30), 2) AS total_ltv_d30,
    ROUND(SUM(ltv_d60), 2) AS total_ltv_d60,
    ROUND(SUM(ltv_d90), 2) AS total_ltv_d90,
    ROUND(SUM(ltv_d120), 2) AS total_ltv_d120,
    ROUND(SUM(ltv_overall), 2) AS total_ltv_overall
  FROM all_ltv
  GROUP BY platform, cohort_month
)

SELECT
  platform,
  cohort_month AS cohort_month_date,
  FORMAT_DATE('%b %Y', cohort_month) AS cohort_month_label,
  total_customers,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 30 THEN avg_ltv_d30 ELSE NULL END AS avg_ltv_d30,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 60 THEN avg_ltv_d60 ELSE NULL END AS avg_ltv_d60,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 90 THEN avg_ltv_d90 ELSE NULL END AS avg_ltv_d90,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 120 THEN avg_ltv_d120 ELSE NULL END AS avg_ltv_d120,
  avg_ltv_overall,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 30 THEN total_ltv_d30 ELSE NULL END AS total_ltv_d30,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 60 THEN total_ltv_d60 ELSE NULL END AS total_ltv_d60,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 90 THEN total_ltv_d90 ELSE NULL END AS total_ltv_d90,
  CASE WHEN DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) >= 120 THEN total_ltv_d120 ELSE NULL END AS total_ltv_d120,
  total_ltv_overall
FROM ltv_by_cohort
ORDER BY platform, cohort_month;
