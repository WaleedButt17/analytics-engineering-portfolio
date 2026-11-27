CREATE OR REPLACE VIEW `your-project.marts.mart_funnel_stages`
AS WITH combined_checkout AS (
  SELECT
    date,
    country,
    SUM(checkout_initiated) AS checkout_initiated,
    SUM(checkout_completed) AS checkout_completed
  FROM (
    SELECT date, country, COALESCE(shopify_checkout_initiated, 0) AS checkout_initiated, COALESCE(shopify_checkout_completed, 0) AS checkout_completed
    FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'
    UNION ALL
    SELECT date, country, COALESCE(cc_checkout_initiated, 0), COALESCE(cc_checkout_completed, 0)
    FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'checkoutchamp'
  )
  GROUP BY date, country
)

SELECT date, store_name, country, 'combined' AS platform, 'Meta Ad Impressions' AS funnel_stage, 1 AS stage_order, COALESCE(impressions, 0) AS value FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, store_name, country, 'combined', 'Meta Ad Clicks', 2, COALESCE(link_clicks, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, store_name, country, 'combined', 'Sessions', 3, COALESCE(sessions, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, store_name, country, 'combined', 'Add to Cart', 4, COALESCE(add_to_carts, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, NULL AS store_name, country, 'combined', 'Checkout Initiated', 5, COALESCE(checkout_initiated, 0) FROM combined_checkout
UNION ALL
SELECT date, NULL AS store_name, country, 'combined', 'Checkout Completed', 6, COALESCE(checkout_completed, 0) FROM combined_checkout

UNION ALL

SELECT date, store_name, country, 'shopify', 'Meta Ad Impressions', 1, COALESCE(impressions, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'
UNION ALL
SELECT date, store_name, country, 'shopify', 'Meta Ad Clicks', 2, COALESCE(link_clicks, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'
UNION ALL
SELECT date, store_name, country, 'shopify', 'Sessions', 3, COALESCE(sessions, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'
UNION ALL
SELECT date, store_name, country, 'shopify', 'Add to Cart', 4, COALESCE(add_to_carts, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'
UNION ALL
SELECT date, store_name, country, 'shopify', 'Checkout Initiated', 5, COALESCE(shopify_checkout_initiated, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'
UNION ALL
SELECT date, store_name, country, 'shopify', 'Checkout Completed', 6, COALESCE(shopify_checkout_completed, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'shopify'

UNION ALL

SELECT date, store_name, country, 'checkoutchamp', 'Meta Ad Impressions', 1, COALESCE(impressions, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, store_name, country, 'checkoutchamp', 'Meta Ad Clicks', 2, COALESCE(link_clicks, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, store_name, country, 'checkoutchamp', 'Sessions', 3, COALESCE(sessions, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, store_name, country, 'checkoutchamp', 'Add to Cart', 4, COALESCE(add_to_carts, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'combined'
UNION ALL
SELECT date, NULL AS store_name, country, 'checkoutchamp', 'Checkout Initiated', 5, COALESCE(cc_checkout_initiated, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'checkoutchamp'
UNION ALL
SELECT date, NULL AS store_name, country, 'checkoutchamp', 'Checkout Completed', 6, COALESCE(cc_checkout_completed, 0) FROM `your-project.marts.mart_funnel_daily` WHERE platform = 'checkoutchamp';
