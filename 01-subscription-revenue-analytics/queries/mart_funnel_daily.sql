CREATE OR REPLACE VIEW `your-project.marts.mart_funnel_daily`
AS WITH

meta AS (
  SELECT
    ad_date AS date,
    COALESCE(cm.name, 'Other') AS country,
    SUM(impressions) AS impressions,
    SUM(link_clicks) AS link_clicks,
    SUM(unique_outbound_clicks) AS unique_outbound_clicks,
    SUM(spend) AS spend,
    SUM(reach) AS reach,
    SUM(landing_page_views) AS landing_page_views,
    AVG(frequency) AS frequency,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS cpm,
    SAFE_DIVIDE(SUM(link_clicks), SUM(impressions)) AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(link_clicks)) AS cpc
  FROM `your-project.staging.stg_meta_ads` m
  LEFT JOIN `your-project.raw.country_codes` cm ON m.country = cm.code
  GROUP BY ad_date, country
),

sessions AS (
  SELECT
    session_date AS date,
    store AS store_name,
    country,
    SUM(sessions) AS sessions,
    SUM(sessions_with_cart_additions) AS add_to_carts,
    SUM(sessions_that_reached_checkout) AS shopify_checkout_initiated,
    SUM(sessions_that_completed_checkout) AS shopify_checkout_completed
  FROM `your-project.staging.stg_shopify_sessions`
  GROUP BY session_date, store, country
),

sessions_by_country AS (
  SELECT
    s.date,
    s.country,
    SUM(s.sessions) AS sessions,
    SUM(s.add_to_carts) AS add_to_carts,
    SUM(s.shopify_checkout_initiated) AS shopify_checkout_initiated,
    SUM(s.shopify_checkout_completed) AS shopify_checkout_completed
  FROM sessions s
  GROUP BY s.date, s.country
),

orders_deduped AS (
  SELECT
    order_id,
    MIN(order_date) AS order_date,
    MAX(store_name) AS store_name,
    MAX(country) AS country,
    SUM(gross_sales) AS gross_sales,
    SUM(CASE WHEN line_type = 'product' THEN net_sales + refunds ELSE 0 END) AS net_revenue,
    ABS(SUM(refunds)) AS refund_amount,
    SUM(discounts) AS discounts,
    SUM(taxes) AS taxes
  FROM `your-project.staging.stg_shopify_orders`
  WHERE line_type = 'product'
  GROUP BY order_id
),

shopify_orders AS (
  SELECT
    order_date AS date,
    store_name,
    country,
    COUNT(DISTINCT order_id) AS orders,
    SUM(gross_sales) AS gross_revenue,
    SUM(net_revenue) AS net_revenue,
    SUM(refund_amount) AS refund_amount,
    SUM(discounts) AS discounts,
    SUM(taxes) AS taxes
  FROM orders_deduped
  GROUP BY order_date, store_name, country
),

cc_orders AS (
  SELECT
    order_date AS date,
    COALESCE(cm.name, 'Other') AS country,
    COUNT(DISTINCT CASE WHEN order_status = 'COMPLETE' THEN order_id END) AS orders,
    SUM(CASE WHEN order_status = 'COMPLETE' THEN total_amount ELSE 0 END) AS gross_revenue,
    SUM(CASE WHEN order_status = 'COMPLETE' THEN net_amount ELSE 0 END) AS net_revenue,
    SUM(CASE WHEN order_status = 'COMPLETE' THEN refund_amount ELSE 0 END) AS refund_amount,
    SUM(CASE WHEN order_status = 'COMPLETE' THEN sales_tax ELSE 0 END) AS taxes
  FROM `your-project.staging.stg_cc_orders` o
  LEFT JOIN `your-project.raw.country_codes` cm ON UPPER(o.country) = cm.code
  GROUP BY order_date, country
),

cc_orders_total AS (
  SELECT
    order_date AS date,
    COUNT(DISTINCT order_id) AS cc_orders_total
  FROM `your-project.staging.stg_cc_orders`
  WHERE order_status = 'COMPLETE'
  GROUP BY order_date
),

cc_summary AS (
  SELECT
    s.date,
    COALESCE(t.cc_orders_total, 0) AS cc_orders_total,
    SUM(s.checkout_initiated) AS cc_checkout_initiated,
    SUM(s.checkout_completed) AS cc_checkout_completed,
    SUM(s.declines_count) AS cc_declines,
    SUM(s.upsells_count) AS cc_upsells,
    SUM(s.upsell_revenue) AS cc_upsell_revenue,
    SUM(s.gross_revenue) AS cc_gross_revenue_total,
    SUM(s.net_revenue) AS cc_net_revenue_total,
    SUM(s.shipping) AS cc_shipping,
    SUM(s.sales_tax) AS cc_sales_tax
  FROM `your-project.staging.stg_cc_orders_summary` s
  LEFT JOIN cc_orders_total t ON s.date = t.date
  GROUP BY s.date, t.cc_orders_total
),

shopify_spine AS (
  SELECT DISTINCT date, store_name, country FROM sessions
  UNION DISTINCT
  SELECT DISTINCT date, store_name, country FROM shopify_orders
),

cc_spine AS (
  SELECT DISTINCT date, country FROM cc_orders
),

combined_spine AS (
  SELECT DISTINCT date, store_name, country FROM sessions
  UNION DISTINCT
  SELECT DISTINCT date, store_name, country FROM shopify_orders
),

store_counts AS (
  SELECT date, country, COUNT(DISTINCT store_name) AS n_stores
  FROM combined_spine
  GROUP BY date, country
),

shopify AS (
  SELECT
    sp.date, sp.store_name, sp.country, 'shopify' AS platform,
    SAFE_DIVIDE(m.impressions, sc.n_stores) AS impressions,
    SAFE_DIVIDE(m.link_clicks, sc.n_stores) AS link_clicks,
    SAFE_DIVIDE(m.unique_outbound_clicks, sc.n_stores) AS unique_outbound_clicks,
    SAFE_DIVIDE(m.spend, sc.n_stores) AS spend,
    SAFE_DIVIDE(m.reach, sc.n_stores) AS reach,
    SAFE_DIVIDE(m.landing_page_views, sc.n_stores) AS landing_page_views,
    m.frequency, m.cpm, m.ctr, m.cpc,
    s.sessions, s.add_to_carts, s.shopify_checkout_initiated, s.shopify_checkout_completed,
    so.orders, so.gross_revenue, so.net_revenue, so.refund_amount, so.discounts, so.taxes,
    NULL AS cc_checkout_initiated, NULL AS cc_checkout_completed,
    NULL AS cc_declines, NULL AS cc_upsells, NULL AS cc_upsell_revenue, NULL AS cc_shipping
  FROM shopify_spine sp
  LEFT JOIN meta m ON sp.date = m.date AND sp.country = m.country
  LEFT JOIN sessions s ON sp.date = s.date AND sp.store_name = s.store_name AND sp.country = s.country
  LEFT JOIN shopify_orders so ON sp.date = so.date AND sp.store_name = so.store_name AND sp.country = so.country
  LEFT JOIN store_counts sc ON sp.date = sc.date AND sp.country = sc.country
),

cc AS (
  SELECT
    sp.date, CAST(NULL AS STRING) AS store_name, sp.country, 'checkoutchamp' AS platform,
    NULL AS impressions, NULL AS link_clicks, NULL AS unique_outbound_clicks,
    NULL AS spend, NULL AS reach, NULL AS landing_page_views, NULL AS frequency,
    NULL AS cpm, NULL AS ctr, NULL AS cpc,
    sbc.sessions, sbc.add_to_carts,
    NULL AS shopify_checkout_initiated, NULL AS shopify_checkout_completed,
    co.orders, co.gross_revenue, co.net_revenue, co.refund_amount,
    NULL AS discounts, co.taxes,
    SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_checkout_initiated AS cc_checkout_initiated,
    SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_checkout_completed AS cc_checkout_completed,
    SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_declines AS cc_declines,
    SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_upsells AS cc_upsells,
    SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_upsell_revenue AS cc_upsell_revenue,
    SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_shipping AS cc_shipping
  FROM cc_spine sp
  LEFT JOIN cc_orders co ON sp.date = co.date AND sp.country = co.country
  LEFT JOIN cc_summary cs ON sp.date = cs.date
  LEFT JOIN sessions_by_country sbc ON sp.date = sbc.date AND sp.country = sbc.country
),

combined AS (
  SELECT
    sp.date, sp.store_name, sp.country, 'combined' AS platform,
    SAFE_DIVIDE(m.impressions, sc.n_stores) AS impressions,
    SAFE_DIVIDE(m.link_clicks, sc.n_stores) AS link_clicks,
    SAFE_DIVIDE(m.unique_outbound_clicks, sc.n_stores) AS unique_outbound_clicks,
    SAFE_DIVIDE(m.spend, sc.n_stores) AS spend,
    SAFE_DIVIDE(m.reach, sc.n_stores) AS reach,
    SAFE_DIVIDE(m.landing_page_views, sc.n_stores) AS landing_page_views,
    m.frequency, m.cpm, m.ctr, m.cpc,
    s.sessions, s.add_to_carts, s.shopify_checkout_initiated, s.shopify_checkout_completed,
    COALESCE(so.orders, 0) + COALESCE(SAFE_DIVIDE(co.orders, sc.n_stores), 0) AS orders,
    COALESCE(so.gross_revenue, 0) + COALESCE(SAFE_DIVIDE(co.gross_revenue, sc.n_stores), 0) AS gross_revenue,
    COALESCE(so.net_revenue, 0) + COALESCE(SAFE_DIVIDE(co.net_revenue, sc.n_stores), 0) AS net_revenue,
    COALESCE(so.refund_amount, 0) + COALESCE(SAFE_DIVIDE(co.refund_amount, sc.n_stores), 0) AS refund_amount,
    so.discounts,
    COALESCE(so.taxes, 0) + COALESCE(SAFE_DIVIDE(co.taxes, sc.n_stores), 0) AS taxes,
    SAFE_DIVIDE(SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_checkout_initiated, sc.n_stores) AS cc_checkout_initiated,
    SAFE_DIVIDE(SAFE_DIVIDE(co.orders, cs.cc_orders_total) * cs.cc_checkout_completed, sc.n_stores) AS cc_checkout_completed,
    CAST(NULL AS FLOAT64) AS cc_declines,
    CAST(NULL AS FLOAT64) AS cc_upsells,
    CAST(NULL AS FLOAT64) AS cc_upsell_revenue,
    CAST(NULL AS FLOAT64) AS cc_shipping
  FROM combined_spine sp
  LEFT JOIN meta m ON sp.date = m.date AND sp.country = m.country
  LEFT JOIN sessions s ON sp.date = s.date AND sp.store_name = s.store_name AND sp.country = s.country
  LEFT JOIN shopify_orders so ON sp.date = so.date AND sp.store_name = so.store_name AND sp.country = so.country
  LEFT JOIN cc_orders co ON sp.date = co.date AND sp.country = co.country
  LEFT JOIN cc_summary cs ON sp.date = cs.date
  LEFT JOIN store_counts sc ON sp.date = sc.date AND sp.country = sc.country
)

SELECT *,
  SAFE_DIVIDE(spend, NULLIF(orders, 0)) AS cpa,
  SAFE_DIVIDE(gross_revenue, NULLIF(spend, 0)) AS roas,
  SAFE_DIVIDE(add_to_carts, NULLIF(sessions, 0)) AS atc_rate,
  SAFE_DIVIDE(orders, NULLIF(sessions, 0)) AS cvr,
  COALESCE(shopify_checkout_initiated, 0) + COALESCE(cc_checkout_initiated, 0) AS checkout_initiated,
  COALESCE(shopify_checkout_completed, 0) + COALESCE(cc_checkout_completed, 0) AS checkout_completed,
  SAFE_DIVIDE(COALESCE(shopify_checkout_initiated, 0) + COALESCE(cc_checkout_initiated, 0), NULLIF(sessions, 0)) AS checkout_initiated_rate,
  SAFE_DIVIDE(COALESCE(shopify_checkout_completed, 0) + COALESCE(cc_checkout_completed, 0), NULLIF(sessions, 0)) AS checkout_completed_rate
FROM shopify

UNION ALL SELECT *,
  SAFE_DIVIDE(spend, NULLIF(orders, 0)) AS cpa,
  SAFE_DIVIDE(gross_revenue, NULLIF(spend, 0)) AS roas,
  SAFE_DIVIDE(add_to_carts, NULLIF(sessions, 0)) AS atc_rate,
  SAFE_DIVIDE(orders, NULLIF(sessions, 0)) AS cvr,
  COALESCE(shopify_checkout_initiated, 0) + COALESCE(cc_checkout_initiated, 0) AS checkout_initiated,
  COALESCE(shopify_checkout_completed, 0) + COALESCE(cc_checkout_completed, 0) AS checkout_completed,
  SAFE_DIVIDE(COALESCE(shopify_checkout_initiated, 0) + COALESCE(cc_checkout_initiated, 0), NULLIF(sessions, 0)) AS checkout_initiated_rate,
  SAFE_DIVIDE(COALESCE(shopify_checkout_completed, 0) + COALESCE(cc_checkout_completed, 0), NULLIF(sessions, 0)) AS checkout_completed_rate
FROM cc

UNION ALL SELECT *,
  SAFE_DIVIDE(spend, NULLIF(orders, 0)) AS cpa,
  SAFE_DIVIDE(gross_revenue, NULLIF(spend, 0)) AS roas,
  SAFE_DIVIDE(add_to_carts, NULLIF(sessions, 0)) AS atc_rate,
  SAFE_DIVIDE(orders, NULLIF(sessions, 0)) AS cvr,
  COALESCE(shopify_checkout_initiated, 0) + COALESCE(cc_checkout_initiated, 0) AS checkout_initiated,
  COALESCE(shopify_checkout_completed, 0) + COALESCE(cc_checkout_completed, 0) AS checkout_completed,
  SAFE_DIVIDE(COALESCE(shopify_checkout_initiated, 0) + COALESCE(cc_checkout_initiated, 0), NULLIF(sessions, 0)) AS checkout_initiated_rate,
  SAFE_DIVIDE(COALESCE(shopify_checkout_completed, 0) + COALESCE(cc_checkout_completed, 0), NULLIF(sessions, 0)) AS checkout_completed_rate
FROM combined;
