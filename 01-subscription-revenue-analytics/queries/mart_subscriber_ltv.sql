CREATE OR REPLACE VIEW `your-project.marts.mart_subscriber_ltv`
AS WITH

loop_subscribers AS (
  SELECT DISTINCT
    LOWER(customer_email) AS customer_email,
    store,
    UPPER(country_code) AS country_code,
    created_date AS subscription_start_date,
    status,
    cancelled_date
  FROM `your-project.staging.stg_loop_subscriptions`
  WHERE customer_email IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_email ORDER BY created_date ASC) = 1
),

shopify_revenue AS (
  SELECT
    LOWER(customer_email) AS customer_email,
    order_date,
    net_sales,
    order_id
  FROM `your-project.staging.stg_shopify_orders`
  WHERE customer_email IS NOT NULL
),

customer_first_order AS (
  SELECT
    customer_email,
    MIN(order_date) AS first_order_date
  FROM shopify_revenue
  GROUP BY customer_email
),

customer_ltv AS (
  SELECT
    r.customer_email,
    f.first_order_date,
    CASE WHEN l.customer_email IS NOT NULL THEN 'subscriber' ELSE 'non_subscriber' END AS customer_type,
    l.subscription_start_date,
    l.status AS subscription_status,
    l.country_code,
    SUM(CASE WHEN DATE_DIFF(r.order_date, f.first_order_date, DAY) <= 30 THEN r.net_sales ELSE 0 END) AS ltv_d30,
    SUM(CASE WHEN DATE_DIFF(r.order_date, f.first_order_date, DAY) <= 60 THEN r.net_sales ELSE 0 END) AS ltv_d60,
    SUM(CASE WHEN DATE_DIFF(r.order_date, f.first_order_date, DAY) <= 90 THEN r.net_sales ELSE 0 END) AS ltv_d90,
    SUM(CASE WHEN DATE_DIFF(r.order_date, f.first_order_date, DAY) <= 120 THEN r.net_sales ELSE 0 END) AS ltv_d120,
    SUM(r.net_sales) AS ltv_overall,
    COUNT(DISTINCT r.order_id) AS total_orders
  FROM customer_first_order f
  JOIN shopify_revenue r ON f.customer_email = r.customer_email
  LEFT JOIN loop_subscribers l ON f.customer_email = l.customer_email
  GROUP BY r.customer_email, f.first_order_date, customer_type, l.subscription_start_date, l.status, l.country_code
)

SELECT
  customer_type,
  COUNT(DISTINCT customer_email) AS total_customers,
  ROUND(AVG(ltv_d30), 2) AS avg_ltv_d30,
  ROUND(AVG(ltv_d60), 2) AS avg_ltv_d60,
  ROUND(AVG(ltv_d90), 2) AS avg_ltv_d90,
  ROUND(AVG(ltv_d120), 2) AS avg_ltv_d120,
  ROUND(AVG(ltv_overall), 2) AS avg_ltv_overall,
  ROUND(AVG(total_orders), 2) AS avg_orders
FROM customer_ltv
GROUP BY customer_type;
