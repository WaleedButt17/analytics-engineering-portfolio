CREATE OR REPLACE VIEW `your-project.marts.mart_subscriber_level`
AS SELECT
  CAST(subscription_id AS STRING) AS subscription_id,
  'loop' AS platform,
  CAST(UPPER(country_code) AS STRING) AS country_code,
  created_date,
  cancelled_date,
  paused_date,
  SAFE_DIVIDE(
    CAST(total_line_item_discounted_price AS FLOAT64),
    NULLIF(CAST(billing_interval_count AS FLOAT64), 0)
  ) AS monthly_value,
  CAST(status AS STRING) AS status,
  CAST(cancellation_reason AS STRING) AS cancellation_reason,
  CAST(next_billing_date AS DATE) AS next_billing_date,
  CAST(billing_interval_count AS INT64) AS billing_interval_count,
  CAST(billing_interval AS STRING) AS billing_interval
FROM `your-project.staging.stg_loop_subscriptions`
WHERE created_date IS NOT NULL

UNION ALL

SELECT
  CAST(purchase_id AS STRING),
  'checkoutchamp',
  CAST(UPPER(country) AS STRING),
  DATE(date_created),
  CAST(last_cancellation_date AS DATE),
  CAST(NULL AS DATE),
  SAFE_DIVIDE(
    CAST(price AS FLOAT64),
    SAFE_DIVIDE(CAST(billing_interval_days AS FLOAT64), 30.0)
  ),
  CAST(CASE
    WHEN status = 'ACTIVE' THEN 'ACTIVE'
    WHEN status IN ('RECYCLE_FAILED', 'RECYCLE_BILLING') THEN 'ACTIVE'
    WHEN status IN ('CANCELLED', 'COMPLETE') THEN 'CANCELLED'
    WHEN status = 'PAUSED' THEN 'PAUSED'
    ELSE status
  END AS STRING),
  CAST(cancel_reason AS STRING),
  CAST(DATE(next_bill_date) AS DATE),
  CAST(CAST(billing_interval_days AS FLOAT64) / 30.0 AS INT64),
  'DAY'
FROM `your-project.staging.stg_cc_purchases`
WHERE date_created IS NOT NULL;
