CREATE OR REPLACE VIEW `your-project.marts.mart_utm_daily`
AS WITH shopify_sessions AS (
  SELECT
    session_date AS date,
    COALESCE(utm_source, '(none)') AS utm_source,
    COALESCE(utm_medium, '(none)') AS utm_medium,
    COALESCE(utm_campaign, '(none)') AS utm_campaign,
    country,
    SUM(sessions) AS sessions,
    SUM(sessions_with_cart_additions) AS add_to_carts,
    SUM(sessions_that_reached_checkout) AS checkout_initiated,
    SUM(sessions_that_completed_checkout) AS checkout_completed
  FROM `your-project.staging.stg_shopify_sessions`
  GROUP BY session_date, utm_source, utm_medium, utm_campaign, country
),

shopify_orders AS (
  SELECT
    order_date AS date,
    COALESCE(utm_source, '(none)') AS utm_source,
    COALESCE(utm_medium, '(none)') AS utm_medium,
    COALESCE(utm_campaign, '(none)') AS utm_campaign,
    country,
    COUNT(DISTINCT order_id) AS orders,
    SUM(gross_sales) AS gross_revenue,
    SUM(net_sales) AS net_revenue,
    SUM(refunds) AS refunds,
    SUM(discounts) AS discounts
  FROM `your-project.staging.stg_shopify_orders`
  GROUP BY order_date, utm_source, utm_medium, utm_campaign, country
),

cc_orders AS (
  SELECT
    order_date AS date,
    COALESCE(utm_source, '(none)') AS utm_source,
    COALESCE(utm_medium, '(none)') AS utm_medium,
    COALESCE(utm_campaign, '(none)') AS utm_campaign,
    COALESCE(cm.name, 'Other') AS country,
    COUNT(DISTINCT CASE WHEN order_status = 'COMPLETE' THEN order_id END) AS orders,
    SUM(CASE WHEN order_status = 'COMPLETE' THEN total_amount ELSE 0 END) AS gross_revenue,
    SUM(CASE WHEN order_status = 'COMPLETE' THEN net_amount ELSE 0 END) AS net_revenue,
    0 AS refunds,
    0 AS discounts
  FROM `your-project.staging.stg_cc_orders` o
  LEFT JOIN `your-project.raw.country_codes` cm ON UPPER(o.country) = cm.code
  GROUP BY order_date, utm_source, utm_medium, utm_campaign, country
),

orders_combined AS (
  SELECT
    date, utm_source, utm_medium, utm_campaign, country,
    SUM(orders) AS orders,
    SUM(gross_revenue) AS gross_revenue,
    SUM(net_revenue) AS net_revenue,
    SUM(refunds) AS refunds,
    SUM(discounts) AS discounts
  FROM (SELECT * FROM shopify_orders UNION ALL SELECT * FROM cc_orders)
  GROUP BY date, utm_source, utm_medium, utm_campaign, country
)

SELECT
  COALESCE(s.date, o.date) AS date,
  COALESCE(s.utm_source, o.utm_source) AS utm_source,
  COALESCE(s.utm_medium, o.utm_medium) AS utm_medium,
  COALESCE(s.utm_campaign, o.utm_campaign) AS utm_campaign,
  COALESCE(s.country, o.country) AS country,
  COALESCE(s.sessions, 0) AS sessions,
  COALESCE(s.add_to_carts, 0) AS add_to_carts,
  COALESCE(s.checkout_initiated, 0) AS checkout_initiated,
  COALESCE(s.checkout_completed, 0) AS checkout_completed,
  COALESCE(o.orders, 0) AS orders,
  COALESCE(o.gross_revenue, 0) AS gross_revenue,
  COALESCE(o.net_revenue, 0) AS net_revenue,
  COALESCE(o.refunds, 0) AS refunds,
  COALESCE(o.discounts, 0) AS discounts,
  SAFE_DIVIDE(COALESCE(o.net_revenue, 0), NULLIF(COALESCE(o.orders, 0), 0)) AS aov,
  SAFE_DIVIDE(COALESCE(o.orders, 0), NULLIF(COALESCE(s.sessions, 0), 0)) AS cvr
FROM shopify_sessions s
FULL OUTER JOIN orders_combined o
  ON s.date = o.date
  AND s.utm_source = o.utm_source
  AND s.utm_medium = o.utm_medium
  AND s.utm_campaign = o.utm_campaign
  AND s.country = o.country;
