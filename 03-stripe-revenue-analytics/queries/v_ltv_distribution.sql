CREATE OR REPLACE VIEW `your-project.stripe.v_ltv_distribution` AS
WITH customer_ltv AS (
  SELECT
    customer,
    MIN(created_date) AS first_order_date,
    MAX(created_date) AS last_order_date,
    ROUND(SUM(amount / 100.0), 2) AS ltv
  FROM `your-project.stripe.stg_stripe_charges`
  WHERE status = 'succeeded'
  AND customer IS NOT NULL
  GROUP BY customer
)

SELECT
  customer,
  ltv,
  first_order_date,
  last_order_date,
  CASE
    WHEN ltv BETWEEN 0 AND 500 THEN '1. $0-500'
    WHEN ltv BETWEEN 501 AND 1000 THEN '2. $501-1000'
    WHEN ltv BETWEEN 1001 AND 2000 THEN '3. $1001-2000'
    WHEN ltv BETWEEN 2001 AND 3000 THEN '4. $2001-3000'
    ELSE '5. $3000+'
  END AS ltv_range
FROM customer_ltv;
