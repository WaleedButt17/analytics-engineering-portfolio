CREATE OR REPLACE VIEW `your-project.stripe.v_cohort_repeat_purchase_rate` AS
WITH cohort_base AS (
  SELECT
    customer,
    DATE_TRUNC(MIN(CASE WHEN is_repeat = 0 THEN created_date END), MONTH) AS cohort_month
  FROM `your-project.stripe.v_first_repeat_revenue`
  GROUP BY customer
),

repeat_flags AS (
  SELECT
    customer,
    MAX(is_repeat) AS has_repeated
  FROM `your-project.stripe.v_first_repeat_revenue`
  GROUP BY customer
)

SELECT
  b.cohort_month AS cohort_month_date,
  FORMAT_DATE('%b %Y', b.cohort_month) AS cohort_label,
  COUNT(DISTINCT b.customer) AS total_customers,
  COUNT(DISTINCT CASE WHEN r.has_repeated = 1 THEN b.customer END) AS repeat_customers,
  ROUND(
    COUNT(DISTINCT CASE WHEN r.has_repeated = 1 THEN b.customer END)
    / COUNT(DISTINCT b.customer), 4
  ) AS repeat_purchase_rate
FROM cohort_base b
JOIN repeat_flags r ON b.customer = r.customer
GROUP BY 1, 2
ORDER BY 1;
