CREATE OR REPLACE VIEW `your-project.staging.stg_cc_orders_summary`
AS WITH combined AS (
  SELECT
    date,
    source,
    orders_count,
    gross_revenue,
    net_revenue,
    refund_amount,
    shipping,
    sales_tax,
    avg_ticket,
    declines_count,
    upsells_count,
    upsell_revenue,
    partial_count,
    partial_count + orders_count AS checkout_initiated,
    orders_count AS checkout_completed,
    ingested_at
  FROM `your-project.raw.historical_cc_orders_summary`

  UNION ALL

  SELECT
    date,
    source,
    orders_count,
    gross_revenue,
    net_revenue,
    refund_amount,
    shipping,
    sales_tax,
    avg_ticket,
    declines_count,
    upsells_count,
    upsell_revenue,
    partial_count,
    partial_count + orders_count AS checkout_initiated,
    orders_count AS checkout_completed,
    ingested_at
  FROM `your-project.raw.daily_cc_orders_summary`
)

SELECT * FROM combined
QUALIFY ROW_NUMBER() OVER (PARTITION BY date ORDER BY ingested_at DESC) = 1;
