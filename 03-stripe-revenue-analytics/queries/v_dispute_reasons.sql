CREATE OR REPLACE VIEW `your-project.stripe.v_dispute_reasons` AS
SELECT
  created_date,
  COALESCE(reason, 'Unknown') AS dispute_reason,
  id AS dispute_id
FROM `your-project.stripe.stg_stripe_disputes`;
