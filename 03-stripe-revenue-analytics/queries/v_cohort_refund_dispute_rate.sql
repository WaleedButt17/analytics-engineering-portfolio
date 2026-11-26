CREATE OR REPLACE VIEW `your-project.stripe.v_cohort_refund_dispute_rate` AS
WITH first_purchase AS (
  SELECT
    customer,
    DATE_TRUNC(MIN(created_date), MONTH) AS cohort_month
  FROM `your-project.stripe.stg_stripe_charges`
  WHERE status = 'succeeded'
  AND customer IS NOT NULL
  GROUP BY customer
),

cohort_orders AS (
  SELECT
    f.cohort_month,
    COUNT(DISTINCT c.id) AS total_orders
  FROM `your-project.stripe.stg_stripe_charges` c
  JOIN first_purchase f ON c.customer = f.customer
  WHERE c.status = 'succeeded'
  GROUP BY 1
),

cohort_refunds AS (
  SELECT
    f.cohort_month,
    COUNT(DISTINCT r.id) AS refund_count
  FROM `your-project.stripe.stg_stripe_refunds` r
  JOIN `your-project.stripe.stg_stripe_charges` c ON r.charge_id = c.id
  JOIN first_purchase f ON c.customer = f.customer
  GROUP BY 1
),

cohort_disputes AS (
  SELECT
    f.cohort_month,
    COUNT(DISTINCT d.id) AS dispute_count
  FROM `your-project.stripe.stg_stripe_disputes` d
  JOIN `your-project.stripe.stg_stripe_charges` c ON d.charge_id = c.id
  JOIN first_purchase f ON c.customer = f.customer
  GROUP BY 1
)

SELECT
  o.cohort_month AS cohort_month_date,
  FORMAT_DATE('%b %Y', o.cohort_month) AS cohort_label,
  o.total_orders,
  COALESCE(r.refund_count, 0) AS refund_count,
  COALESCE(d.dispute_count, 0) AS dispute_count,
  ROUND(COALESCE(r.refund_count, 0) / o.total_orders, 4) AS refund_rate,
  ROUND(COALESCE(d.dispute_count, 0) / o.total_orders, 4) AS dispute_rate,
  ROUND((COALESCE(r.refund_count, 0) + COALESCE(d.dispute_count, 0)) / o.total_orders, 4) AS total_loss_rate
FROM cohort_orders o
LEFT JOIN cohort_refunds r ON o.cohort_month = r.cohort_month
LEFT JOIN cohort_disputes d ON o.cohort_month = d.cohort_month
ORDER BY o.cohort_month;
