WITH v1 AS (
  SELECT
    iso_year,
    week_number,
    total_sales        AS sales_v1,
    call_center_sales    AS cc_v1,
    ecommerce_sales      AS ecom_v1,
    total_installs AS installs_v1
  FROM `your-project.client_dataset.v1_weekly_results`
),
v2 AS (
  SELECT
    EXTRACT(ISOYEAR FROM report_date) AS iso_year,
    EXTRACT(ISOWEEK FROM report_date) AS week_number,
    MIN(report_date)                  AS date_from,
    MAX(report_date)                  AS date_to,
    SUM(sales)                                       AS sales_v2,
    SUM(IF(subchannel = 'Call Center', sales, 0))      AS cc_v2,
    SUM(IF(subchannel = 'E-commerce',  sales, 0))      AS ecom_v2,
    SUM(installs)                                AS installs_v2
  FROM `your-project.client_dataset.vw_national_v2`
  GROUP BY iso_year, week_number
)
SELECT
  iso_year,
  week_number,
  v2.date_from,
  v2.date_to,
  v1.sales_v1,
  v2.sales_v2,
  v2.sales_v2 - v1.sales_v1 AS diff_sales,
  v1.installs_v1,
  v2.installs_v2,
  v2.installs_v2 - v1.installs_v1     AS diff_installs
FROM v2
FULL OUTER JOIN v1 USING (iso_year, week_number)
ORDER BY iso_year, week_number;
