CREATE OR REPLACE VIEW `your-project.staging.stg_cc_purchases`
AS WITH combined AS (
  SELECT *, 'historical' AS data_source FROM `your-project.raw.historical_cc_purchases`
  UNION ALL
  SELECT *, 'daily' AS data_source FROM `your-project.raw.daily_cc_purchases`
)
SELECT
  DATE(date_created) AS purchase_date,
  purchase_id,
  actual_purchase_id,
  customer_id,
  order_id,
  campaign_id,
  product_name,
  display_name,
  status,
  cancel_reason,
  price,
  shipping_price,
  billing_cycle_type,
  billing_interval_days,
  billing_cycle_number,
  next_bill_date,
  last_cancellation_date,
  last_activation_date,
  total_billed,
  total_refunded,
  product_qty,
  merchant_id,
  merchant,
  currency_code,
  UPPER(country) AS country,
  date_created,
  date_updated,
  cancellation_scheduled,
  pause_scheduled
FROM combined
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY purchase_id
  ORDER BY date_updated DESC, data_source ASC, actual_purchase_id DESC
) = 1;
