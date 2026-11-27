CREATE OR REPLACE VIEW `your-project.staging.stg_loop_subscriptions`
AS SELECT
  DATE(ingested_at) AS activity_date,
  DATE(created_at) AS created_date,
  DATE(cancelled_at) AS cancelled_date,
  DATE(paused_at) AS paused_date,
  store,
  subscription_id,
  shopify_id,
  customer_id,
  customer_shopify_id,
  customer_email,
  status,
  cancellation_reason,
  cancellation_comment,
  completed_orders_count,
  total_line_item_price,
  total_line_item_discounted_price,
  delivery_price,
  currency_code,
  billing_interval,
  billing_interval_count,
  next_billing_date_epoch,
  DATE(TIMESTAMP_SECONDS(next_billing_date_epoch)) AS next_billing_date,
  last_payment_status,
  is_prepaid,
  is_marked_for_cancellation,
  UPPER(country_code) AS country_code,
  province_code,
  product_shopify_id,
  variant_shopify_id,
  product_title,
  variant_title,
  sku,
  price,
  quantity,
  delivery_method,
  ingested_at,
  updated_at
FROM `your-project.raw.daily_loop_subscriptions`
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY subscription_id
  ORDER BY ingested_at DESC, updated_at DESC
) = 1;
