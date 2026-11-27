CREATE OR REPLACE VIEW `your-project.marts.mart_customer_acquisition`
AS WITH
first_orders AS (
  SELECT customer_email, store_name, MIN(order_date) AS first_order_date
  FROM `your-project.staging.stg_shopify_orders`
  WHERE customer_email IS NOT NULL AND customer_email != ''
  GROUP BY customer_email, store_name
),
order_customer_type AS (
  SELECT order_id, order_date, country, customer_type
  FROM (
    SELECT
      o.order_id,
      o.order_date,
      o.country,
      CASE
        WHEN o.customer_type IS NOT NULL THEN o.customer_type
        WHEN fo.first_order_date = o.order_date THEN 'First-time'
        ELSE 'Returning'
      END AS customer_type,
      ROW_NUMBER() OVER (
        PARTITION BY o.order_id
        ORDER BY
          CASE WHEN o.customer_type IS NOT NULL THEN 0 ELSE 1 END,
          CASE WHEN o.data_source = 'daily' THEN 0 ELSE 1 END
      ) AS rn
    FROM `your-project.staging.stg_shopify_orders` o
    LEFT JOIN first_orders fo
      ON o.customer_email = fo.customer_email
      AND o.store_name = fo.store_name
    WHERE o.line_type = 'product'
  )
  WHERE rn = 1
),
order_data AS (
  SELECT
    oct.order_date AS date,
    oct.country,
    oct.customer_type,
    COUNT(DISTINCT oct.order_id) AS order_count,
    SUM(o.gross_sales) AS gross_revenue,
    SUM(o.net_sales) AS net_revenue
  FROM order_customer_type oct
  LEFT JOIN `your-project.staging.stg_shopify_orders` o
    ON oct.order_id = o.order_id
    AND o.line_type = 'product'
  GROUP BY oct.order_date, oct.country, oct.customer_type
),
meta AS (
  SELECT
    ad_date AS date,
    COALESCE(cm.name, 'Other') AS country,
    SUM(spend) AS spend
  FROM `your-project.staging.stg_meta_ads` m
  LEFT JOIN `your-project.raw.country_codes` cm ON m.country = cm.code
  GROUP BY ad_date, country
),
daily_totals AS (
  SELECT
    date,
    country,
    SUM(order_count) AS total_orders,
    SUM(CASE WHEN customer_type = 'First-time' THEN order_count ELSE 0 END) AS new_orders
  FROM order_data
  GROUP BY date, country
)
SELECT
  o.date, o.country, o.customer_type,
  o.order_count AS orders,
  o.gross_revenue, o.net_revenue,
  m.spend,
  SAFE_DIVIDE(m.spend, NULLIF(dt.new_orders, 0)) AS ncac,
  SAFE_DIVIDE(dt.new_orders, NULLIF(dt.total_orders, 0)) AS new_customer_rate
FROM order_data o
LEFT JOIN meta m ON o.date = m.date AND o.country = m.country
LEFT JOIN daily_totals dt ON o.date = dt.date AND o.country = dt.country;
