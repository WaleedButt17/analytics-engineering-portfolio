CREATE OR REPLACE VIEW `your-project.stripe.v_cohort_refund_timing` AS
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

refund_timing AS (
  SELECT
    f.cohort_month,
    DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) AS days_to_refund,
    r.id AS refund_id
  FROM `your-project.stripe.stg_stripe_refunds` r
  JOIN `your-project.stripe.stg_stripe_charges` c ON r.charge_id = c.id
  JOIN first_purchase f ON c.customer = f.customer
)

SELECT
  o.cohort_month AS cohort_month_date,
  FORMAT_DATE('%b %Y', o.cohort_month) AS cohort_label,
  o.total_orders,
  ROUND(COUNTIF(t.days_to_refund BETWEEN 0 AND 3) / o.total_orders, 4) AS refund_0_3_days,
  ROUND(COUNTIF(t.days_to_refund BETWEEN 4 AND 14) / o.total_orders, 4) AS refund_4_14_days,
  ROUND(COUNTIF(t.days_to_refund BETWEEN 15 AND 21) / o.total_orders, 4) AS refund_15_21_days,
  ROUND(COUNTIF(t.days_to_refund > 21) / o.total_orders, 4) AS refund_21plus_days
FROM cohort_orders o
LEFT JOIN refund_timing t ON o.cohort_month = t.cohort_month
GROUP BY
  o.cohort_month,
  FORMAT_DATE('%b %Y', o.cohort_month),
  o.total_orders
ORDER BY o.cohort_month;
