SELECT
  table_id,
  TIMESTAMP_MILLIS(last_modified_time) AS last_write,
  DATETIME(TIMESTAMP_MILLIS(last_modified_time), 'Etc/GMT+6') AS last_write_local,
  row_count AS n_rows
FROM `your-project.marketing.__TABLES__`
WHERE STARTS_WITH(table_id, 'ga4_')
ORDER BY last_modified_time;

EXECUTE IMMEDIATE (
  SELECT
    STRING_AGG(
      FORMAT(
        "SELECT '%s' AS source_table, CAST(MAX(date) AS STRING) AS last_day, COUNT(*) AS n_rows FROM `your-project.marketing.%s`",
        table_name, table_name),
      "\nUNION ALL\n")
    || "\nORDER BY last_day, source_table"
  FROM `your-project.marketing.INFORMATION_SCHEMA.COLUMNS`
  WHERE column_name = 'date'
    AND STARTS_WITH(table_name, 'ga4_')
);

SELECT 'ga4_brand_e' AS source_table, COUNT(*) AS n_rows,
       COUNT(DISTINCT FORMAT('%t|%t|%t', date, campaign, event_name)) AS combinations
FROM `your-project.marketing.ga4_brand_e`
UNION ALL
SELECT 'ga4_brand_a', COUNT(*),
       COUNT(DISTINCT FORMAT('%t|%t|%t', date, campaign, event_name))
FROM `your-project.marketing.ga4_brand_a`
UNION ALL
SELECT 'ga4_brand_d', COUNT(*),
       COUNT(DISTINCT FORMAT('%t|%t', date, campaign))
FROM `your-project.marketing.ga4_brand_d`
UNION ALL
SELECT 'ga4_brand_b_events_v2', COUNT(*),
       COUNT(DISTINCT FORMAT('%t|%t|%t', date, session_source_medium, event_name))
FROM `your-project.marketing.ga4_brand_b_events_v2`;

SELECT *
FROM `your-project.marketing.ga4_brand_a_users_weekly`
ORDER BY year_week_iso DESC
LIMIT 6;

SELECT
  table_id,
  DATETIME(TIMESTAMP_MILLIS(last_modified_time), 'Etc/GMT+6') AS last_write_local,
  row_count AS n_rows
FROM `your-project.another_dataset.__TABLES__`
WHERE STARTS_WITH(table_id, 'ga4_')
ORDER BY last_modified_time;
