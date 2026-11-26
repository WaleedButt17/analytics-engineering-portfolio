CREATE OR REPLACE VIEW `your-project.stripe.v_sku_performance` AS
WITH orders AS (
  SELECT
    c.created_date,
    COALESCE(c.metadata_product_sku, 'Unknown') AS sku,
    COUNT(DISTINCT f.charge_id) AS total_orders,
    ROUND(SUM(f.gross_amount), 2) AS gross_revenue,
    ROUND(SUM(f.true_net), 2) AS net_revenue
  FROM `your-project.stripe.fact_revenue` f
  JOIN `your-project.stripe.stg_stripe_charges` c ON f.charge_id = c.id
  WHERE c.status = 'succeeded'
  GROUP BY 1, 2
),
refunds AS (
  SELECT
    c.created_date,
    COALESCE(c.metadata_product_sku, 'Unknown') AS sku,
    COUNT(DISTINCT r.id) AS refund_count
  FROM `your-project.stripe.stg_stripe_refunds` r
  JOIN `your-project.stripe.stg_stripe_charges` c ON r.charge_id = c.id
  GROUP BY 1, 2
),
disputes AS (
  SELECT
    c.created_date,
    COALESCE(c.metadata_product_sku, 'Unknown') AS sku,
    COUNT(DISTINCT d.id) AS dispute_count
  FROM `your-project.stripe.stg_stripe_disputes` d
  JOIN `your-project.stripe.stg_stripe_charges` c ON d.charge_id = c.id
  GROUP BY 1, 2
)
SELECT
  o.created_date,
  o.sku,
  o.total_orders,
  o.gross_revenue,
  o.net_revenue,
  COALESCE(r.refund_count, 0) AS refund_count,
  COALESCE(d.dispute_count, 0) AS dispute_count
FROM orders o
LEFT JOIN refunds r ON o.sku = r.sku AND o.created_date = r.created_date
LEFT JOIN disputes d ON o.sku = d.sku AND o.created_date = d.created_date
ORDER BY o.gross_revenue DESC;
