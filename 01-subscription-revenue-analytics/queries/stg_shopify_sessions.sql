CREATE OR REPLACE VIEW `your-project.staging.stg_shopify_sessions`
AS WITH combined AS (
  SELECT
    day AS session_date,
    CASE
      WHEN store = 'store-1-old-domain.com' THEN 'store-1.com'
      ELSE store
    END AS store,
    CASE
      WHEN (session_country IS NULL OR session_country = '') AND store = 'store-2.com' THEN 'United States'
      WHEN (session_country IS NULL OR session_country = '') THEN 'Unknown'
      ELSE session_country
    END AS country,
    utm_source,
    utm_medium,
    utm_campaign,
    sessions,
    online_store_visitors,
    sessions_with_cart_additions,
    sessions_that_reached_checkout,
    sessions_that_completed_checkout,
    conversion_rate,
    'historical' AS data_source
  FROM `your-project.raw.historical_shopify_sessions`
  WHERE store NOT IN ('Excluded Store A', 'Excluded Store B', 'excluded-store-c.com', 'excluded-store-d.myshopify.com', 'excluded-store-e.myshopify.com')

  UNION ALL

  SELECT
    day AS session_date,
    CASE
      WHEN store = 'store-1-old-domain.com' THEN 'store-1.com'
      ELSE store
    END AS store,
    CASE
      WHEN (session_country IS NULL OR session_country = '') AND store = 'store-2.com' THEN 'United States'
      WHEN (session_country IS NULL OR session_country = '') THEN 'Unknown'
      ELSE session_country
    END AS country,
    utm_source,
    utm_medium,
    utm_campaign,
    sessions,
    online_store_visitors,
    sessions_with_cart_additions,
    sessions_that_reached_checkout,
    sessions_that_completed_checkout,
    conversion_rate,
    'daily' AS data_source
  FROM `your-project.raw.daily_shopify_sessions`
  WHERE store NOT IN ('Excluded Store A', 'Excluded Store B', 'excluded-store-c.com', 'excluded-store-d.myshopify.com', 'excluded-store-e.myshopify.com')
)

SELECT * FROM combined
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY session_date, store, country, utm_source, utm_medium, utm_campaign
  ORDER BY data_source ASC
) = 1;
