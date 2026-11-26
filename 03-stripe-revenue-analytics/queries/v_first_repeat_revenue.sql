CREATE OR REPLACE VIEW `your-project.stripe.v_first_repeat_revenue` AS
WITH first_purchase AS (
  SELECT
    customer,
    MIN(created_date) AS first_purchase_date
  FROM `your-project.stripe.stg_stripe_charges`
  WHERE status = 'succeeded'
  AND customer IS NOT NULL
  GROUP BY customer
)
SELECT
  c.created_date,
  c.id AS charge_id,
  c.customer,
  ROUND(c.amount / 100.0, 2) AS revenue,
  CASE
    WHEN c.created_date = f.first_purchase_date THEN 'First Order'
    ELSE 'Repeat'
  END AS order_type,
  CASE
    WHEN c.created_date = f.first_purchase_date THEN 0
    ELSE 1
  END AS is_repeat
FROM `your-project.stripe.stg_stripe_charges` c
JOIN first_purchase f ON c.customer = f.customer
WHERE c.status = 'succeeded'
AND c.customer IS NOT NULL;
