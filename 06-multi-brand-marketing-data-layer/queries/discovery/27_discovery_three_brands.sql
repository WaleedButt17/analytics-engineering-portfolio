SELECT
  'facebook_ads_campaigns_v2' AS source_table,
  d.brand,
  FORMAT_DATE('%Y-%m', f.date) AS month_start,
  COUNT(DISTINCT f.campaign)   AS campaign_names,
  ROUND(SUM(f.spend), 2)       AS spend,
  MIN(f.date)                  AS first_day,
  MAX(f.date)                  AS last_day
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
WHERE d.brand IN ('Brand F', 'Brand G')
GROUP BY source_table, d.brand, month_start

UNION ALL

SELECT
  'facebook_ads_campaigns',
  d.brand,
  FORMAT_DATE('%Y-%m', f.date),
  COUNT(DISTINCT f.campaign),
  ROUND(SUM(f.spend), 2),
  MIN(f.date),
  MAX(f.date)
FROM `your-project.marketing.facebook_ads_campaigns` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
WHERE d.brand IN ('Brand F', 'Brand G')
GROUP BY 1, 2, 3
ORDER BY brand, month_start, source_table;

SELECT
  d.brand,
  d.campaign_name,
  d.spend_total          AS spend_catalogue,
  d.active_since,
  d.active_until,
  COUNTIF(v.campaign IS NOT NULL) AS rows_v2,
  COUNTIF(p.campaign IS NOT NULL) AS rows_production
FROM `your-project.marketing.dim_campaign` d
LEFT JOIN `your-project.marketing.facebook_ads_campaigns_v2` v
  ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
LEFT JOIN `your-project.marketing.facebook_ads_campaigns` p
  ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
WHERE d.channel = 'Meta'
  AND d.brand IN ('Brand F', 'Brand G')
GROUP BY d.brand, d.campaign_name, d.spend_total, d.active_since, d.active_until
ORDER BY d.brand, spend_catalogue DESC;

SELECT
  d.brand,
  d.campaign_name,
  d.spend_total                AS spend_catalogue,
  ROUND(SUM(g.spend), 2)       AS spend_table,
  ROUND(d.spend_total - IFNULL(SUM(g.spend), 0), 2) AS difference,
  MIN(g.date)                  AS first_day,
  MAX(g.date)                  AS last_day,
  COUNT(DISTINCT g.date)       AS days_with_data
FROM `your-project.marketing.dim_campaign` d
LEFT JOIN `your-project.marketing.google_ads_campaigns` g
  ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
WHERE d.channel = 'Google'
  AND d.brand IN ('Brand F', 'Brand G')
GROUP BY d.brand, d.campaign_name, d.spend_total
ORDER BY d.brand, spend_catalogue DESC;

SELECT
  f.campaign_id,
  f.campaign,
  MIN(f.date)            AS first_day,
  MAX(f.date)            AS last_day,
  COUNT(DISTINCT f.date) AS days,
  ROUND(SUM(f.spend), 2) AS spend
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
WHERE f.campaign_id = 'CAMPAIGN_ID_1'
GROUP BY f.campaign_id, f.campaign
ORDER BY first_day;

SELECT
  f.campaign,
  MIN(f.date)            AS first_day,
  MAX(f.date)            AS last_day,
  ROUND(SUM(f.spend), 2) AS spend
FROM `your-project.marketing.facebook_ads_campaigns` f
WHERE CAST(f.campaign_id AS STRING) = 'CAMPAIGN_ID_1'
GROUP BY f.campaign
ORDER BY first_day;

SELECT
  d.brand,
  d.channel,
  d.campaign_name,
  d.objective,
  d.active_since,
  d.active_until,
  d.spend_total
FROM `your-project.marketing.dim_campaign` d
WHERE d.brand IN ('Brand F', 'Brand G', 'Brand H')
  AND (d.initiative IS NULL OR TRIM(d.initiative) = '')
ORDER BY d.spend_total DESC;

SELECT
  FORMAT_DATE('%Y-%m', v.date)          AS month_start,
  COUNT(DISTINCT v.date)                AS days,
  ROUND(SUM(v.spend), 2)                AS spend,
  ROUND(SUM(v.revenue_advertiser), 2)   AS revenue_advertiser,
  SUM(v.impressions)                    AS impressions,
  SUM(v.clicks)                         AS clicks,
  SUM(v.complete_views_video)           AS complete_views_video
FROM `your-project.marketing.dv360_campaign_v2` v
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'DV360'
 AND  d.brand    = 'Brand H'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(v.campaign), NFKC), r'\s+', ' ')
GROUP BY month_start
ORDER BY month_start;

SELECT
  u.brand,
  u.initiative       AS initiative_per_ga4,
  u.utm_campaign,
  u.sessions_observed,
  d.campaign_name          AS campaign_catalogue,
  d.initiative       AS initiative_catalogue,
  d.spend_total
FROM `your-project.marketing.dim_utm` u
LEFT JOIN `your-project.marketing.dim_campaign` d
  ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(u.utm_campaign), NFKC), r'\s+', ' ')
WHERE u.brand IN ('Brand F', 'Brand G')
ORDER BY u.brand, u.sessions_observed DESC;

WITH by_utm AS (
  SELECT
    date,
    source,
    campaign,
    MAX(sessions) AS sessions,
    SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY date, source, campaign
)
SELECT
  u.brand,
  u.initiative,
  FORMAT_DATE('%Y-%m', p.date) AS month_start,
  SUM(p.sessions)              AS sessions,
  SUM(p.leads)                 AS leads
FROM by_utm p
JOIN `your-project.marketing.dim_utm_by_property` u
  ON  u.property = 'ga4_property_E'
 AND  u.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
WHERE u.brand IN ('Brand F', 'Brand G')
GROUP BY u.brand, u.initiative, month_start
ORDER BY u.brand, month_start;
