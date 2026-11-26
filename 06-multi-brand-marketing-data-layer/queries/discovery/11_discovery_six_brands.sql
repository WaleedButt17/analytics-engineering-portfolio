SELECT table_id AS object,
       CASE type WHEN 1 THEN 'TABLE' WHEN 2 THEN 'VIEW' ELSE CAST(type AS STRING) END AS object_type,
       row_count AS n_rows,
       ROUND(size_bytes/(1024 * 1024), 1) AS mb,
       DATE(TIMESTAMP_MILLIS(creation_time))      AS created,
       DATE(TIMESTAMP_MILLIS(last_modified_time)) AS modified
FROM `your-project.marketing.__TABLES__`
ORDER BY object_type, object;

SELECT 'google' AS channel, account_id,
       COUNT(*)                                                    AS n_rows,
       COUNTIF(campaign_id IS NOT NULL AND campaign_id != '')      AS with_id,
       ROUND(100*SAFE_DIVIDE(COUNTIF(campaign_id IS NOT NULL AND campaign_id != ''), COUNT(*)),1) AS pct_with_id,
       MIN(date) AS since_date, MAX(date) AS until_date
FROM `your-project.marketing.google_ads_campaigns`
GROUP BY 1,2
UNION ALL
SELECT 'meta', account_id, COUNT(*),
       COUNTIF(campaign_id IS NOT NULL AND campaign_id != ''),
       ROUND(100*SAFE_DIVIDE(COUNTIF(campaign_id IS NOT NULL AND campaign_id != ''), COUNT(*)),1),
       MIN(date), MAX(date)
FROM `your-project.marketing.facebook_ads_campaigns`
GROUP BY 1,2
ORDER BY channel, account_id;

WITH cat AS (
  SELECT channel, campaign_key, brand, campaign_id, active_since, active_until, spend_total
  FROM `your-project.marketing.dim_campaign`
  WHERE brand IN ('Brand G','Brand F','Brand C','Brand E','Brand D','Brand H')
),
raw AS (
  SELECT 'Google' AS channel,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS campaign_key,
         MIN(date) AS raw_since, MAX(date) AS raw_until,
         COUNT(*) AS days, ROUND(SUM(spend),2) AS raw_spend
  FROM `your-project.marketing.google_ads_campaigns` GROUP BY 1,2
  UNION ALL
  SELECT 'Meta',
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' '),
         MIN(date), MAX(date), COUNT(*), ROUND(SUM(spend),2)
  FROM `your-project.marketing.facebook_ads_campaigns` GROUP BY 1,2
  UNION ALL
  SELECT 'DV360',
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' '),
         MIN(date), MAX(date), COUNT(*), ROUND(SUM(spend),2)
  FROM `your-project.marketing.dv360_campaign_v2` GROUP BY 1,2
)
SELECT c.brand, c.channel, c.campaign_key,
       c.active_since, c.active_until, c.spend_total,
       r.raw_since, r.raw_until, r.days, r.raw_spend,
       CASE WHEN r.campaign_key IS NULL              THEN 'ABSENT from the table'
            WHEN r.raw_since > c.active_since       THEN 'BACKFILL INCOMPLETE'
            ELSE 'ok' END                           AS verdict
FROM cat c
LEFT JOIN raw r ON r.channel = c.channel AND r.campaign_key = c.campaign_key
ORDER BY verdict DESC, c.brand, c.channel;

SELECT campaign_id, campaign, account_id,
       MIN(date) AS since_date, MAX(date) AS until_date,
       COUNT(*) AS days, ROUND(SUM(spend),2) AS spend_amount
FROM `your-project.marketing.facebook_ads_campaigns`
WHERE campaign_id = 'CAMPAIGN_ID_1'
   OR REGEXP_CONTAINS(LOWER(campaign), r'brand g aon sep|initiative f1|initiative f3')
GROUP BY 1,2,3
ORDER BY since_date;

SELECT column_name, data_type
FROM `your-project.marketing.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = '<ga4_brand_e_table>'
ORDER BY ordinal_position;

SELECT COALESCE(d.brand, '(uncatalogued)') AS brand,
       v.campaign, v.campaign_id,
       MIN(v.date) AS since_date, MAX(v.date) AS until_date,
       ROUND(SUM(v.spend),2)               AS spend,
       ROUND(SUM(v.revenue_advertiser),2)  AS revenue_advertiser,
       SUM(v.impressions) AS impression_count, SUM(v.clicks) AS click_count
FROM `your-project.marketing.dv360_campaign_v2` v
LEFT JOIN `your-project.marketing.dim_campaign` d
  ON d.channel = 'DV360'
 AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
GROUP BY 1,2,3
ORDER BY spend DESC;

WITH all_rows AS (
  SELECT 'Google' AS channel, campaign, account_id, date, spend
  FROM `your-project.marketing.google_ads_campaigns`
  UNION ALL SELECT 'Meta', campaign, account_id, date, spend
  FROM `your-project.marketing.facebook_ads_campaigns`
  UNION ALL SELECT 'DV360', campaign, CAST(NULL AS STRING), date, spend
  FROM `your-project.marketing.dv360_campaign_v2`
)
SELECT t.channel, t.campaign, t.account_id,
       MIN(t.date) AS since_date, MAX(t.date) AS until_date,
       ROUND(SUM(t.spend),2) AS uncatalogued_spend
FROM all_rows t
LEFT JOIN `your-project.marketing.dim_campaign` d
  ON d.channel = t.channel
 AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(t.campaign), NFKC), r'\s+', ' ')
WHERE d.campaign_key IS NULL
GROUP BY 1,2,3
HAVING uncatalogued_spend > 0
ORDER BY uncatalogued_spend DESC;

SELECT campaign, account_id,
       ROUND(SUM(spend),2) AS spend, SUM(clicks) AS click_count,
       SUM(impressions) AS impression_count, SUM(reach) AS reach_count
FROM `your-project.marketing.facebook_ads_campaigns`
WHERE date BETWEEN '2026-08-01' AND '2026-08-07'
  AND LOWER(campaign) LIKE '%brand c%'
GROUP BY 1,2
ORDER BY spend DESC;

SELECT account_id,
       COUNT(*)                                            AS n_rows,
       COUNT(DISTINCT campaign_id)                         AS campaign_names,
       COUNTIF(campaign_id IS NULL OR campaign_id = '')    AS no_id,
       COUNTIF(reach IS NULL)                              AS no_reach,
       COUNTIF(account_id IS NULL OR account_id = '')      AS no_account,
       MIN(date) AS since_date, MAX(date) AS until_date,
       ROUND(SUM(spend),2)                                 AS spend_total
FROM `your-project.marketing.facebook_ads_campaigns_v2`
GROUP BY 1
ORDER BY 1;

SELECT date, campaign_id, COUNT(*) AS n_rows
FROM `your-project.marketing.facebook_ads_campaigns_v2`
GROUP BY 1,2 HAVING COUNT(*) > 1
ORDER BY n_rows DESC LIMIT 20;

SELECT campaign_id, ANY_VALUE(campaign) AS campaign_name,
       COUNT(DISTINCT account_id) AS accounts,
       STRING_AGG(DISTINCT account_id) AS ids
FROM `your-project.marketing.facebook_ads_campaigns_v2`
GROUP BY 1 HAVING COUNT(DISTINCT account_id) > 1;
