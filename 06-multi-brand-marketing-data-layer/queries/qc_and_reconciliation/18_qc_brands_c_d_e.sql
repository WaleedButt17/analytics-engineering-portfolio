CREATE OR REPLACE VIEW `your-project.marketing.qc_brands_spend_sessions` AS
WITH all_rows AS (
  SELECT 'Brand C' AS brand, report_date, channel, initiative, spend, sessions
  FROM `your-project.marketing.vw_brand_c_v2`
  UNION ALL
  SELECT 'Brand D', report_date, channel, initiative, spend, sessions
  FROM `your-project.marketing.vw_brand_d_v2`
  UNION ALL
  SELECT 'Brand E', report_date, channel, initiative, spend, sessions
  FROM `your-project.marketing.vw_brand_e_v2`
)
SELECT brand, report_date, channel, initiative,
       ROUND(spend, 2) AS spend,
       sessions,
       CASE WHEN COALESCE(sessions,0) = 0 AND COALESCE(spend,0) > 0
              THEN 'spend without sessions'
            ELSE 'sessions without spend' END AS problem
FROM all_rows
WHERE (COALESCE(sessions,0) = 0 AND COALESCE(spend,0) > 100)
   OR (COALESCE(spend,0)    = 0 AND COALESCE(sessions,0) > 50)
ORDER BY brand, report_date DESC;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brands_freshness` AS
WITH latest AS (
  SELECT 'Brand C' AS brand, MAX(report_date) AS last_date
  FROM `your-project.marketing.vw_brand_c_v2` WHERE spend IS NOT NULL
  UNION ALL
  SELECT 'Brand D', MAX(report_date)
  FROM `your-project.marketing.vw_brand_d_v2` WHERE spend IS NOT NULL
  UNION ALL
  SELECT 'Brand E', MAX(report_date)
  FROM `your-project.marketing.vw_brand_e_v2` WHERE spend IS NOT NULL
)
SELECT brand, last_date,
       DATE_DIFF(CURRENT_DATE('Etc/GMT+6'), last_date, DAY) AS days_of_delay
FROM latest
WHERE DATE_DIFF(CURRENT_DATE('Etc/GMT+6'), last_date, DAY) > 2
ORDER BY days_of_delay DESC;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brands_campaigns_missing` AS
WITH in_staging AS (
  SELECT DISTINCT 'Brand C' AS brand, channel, initiative
  FROM `your-project.marketing.vw_brand_c_v2` WHERE spend IS NOT NULL
  UNION DISTINCT
  SELECT DISTINCT 'Brand D', channel, initiative
  FROM `your-project.marketing.vw_brand_d_v2` WHERE spend IS NOT NULL
  UNION DISTINCT
  SELECT DISTINCT 'Brand E', channel, initiative
  FROM `your-project.marketing.vw_brand_e_v2` WHERE spend IS NOT NULL
)
SELECT d.brand, d.channel, d.initiative, d.campaign_name,
       d.active_since, d.active_until, d.spend_total
FROM `your-project.marketing.dim_campaign` d
LEFT JOIN in_staging s
  ON  s.brand   = d.brand
 AND  s.channel      = d.channel
 AND  COALESCE(s.initiative,'') = COALESCE(d.initiative,'')
WHERE d.brand IN ('Brand C','Brand D','Brand E')
  AND s.brand IS NULL
ORDER BY d.spend_total DESC;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brands_no_additive` AS
SELECT table_name, column_name
FROM `your-project.marketing.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN (
        'vw_brand_c_rollup_weekly','vw_brand_c_rollup_biweekly','vw_brand_c_rollup_v2',
        'vw_brand_d_rollup_weekly','vw_brand_d_rollup_biweekly','vw_brand_d_rollup_v2',
        'vw_brand_e_rollup_weekly','vw_brand_e_rollup_biweekly','vw_brand_e_rollup_v2')
  AND (LOWER(column_name) LIKE '%reach%' OR LOWER(column_name) LIKE '%total_users%')
  AND LOWER(column_name) NOT LIKE '%note%'
ORDER BY table_name, column_name;
