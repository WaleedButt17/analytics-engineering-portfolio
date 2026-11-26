CREATE OR REPLACE VIEW `your-project.stripe.v_refund_by_sku` AS
SELECT
  c.created_date,
  COALESCE(c.metadata_product_sku, 'Unknown') AS sku,
  c.id AS charge_id,
  CASE WHEN r.id IS NOT NULL THEN 1 ELSE 0 END AS is_refunded,
  r.id AS refund_id
FROM `your-project.stripe.stg_stripe_charges` c
LEFT JOIN `your-project.stripe.stg_stripe_refunds` r ON r.charge_id = c.id
WHERE c.status = 'succeeded';
