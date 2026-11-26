CREATE OR REPLACE VIEW `your-project.stripe.view_refund_dispute_tracking` AS
SELECT
  r.id AS refund_id,
  c.id AS charge_id,
  r.created_date,
  c.customer,
  COALESCE(c.metadata_customer_email, c.billing_details_email) AS customer_email,
  COALESCE(c.metadata_customer_name, c.billing_details_name) AS customer_name,
  c.metadata_product_sku AS sku,
  c.currency,
  ROUND(c.amount / 100.0, 2) AS gross_amount,
  ROUND(r.amount / 100.0, 2) AS refunded_amount,
  r.reason AS refund_reason,
  r.status AS refund_status,
  'refund' AS event_type,
  NULL AS dispute_reason,
  NULL AS dispute_status,
  NULL AS failure_code,
  NULL AS failure_message
FROM `your-project.stripe.stg_stripe_refunds` r
JOIN `your-project.stripe.stg_stripe_charges` c
  ON r.charge_id = c.id

UNION ALL

SELECT
  NULL AS refund_id,
  c.id AS charge_id,
  c.created_date,
  c.customer,
  COALESCE(c.metadata_customer_email, c.billing_details_email) AS customer_email,
  COALESCE(c.metadata_customer_name, c.billing_details_name) AS customer_name,
  c.metadata_product_sku AS sku,
  c.currency,
  ROUND(c.amount / 100.0, 2) AS gross_amount,
  NULL AS refunded_amount,
  NULL AS refund_reason,
  NULL AS refund_status,
  'failed_charge' AS event_type,
  NULL AS dispute_reason,
  NULL AS dispute_status,
  COALESCE(CASE c.failure_code
    WHEN 'card_declined' THEN 'Card Declined'
    WHEN 'payment_intent_payment_attempt_failed' THEN 'Attempt Failed'
    WHEN 'payment_intent_payment_attempt_expired' THEN 'Attempt Failed'
    WHEN 'payment_intent_authentication_failure' THEN 'Authentication Failed'
    WHEN 'incorrect_number' THEN 'Incorrect Card Number'
    WHEN 'incorrect_cvc' THEN 'Incorrect CVC'
    WHEN 'invalid_cvc' THEN 'Invalid CVC'
    WHEN 'expired_card' THEN 'Expired Card'
    WHEN 'payment_method_provider_decline' THEN 'Provider Declined'
    WHEN 'payment_method_customer_decline' THEN 'Customer Declined'
    WHEN 'processing_error' THEN 'Processing Error'
    ELSE 'Payment Failed'
  END, 'Payment Failed') AS failure_code,
  c.failure_message
FROM `your-project.stripe.stg_stripe_charges` c
WHERE c.status = 'failed'

UNION ALL

SELECT
  NULL AS refund_id,
  c.id AS charge_id,
  d.created_date,
  c.customer,
  COALESCE(c.metadata_customer_email, c.billing_details_email) AS customer_email,
  COALESCE(c.metadata_customer_name, c.billing_details_name) AS customer_name,
  c.metadata_product_sku AS sku,
  c.currency,
  ROUND(c.amount / 100.0, 2) AS gross_amount,
  ROUND(d.amount / 100.0, 2) AS refunded_amount,
  NULL AS refund_reason,
  NULL AS refund_status,
  'dispute' AS event_type,
  d.reason AS dispute_reason,
  d.status AS dispute_status,
  NULL AS failure_code,
  NULL AS failure_message
FROM `your-project.stripe.stg_stripe_disputes` d
LEFT JOIN `your-project.stripe.stg_stripe_charges` c
  ON d.charge_id = c.id;
