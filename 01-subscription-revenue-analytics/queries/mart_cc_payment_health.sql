CREATE OR REPLACE VIEW `your-project.marts.mart_cc_payment_health`
AS WITH billing_cycles AS (
  SELECT
    DATE(date_created) AS transaction_date,
    country,
    order_id,
    billing_cycle_number,
    MAX(CASE WHEN response_type = 'SUCCESS' THEN 1 ELSE 0 END) AS cycle_succeeded,
    MIN(CASE WHEN recycle_number IS NULL OR recycle_number = 0 THEN response_type END) AS first_attempt_response
  FROM `your-project.staging.stg_cc_transactions`
  GROUP BY DATE(date_created), country, order_id, billing_cycle_number
),

daily_summary AS (
  SELECT
    transaction_date,
    country,
    COUNT(*) AS total_billing_cycles,
    COUNT(CASE WHEN first_attempt_response = 'SUCCESS' THEN 1 END) AS first_attempt_success,
    COUNT(CASE WHEN cycle_succeeded = 1 THEN 1 END) AS eventually_succeeded
  FROM billing_cycles
  GROUP BY transaction_date, country
)

SELECT
  transaction_date,
  country,
  total_billing_cycles,
  first_attempt_success,
  eventually_succeeded,
  SAFE_DIVIDE(first_attempt_success, total_billing_cycles) AS payment_success_rate_first_attempt,
  SAFE_DIVIDE(eventually_succeeded, total_billing_cycles) AS payment_success_rate_all_attempts,
  SAFE_DIVIDE(eventually_succeeded - first_attempt_success, total_billing_cycles) AS dunning_recovery_rate
FROM daily_summary;
