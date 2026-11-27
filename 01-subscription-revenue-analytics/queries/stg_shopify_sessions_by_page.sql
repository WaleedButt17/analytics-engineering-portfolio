CREATE OR REPLACE VIEW `your-project.staging.stg_shopify_sessions_by_page`
AS WITH combined AS (
  SELECT
    day AS session_date,
    store,
    landing_page_path,
    sessions,
    sessions_with_cart_additions,
    sessions_that_reached_checkout,
    sessions_that_completed_checkout,
    conversion_rate,
    'historical' AS data_source
  FROM `your-project.raw.historical_shopify_sessions_by_page`
  WHERE store NOT IN ('Excluded Store A', 'Excluded Store B')

  UNION ALL

  SELECT
    day AS session_date,
    store,
    landing_page_path,
    sessions,
    sessions_with_cart_additions,
    sessions_that_reached_checkout,
    sessions_that_completed_checkout,
    conversion_rate,
    'daily' AS data_source
  FROM `your-project.raw.daily_shopify_sessions_by_page`
  WHERE store NOT IN ('Excluded Store A', 'Excluded Store B')
)

SELECT * FROM combined
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY session_date, store, landing_page_path
  ORDER BY data_source DESC
) = 1;
