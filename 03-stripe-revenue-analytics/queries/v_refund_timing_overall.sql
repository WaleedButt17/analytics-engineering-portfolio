CREATE OR REPLACE VIEW `your-project.stripe.v_refund_timing_overall` AS
SELECT
  c.created_date,
  r.id AS refund_id,
  CASE
    WHEN DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) BETWEEN 0 AND 3 THEN 1
    WHEN DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) BETWEEN 4 AND 14 THEN 2
    WHEN DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) BETWEEN 15 AND 21 THEN 3
    ELSE 4
  END AS sort_order,
  CASE
    WHEN DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) BETWEEN 0 AND 3 THEN '0-3 (buyer remorse)'
    WHEN DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) BETWEEN 4 AND 14 THEN '4-14 (processing delay)'
    WHEN DATE_DIFF(DATE(TIMESTAMP_SECONDS(r.created)), c.created_date, DAY) BETWEEN 15 AND 21 THEN '15-21 (product confusion)'
    ELSE '21+ (product dissatisfaction)'
  END AS days_after_purchase
FROM `your-project.stripe.stg_stripe_refunds` r
JOIN `your-project.stripe.stg_stripe_charges` c ON r.charge_id = c.id
WHERE c.status = 'succeeded';
