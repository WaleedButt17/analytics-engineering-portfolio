CREATE OR REPLACE VIEW `your-project.stripe.v_customer_value_distribution` AS
WITH customer_orders AS (
  SELECT
    customer,
    MIN(created_date) AS first_order_date,
    MAX(created_date) AS last_order_date,
    COUNT(DISTINCT id) AS total_orders
  FROM `your-project.stripe.stg_stripe_charges`
  WHERE status = 'succeeded'
  AND customer IS NOT NULL
  GROUP BY customer
)

SELECT
  customer,
  total_orders,
  first_order_date,
  last_order_date,
  CASE
    WHEN total_orders = 1 THEN '1. One-time buyers'
    WHEN total_orders BETWEEN 2 AND 3 THEN '2. Active customers'
    ELSE '3. Long-term'
  END AS segment,
  CASE
    WHEN total_orders = 1 THEN '1 order'
    WHEN total_orders BETWEEN 2 AND 3 THEN '2-3 orders'
    ELSE '4+ orders'
  END AS definition
FROM customer_orders;
