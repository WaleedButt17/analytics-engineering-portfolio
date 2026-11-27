CREATE OR REPLACE VIEW `your-project.marts.mart_product_daily`
AS SELECT
  order_date,
  store_name,
  country_code,
  product_id,
  product_title,
  product_type,
  product_variant_id,
  product_variant_sku,
  product_variant_title,
  COUNT(DISTINCT order_id) AS orders,
  SUM(ordered_quantity) AS units_sold,
  SUM(gross_sales) AS gross_revenue,
  SUM(net_sales) AS net_revenue,
  SUM(discounts) AS discounts,
  SUM(refunds) AS refunds,
  SAFE_DIVIDE(SUM(net_sales), COUNT(DISTINCT order_id)) AS aov,
  SAFE_DIVIDE(SUM(net_sales), SUM(ordered_quantity)) AS revenue_per_unit
FROM `your-project.staging.stg_shopify_orders`
WHERE product_title IS NOT NULL
GROUP BY
  order_date,
  store_name,
  country_code,
  product_id,
  product_title,
  product_type,
  product_variant_id,
  product_variant_sku,
  product_variant_title;
