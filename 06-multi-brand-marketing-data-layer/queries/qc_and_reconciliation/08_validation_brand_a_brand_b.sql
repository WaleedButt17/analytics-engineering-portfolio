SELECT channel, ROUND(SUM(spend),2) AS spend_amount
FROM `your-project.marketing.vw_brand_a_v3`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY ROLLUP(channel)
ORDER BY channel NULLS LAST;

SELECT
  channel,
  SUM(sessions)        AS sessions,
  SUM(clicks_partner_1)   AS partner_1,
  SUM(clicks_partner_2)    AS partner_2,
  SUM(video_1)   AS video_1_clicks,
  SUM(video_2) AS video_2_clicks,
  SUM(button_a)  AS button_a_clicks,
  SUM(button_b)      AS button_b_clicks,
  ROUND(SUM(spend), 2) AS spend
FROM `your-project.marketing.mart_kpis_brand_b_v3`
WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY ROLLUP(channel)
ORDER BY channel NULLS LAST;

SELECT
  ROUND(SAFE_DIVIDE(
    SUM(bounce_rate * CAST(sessions AS FLOAT64)),
    SUM(CAST(sessions AS FLOAT64))) * 100, 2) AS bounce_pct,
  ROUND(SAFE_DIVIDE(
    SUM(engagement_rate * CAST(sessions AS FLOAT64)),
    SUM(CAST(sessions AS FLOAT64))) * 100, 2) AS interaction_pct
FROM `your-project.marketing.vw_brand_b_v3`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31';

SELECT ROUND(SUM(spend),2) AS spend_amount, SUM(sessions) AS session_count, SUM(leads) AS leads
FROM `your-project.marketing.vw_brand_a_rollup_biweekly_v3`
WHERE period_start IN ('2026-07-01', '2026-07-16');

SELECT
  SUM(sessions) AS session_count, SUM(new_users) AS new_ones,
  SUM(clicks_orientation) AS orientation, SUM(clicks_buttons_total) AS buttons,
  SUM(leads) AS forms,
  SUM(clicks_assoc_org_1) AS org_1, SUM(clicks_assoc_org_2) AS org_2
FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
WHERE period_start = '2026-08-03';

WITH spend_amount AS (
  SELECT 'Meta' AS channel, account_id AS id_account, campaign AS campaign_name, SUM(spend) AS spend_amount
  FROM `your-project.marketing.facebook_ads_campaigns` GROUP BY 1,2,3
  UNION ALL
  SELECT 'Google', account_id, campaign, SUM(spend)
  FROM `your-project.marketing.google_ads_campaigns` GROUP BY 1,2,3
  UNION ALL
  SELECT 'DV360', CAST(NULL AS STRING), campaign, SUM(revenue_advertiser)
  FROM `your-project.marketing.dv360_campaign_v2` GROUP BY 1,2,3
)
SELECT g.channel,
       COALESCE(d.brand, 'NO MAPPING') AS brand,
       COUNT(DISTINCT g.campaign_name)         AS campaign_names,
       ROUND(SUM(g.spend_amount), 2)            AS spend_amount
FROM spend_amount g
LEFT JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = g.channel
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign_name), NFKC), r'\s+', ' ')
  AND (d.id_account  = g.id_account OR g.id_account IS NULL)
GROUP BY 1,2
ORDER BY g.channel, spend_amount DESC;

SELECT account_id, date, campaign, COUNT(*) AS n_rows
FROM `your-project.marketing.facebook_ads_campaigns`
GROUP BY 1,2,3
HAVING COUNT(*) > 1
ORDER BY date DESC
LIMIT 20;

SELECT
  DATE_TRUNC(date, MONTH) AS month_start,
  COUNT(*) AS n_rows,
  COUNTIF(SAFE_CAST(totalusers AS NUMERIC) > 0) AS with_users
FROM `your-project.marketing.ga4_brand_b_traffic_v2`
GROUP BY 1
ORDER BY 1;

SELECT
  COUNT(*)  AS n_rows,
  MIN(date) AS since_date,
  MAX(date) AS until_date,
  COUNTIF(file_name IS NOT NULL AND file_name != '(not set)') AS with_name,
  COUNTIF(link_url  IS NOT NULL AND link_url  != '(not set)') AS with_link
FROM `your-project.marketing.ga4_brand_a_downloads`;

SELECT campaign, COUNT(DISTINCT account_id) AS accounts, STRING_AGG(DISTINCT account_id) AS ids
FROM `your-project.marketing.facebook_ads_campaigns`
GROUP BY campaign
HAVING COUNT(DISTINCT account_id) > 1;

SELECT 'ads' AS traffic_source, campaign AS name,
       TO_HEX(CAST(campaign AS BYTES)) AS hex
FROM `your-project.marketing.google_ads_campaigns`
WHERE campaign LIKE '%Initiative C1%'
GROUP BY 1,2,3
UNION ALL
SELECT 'catalogue', campaign_name, TO_HEX(CAST(campaign_name AS BYTES))
FROM `your-project.marketing.dim_campaign`
WHERE channel = 'Google' AND campaign_name LIKE '%Initiative C1%';

SELECT * FROM `your-project.marketing.tf_brand_a_weekly_buttons`(DATE '2026-08-03', DATE '2026-08-09');
SELECT * FROM `your-project.marketing.tf_brand_a_weekly_orientation_v2`(DATE '2026-08-03', DATE '2026-08-09');
SELECT * FROM `your-project.marketing.tf_brand_a_weekly_videos`(DATE '2026-08-03', DATE '2026-08-09');
