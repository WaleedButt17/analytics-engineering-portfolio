CREATE OR REPLACE VIEW `your-project.staging.stg_cc_orders`
AS WITH combined AS (
  SELECT
    DATE(date_created) AS order_date,
    order_id,
    actual_order_id,
    customer_id,
    campaign_id,
    campaign_name,
    order_type,
    order_status,
    country,
    currency_code,
    total_amount,
    price,
    base_shipping,
    discount_price,
    sales_tax,
    total_discount,
    refund_remaining,
    item_count,
    item_names,
    item_skus,
    utm_source,
    utm_medium,
    utm_campaign,
    utm_content,
    utm_term,
    pay_source,
    has_upsell,
    is_decline_save,
    funnel_reference_id,
    date_created,
    date_updated,
    'historical' AS data_source
  FROM `your-project.raw.historical_cc_orders`
  WHERE order_status IN ('COMPLETE', 'REFUNDED')
  UNION ALL
  SELECT
    DATE(date_created) AS order_date,
    order_id,
    actual_order_id,
    customer_id,
    campaign_id,
    campaign_name,
    order_type,
    order_status,
    country,
    currency_code,
    total_amount,
    price,
    base_shipping,
    discount_price,
    sales_tax,
    total_discount,
    refund_remaining,
    item_count,
    item_names,
    item_skus,
    utm_source,
    utm_medium,
    utm_campaign,
    utm_content,
    utm_term,
    pay_source,
    has_upsell,
    is_decline_save,
    funnel_reference_id,
    date_created,
    date_updated,
    'daily' AS data_source
  FROM `your-project.raw.daily_cc_orders`
  WHERE order_status IN ('COMPLETE', 'REFUNDED')
)
SELECT *,
  CASE WHEN order_status = 'REFUNDED' THEN refund_remaining ELSE 0 END AS refund_amount,
  total_amount - CASE WHEN order_status = 'REFUNDED' THEN refund_remaining ELSE 0 END AS net_amount
FROM combined
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY order_id
  ORDER BY date_updated DESC, data_source DESC
) = 1;
