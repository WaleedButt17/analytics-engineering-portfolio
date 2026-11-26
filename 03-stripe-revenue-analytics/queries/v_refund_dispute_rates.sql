CREATE OR REPLACE VIEW `your-project.stripe.v_refund_dispute_rates` AS
WITH daily_events AS (
  SELECT
    created_date,
    COUNT(DISTINCT CASE WHEN event_type = 'refund' THEN refund_id END) AS refund_count,
    COUNT(DISTINCT CASE WHEN event_type = 'dispute' THEN charge_id END) AS dispute_count,
    SUM(CASE WHEN dispute_status = 'lost' THEN refunded_amount ELSE 0 END) AS chargeback_amount,
    COUNT(DISTINCT CASE WHEN dispute_status = 'lost' THEN charge_id END) AS chargeback_count
  FROM `your-project.stripe.view_refund_dispute_tracking`
  GROUP BY 1
),

daily_orders AS (
  SELECT
    created_date,
    COUNT(DISTINCT charge_id) AS total_orders
  FROM `your-project.stripe.fact_revenue`
  WHERE status = 'succeeded'
  GROUP BY 1
),

daily_refunds AS (
  SELECT
    created_date,
    ROUND(SUM(ABS(amount)) / 100.0, 2) AS refund_amount
  FROM `your-project.stripe.stg_stripe_balance_transactions`
  WHERE type = 'payment_refund'
  GROUP BY 1
)

SELECT
  o.created_date,
  o.total_orders,
  COALESCE(e.refund_count, 0) AS refund_count,
  ROUND(COALESCE(r.refund_amount, 0) - COALESCE(e.chargeback_amount, 0), 2) AS refund_amount,
  COALESCE(e.dispute_count, 0) AS dispute_count,
  COALESCE(e.chargeback_amount, 0) AS chargeback_amount,
  COALESCE(e.chargeback_count, 0) AS chargeback_count,
  ROUND(COALESCE(e.refund_count, 0) / NULLIF(o.total_orders, 0), 4) AS refund_rate,
  ROUND(COALESCE(e.dispute_count, 0) / NULLIF(o.total_orders, 0), 4) AS dispute_rate,
  ROUND(COALESCE(e.chargeback_count, 0) / NULLIF(o.total_orders, 0), 4) AS chargeback_rate
FROM daily_orders o
LEFT JOIN daily_events e ON o.created_date = e.created_date
LEFT JOIN daily_refunds r ON o.created_date = r.created_date;
