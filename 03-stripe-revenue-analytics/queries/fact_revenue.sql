CREATE OR REPLACE VIEW `your-project.stripe.fact_revenue` AS
WITH
refund_agg AS (
  SELECT
    c.id AS charge_id,
    SUM(bt.net) AS total_refund_net
  FROM `your-project.stripe.stg_stripe_charges` c
  JOIN `your-project.stripe.stg_stripe_refunds` r
    ON c.id = r.charge_id
  JOIN `your-project.stripe.stg_stripe_balance_transactions` bt
    ON r.balance_transaction = bt.id
  WHERE bt.type IN ('refund', 'payment_refund', 'refund_failure')
  GROUP BY 1
),

adjustment_agg AS (
  SELECT
    d.charge_id,
    SUM(bt.net) AS total_adjustment_net
  FROM `your-project.stripe.stg_stripe_balance_transactions` bt
  JOIN `your-project.stripe.stg_stripe_disputes` d
    ON bt.source = d.id
  WHERE bt.type = 'adjustment'
  GROUP BY 1
)

SELECT
  c.id AS charge_id,
  c.created_date,
  c.customer,
  COALESCE(c.metadata_customer_email, c.billing_details_email) AS customer_email,
  COALESCE(c.metadata_customer_name, c.billing_details_name) AS customer_name,
  c.metadata_customer_email AS metadata_email_raw,
  c.billing_details_email AS billing_email_raw,
  c.metadata_product_sku AS sku,
  c.metadata_product_id AS product_id,
  c.metadata_coupon_code AS coupon_code,
  SAFE_CAST(c.metadata_discount_amount AS FLOAT64) AS discount_amount,
  c.payment_method_details_type AS payment_type,
  c.payment_method_details_card_brand AS card_brand,
  c.payment_method_details_card_funding AS card_funding,
  c.payment_method_details_card_wallet AS wallet_type,
  c.currency,
  c.status,
  c.refunded AS is_refunded,
  IF(c.status = 'failed', true, false) AS is_failed,
  c.disputed AS is_disputed,
  c.failure_code,
  c.failure_message,
  CASE
    WHEN c.disputed = true AND c.refunded = true THEN 'Disputed & Refunded'
    WHEN c.disputed = true THEN 'Disputed'
    WHEN c.refunded = true THEN 'Refunded'
    WHEN c.status = 'failed' THEN 'Failed'
    ELSE 'Clean'
  END AS charge_type,
  ROUND(c.amount / 100.0, 2) AS gross_amount,
  ROUND((c.amount + COALESCE(SAFE_CAST(c.metadata_discount_amount AS FLOAT64), 0) * 100) / 100.0, 2) AS list_price,
  ROUND(c.amount_captured / 100.0, 2) AS amount_captured,
  ROUND(c.amount_refunded / 100.0, 2) AS refunded_amount,
  ROUND(bt.fee / 100.0, 2) AS stripe_fee,
  ROUND(bt.net / 100.0, 2) AS net_after_fees,
  ROUND(COALESCE(r.total_refund_net, 0) / 100.0, 2) AS refund_net,
  ROUND(COALESCE(a.total_adjustment_net, 0) / 100.0, 2) AS adjustment_net,
  ROUND(
    (COALESCE(bt.net, 0) + COALESCE(r.total_refund_net, 0) + COALESCE(a.total_adjustment_net, 0)) / 100.0
  , 2) AS true_net,
  c.ingested_at

FROM `your-project.stripe.stg_stripe_charges` c
LEFT JOIN `your-project.stripe.stg_stripe_balance_transactions` bt
  ON c.balance_transaction = bt.id
LEFT JOIN refund_agg r ON c.id = r.charge_id
LEFT JOIN adjustment_agg a ON c.id = a.charge_id;
