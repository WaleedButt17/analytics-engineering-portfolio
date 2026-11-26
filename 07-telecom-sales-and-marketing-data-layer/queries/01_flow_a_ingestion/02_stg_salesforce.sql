CREATE OR REPLACE VIEW `your-project.client_dataset.stg_salesforce_v2` AS
WITH raw_rows AS (
  SELECT 'E-commerce'  AS subchannel, 'Sales'        AS metric, TO_JSON(t) AS j
  FROM `your-project.client_dataset.ext_sf_sales_ecom_v2` t
  UNION ALL
  SELECT 'Call Center', 'Sales',        TO_JSON(t)
  FROM `your-project.client_dataset.ext_sf_sales_cc_v2`  t
  UNION ALL
  SELECT 'E-commerce',  'Installs', TO_JSON(t)
  FROM `your-project.client_dataset.ext_sf_installs_ecom_v2`   t
  UNION ALL
  SELECT 'Call Center', 'Installs', TO_JSON(t)
  FROM `your-project.client_dataset.ext_sf_installs_cc_v2`    t
),
long_form AS (
  SELECT
    subchannel,
    metric,
    JSON_VALUE(j['string_field_0']) AS col_a,
    JSON_VALUE(j['string_field_1']) AS col_b,
    k                               AS column_name,
    JSON_VALUE(j[k])                AS cell_value
  FROM raw_rows, UNNEST(JSON_KEYS(j, 1)) AS k
),
header AS (
  SELECT
    subchannel, metric, column_name,
    ANY_VALUE(COALESCE(
      SAFE.PARSE_DATE('%d/%m/%Y', cell_value),
      IF(REGEXP_CONTAINS(cell_value, r'^[0-9]{5}$'),
         DATE_ADD(DATE '1899-12-30', INTERVAL CAST(cell_value AS INT64) DAY),
         NULL)
    )) AS report_date
  FROM long_form
  WHERE col_a LIKE 'Site:%'
  GROUP BY subchannel, metric, column_name
),
cells AS (
  SELECT
    subchannel, metric, column_name,
    TRIM(col_b) AS district,
    SAFE_CAST(REPLACE(REPLACE(cell_value, '"', ''), ',', '') AS INT64) AS cell_value
  FROM long_form
  WHERE col_b IS NOT NULL
    AND col_b NOT LIKE 'Site:%'
    AND TRIM(col_b) != 'Subtotal'
)
SELECT
  e.report_date,
  d.district,
  d.subchannel,
  SUM(IF(d.metric = 'Sales',        d.cell_value, 0)) AS sales,
  SUM(IF(d.metric = 'Installs', d.cell_value, 0)) AS installs
FROM cells d
JOIN header e
  USING (subchannel, metric, column_name)
WHERE e.report_date IS NOT NULL
GROUP BY e.report_date, d.district, d.subchannel;
