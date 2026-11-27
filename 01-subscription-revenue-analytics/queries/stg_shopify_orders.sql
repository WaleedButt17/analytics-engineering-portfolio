CREATE OR REPLACE VIEW `your-project.staging.stg_shopify_orders`
AS WITH combined AS (
  SELECT
    day AS order_date,
    order_id, sale_id, line_item_id, line_type, store_name, myshopify_domain,
    customer_id, customer_email, customer_name,
    CAST(NULL AS STRING) AS customer_type,
    shipping_country_code AS country_code, shipping_country AS country,
    gross_sales, net_sales, refunds, discounts, taxes, ordered_quantity,
    unit_price, payment_status, order_fulfillment_status, order_type, is_one_time,
    product_id, product_title, product_type, product_variant_id, product_variant_sku,
    product_variant_title_at_sale AS product_variant_title,
    source_name, sales_channel_name, utm_source, utm_medium, utm_campaign,
    utm_content, utm_term, 'historical' AS data_source
  FROM `your-project.raw.historical_shopify_orders`
  WHERE myshopify_domain NOT IN ('excluded-store-d.myshopify.com', 'excluded-store-e.myshopify.com')

  UNION ALL

  SELECT
    DATE(order_created_at_date) AS order_date,
    order_id, sale_id, line_item_id, line_type, store_name, myshopify_domain,
    customer_id, customer_email, customer_name, customer_type,
    shipping_country_code AS country_code, shipping_country AS country,
    gross_sales, net_sales, refunds, discounts, taxes, ordered_quantity,
    unit_price, payment_status, order_fulfillment_status, order_type, is_one_time,
    product_id, product_title, product_type, product_variant_id, product_variant_sku,
    product_variant_title, source_name, sales_channel_name,
    utm_source, utm_medium, utm_campaign, utm_content, utm_term,
    'daily' AS data_source
  FROM `your-project.raw.daily_shopify_orders`
  WHERE myshopify_domain NOT IN ('excluded-store-d.myshopify.com', 'excluded-store-e.myshopify.com')
)
SELECT * FROM combined
QUALIFY ROW_NUMBER() OVER (PARTITION BY sale_id ORDER BY data_source DESC) = 1;
