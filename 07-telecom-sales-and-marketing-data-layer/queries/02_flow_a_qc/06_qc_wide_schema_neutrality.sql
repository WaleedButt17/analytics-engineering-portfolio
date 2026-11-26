SELECT
  FORMAT_DATE('%Y-%m', report_date) AS report_month,
  subchannel,
  SUM(sales)         AS sales,
  SUM(installs)  AS installs,
  COUNT(DISTINCT report_date) AS days
FROM `your-project.client_dataset.vw_national_v2`
GROUP BY report_month, subchannel
ORDER BY report_month, subchannel;

SELECT reconciles, COUNT(*) AS periods, MIN(report_date) AS date_from, MAX(report_date) AS date_to
FROM `your-project.client_dataset.vw_national_v2_validated`
GROUP BY reconciles
ORDER BY reconciles;

WITH declared AS (
  SELECT table_name, COUNT(*) AS declared_columns
  FROM `your-project.client_dataset.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name IN ('ext_sf_sales_ecom_v2','ext_sf_sales_cc_v2',
                       'ext_sf_installs_ecom_v2','ext_sf_installs_cc_v2')
  GROUP BY table_name
),
in_use AS (
  SELECT 'ext_sf_sales_ecom_v2' AS table_name,
         MAX(CAST(REGEXP_EXTRACT(k, r'[0-9]+$') AS INT64)) + 1 AS columns_in_use
  FROM `your-project.client_dataset.ext_sf_sales_ecom_v2` t,
       UNNEST(JSON_KEYS(TO_JSON(t), 1)) AS k
  WHERE JSON_VALUE(TO_JSON(t)[k]) IS NOT NULL
  UNION ALL
  SELECT 'ext_sf_sales_cc_v2',
         MAX(CAST(REGEXP_EXTRACT(k, r'[0-9]+$') AS INT64)) + 1
  FROM `your-project.client_dataset.ext_sf_sales_cc_v2` t,
       UNNEST(JSON_KEYS(TO_JSON(t), 1)) AS k
  WHERE JSON_VALUE(TO_JSON(t)[k]) IS NOT NULL
  UNION ALL
  SELECT 'ext_sf_installs_ecom_v2',
         MAX(CAST(REGEXP_EXTRACT(k, r'[0-9]+$') AS INT64)) + 1
  FROM `your-project.client_dataset.ext_sf_installs_ecom_v2` t,
       UNNEST(JSON_KEYS(TO_JSON(t), 1)) AS k
  WHERE JSON_VALUE(TO_JSON(t)[k]) IS NOT NULL
  UNION ALL
  SELECT 'ext_sf_installs_cc_v2',
         MAX(CAST(REGEXP_EXTRACT(k, r'[0-9]+$') AS INT64)) + 1
  FROM `your-project.client_dataset.ext_sf_installs_cc_v2` t,
       UNNEST(JSON_KEYS(TO_JSON(t), 1)) AS k
  WHERE JSON_VALUE(TO_JSON(t)[k]) IS NOT NULL
)
SELECT
  d.table_name,
  d.declared_columns,
  u.columns_in_use,
  d.declared_columns - u.columns_in_use AS headroom,
  CAST(FLOOR((d.declared_columns - u.columns_in_use) / 32) AS INT64) AS months_of_headroom
FROM declared d
JOIN in_use u USING (table_name)
ORDER BY table_name;
