CREATE OR REPLACE VIEW `your-project.client_dataset.vw_national_v2` AS
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
total_row AS (
  SELECT
    subchannel, metric, column_name,
    SAFE_CAST(REPLACE(REPLACE(cell_value, '"', ''), ',', '') AS INT64) AS cell_value
  FROM long_form
  WHERE TRIM(col_a) = 'Total'
)
SELECT
  e.report_date,
  n.subchannel,
  SUM(IF(n.metric = 'Sales',        n.cell_value, 0)) AS sales,
  SUM(IF(n.metric = 'Installs', n.cell_value, 0)) AS installs
FROM total_row n
JOIN header e
  USING (subchannel, metric, column_name)
WHERE e.report_date IS NOT NULL
GROUP BY e.report_date, n.subchannel;

CREATE OR REPLACE VIEW `your-project.client_dataset.qc_national_vs_markets_v2` AS
WITH markets AS (
  SELECT report_date, subchannel,
         SUM(sales)        AS sales,
         SUM(installs) AS installs
  FROM `your-project.client_dataset.stg_salesforce_v2`
  GROUP BY report_date, subchannel
)
SELECT
  report_date,
  subchannel,
  n.sales               AS sales_national,
  m.sales               AS sales_markets,
  n.sales - m.sales    AS diff_sales,
  n.installs        AS installs_national,
  m.installs        AS installs_markets,
  n.installs - m.installs AS diff_installs
FROM `your-project.client_dataset.vw_national_v2` n
FULL OUTER JOIN markets m
  USING (report_date, subchannel)
WHERE n.sales IS DISTINCT FROM m.sales
   OR n.installs IS DISTINCT FROM m.installs;

CREATE OR REPLACE VIEW `your-project.client_dataset.vw_national_v2_validated` AS
WITH markets AS (
  SELECT report_date, subchannel,
         SUM(sales)        AS sales_markets,
         SUM(installs) AS installs_markets
  FROM `your-project.client_dataset.stg_salesforce_v2`
  GROUP BY report_date, subchannel
)
SELECT
  n.report_date,
  n.subchannel,
  n.sales,
  n.installs,
  m.sales_markets,
  m.installs_markets,
  n.sales        IS NOT DISTINCT FROM m.sales_markets AS reconciles_sales,
  n.installs IS NOT DISTINCT FROM m.installs_markets   AS reconciles_installs,
  (n.sales        IS NOT DISTINCT FROM m.sales_markets
   AND n.installs IS NOT DISTINCT FROM m.installs_markets) AS reconciles
FROM `your-project.client_dataset.vw_national_v2` n
LEFT JOIN markets m
  USING (report_date, subchannel);
