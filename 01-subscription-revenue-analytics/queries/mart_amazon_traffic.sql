CREATE OR REPLACE VIEW `your-project.marts.mart_amazon_traffic`
AS SELECT
  date,
  ordered_product_sales,
  units_ordered,
  total_order_items,
  average_selling_price,
  units_refunded,
  refund_rate / 100 AS refund_rate,
  units_shipped,
  orders_shipped,
  shipped_product_sales,
  page_views,
  browser_page_views,
  mobile_page_views,
  sessions,
  browser_sessions,
  mobile_sessions,
  buy_box_percentage / 100 AS buy_box_percentage,
  unit_session_percentage / 100 AS unit_session_percentage,
  order_item_session_percentage / 100 AS order_item_session_percentage,
  ingested_at
FROM `your-project.staging.stg_amazon_traffic`;
