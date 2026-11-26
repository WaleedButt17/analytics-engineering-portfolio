SELECT
  channel,
  ROUND(SUM(spend), 2)  AS spend,
  SUM(impressions)      AS impressions,
  SUM(clicks)           AS clicks,
  SUM(sessions)         AS sessions,
  SUM(new_users)        AS new_users,
  SUM(leads)            AS leads,
  ROUND(SAFE_DIVIDE(SUM(clicks), SUM(impressions)) * 100, 2) AS ctr_pct,
  ROUND(SAFE_DIVIDE(SUM(spend),  SUM(clicks)), 2)            AS cpc,
  ROUND(SAFE_DIVIDE(SUM(spend),  SUM(leads)), 2)             AS cpa,
  ROUND(SAFE_DIVIDE(SUM(leads),  SUM(sessions)) * 100, 2)    AS conv_sessions_pct
FROM `your-project.marketing.vw_brand_e_v2`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY ROLLUP(channel)
ORDER BY channel NULLS LAST;

WITH by_group AS (
  SELECT
    g.date,
    g.source,
    g.campaign,
    SUM(IF(g.event_name = 'session_start', g.event_count, 0)) AS session_start,
    MAX(g.sessions)                                           AS max_sessions,
    SUM(g.sessions)                                           AS sum_sessions
  FROM `your-project.marketing.ga4_brand_e` g
  WHERE g.date BETWEEN '2026-07-01' AND '2026-07-31'
    AND g.source IN ('google', 'meta')
  GROUP BY g.date, g.source, g.campaign
)
SELECT
  p.source,
  SUM(p.session_start) AS sessions_session_start,
  SUM(p.max_sessions)  AS sessions_max,
  SUM(p.sum_sessions)  AS sessions_sum_naive,
  ROUND(SAFE_DIVIDE(SUM(p.max_sessions) - SUM(p.session_start),
                    SUM(p.session_start)) * 100, 2) AS pct_max_vs_start
FROM by_group p
JOIN `your-project.marketing.dim_utm_by_property` u
  ON  u.property = 'ga4_property_E'
 AND  u.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
 AND  u.brand  = 'Brand E'
GROUP BY p.source
ORDER BY p.source;

SELECT
  report_date,
  ROUND(SUM(spend), 2) AS spend,
  SUM(clicks)          AS clicks,
  SUM(impressions)     AS impressions,
  SUM(sessions)        AS sessions,
  SUM(leads)           AS leads,
  COUNT(DISTINCT channel) AS channels
FROM `your-project.marketing.vw_brand_e_v2`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY report_date
ORDER BY report_date;

SELECT
  initiative,
  channel,
  ROUND(SUM(spend), 2) AS spend,
  SUM(impressions)     AS impressions,
  SUM(clicks)          AS clicks,
  SUM(sessions)        AS sessions,
  SUM(leads)           AS leads
FROM `your-project.marketing.vw_brand_e_v2`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY initiative, channel
ORDER BY spend DESC;

WITH by_group AS (
  SELECT
    g.source,
    g.campaign,
    MAX(g.sessions) AS sessions,
    SUM(IF(g.event_name = 'registration_complete', g.event_count, 0)) AS leads
  FROM `your-project.marketing.ga4_brand_e` g
  WHERE g.date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY g.date, g.source, g.campaign
)
SELECT
  p.source,
  p.campaign AS utm_campaign,
  SUM(p.sessions) AS sessions,
  SUM(p.leads)    AS leads,
  IFNULL(u.brand, '(unmapped)')   AS brand,
  IFNULL(u.initiative, '(unmapped)') AS initiative,
  CASE WHEN u.brand = 'Brand E' THEN 'IN R-1'
       WHEN u.brand IS NOT NULL     THEN 'other brand'
       ELSE 'outside the model' END     AS status
FROM by_group p
LEFT JOIN `your-project.marketing.dim_utm_by_property` u
  ON  u.property = 'ga4_property_E'
 AND  u.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
GROUP BY p.source, utm_campaign, u.brand, u.initiative, status
ORDER BY sessions DESC;

SELECT
  d.channel,
  d.campaign_name,
  d.initiative,
  d.active_since,
  d.active_until,
  ROUND(SUM(f.spend), 2) AS spend_july,
  SUM(f.clicks)          AS clicks_july,
  COUNT(DISTINCT f.date) AS days
FROM `your-project.marketing.dim_campaign` d
LEFT JOIN `your-project.marketing.facebook_ads_campaigns_v2` f
  ON  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
 AND  f.date BETWEEN '2026-07-01' AND '2026-07-31'
WHERE d.brand = 'Brand E' AND d.channel = 'Meta'
GROUP BY d.channel, d.campaign_name, d.initiative, d.active_since, d.active_until

UNION ALL

SELECT
  d.channel, d.campaign_name, d.initiative, d.active_since, d.active_until,
  ROUND(SUM(g.spend), 2), SUM(g.clicks), COUNT(DISTINCT g.date)
FROM `your-project.marketing.dim_campaign` d
LEFT JOIN `your-project.marketing.google_ads_campaigns` g
  ON  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
 AND  g.date BETWEEN '2026-07-01' AND '2026-07-31'
WHERE d.brand = 'Brand E' AND d.channel = 'Google'
GROUP BY d.channel, d.campaign_name, d.initiative, d.active_since, d.active_until
ORDER BY spend_july DESC;

SELECT
  'sum of daily reach' AS method,
  CAST(SUM(f.reach) AS INT64) AS reach_count
FROM `your-project.marketing.facebook_ads_campaigns_v2` f
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.brand    = 'Brand E'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
WHERE f.date BETWEEN '2026-07-01' AND '2026-07-31'

UNION ALL

SELECT
  CONCAT('windsor period ', a.grain),
  CAST(SUM(a.reach) AS INT64)
FROM `your-project.marketing.meta_reach_period` a
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Meta'
 AND  d.brand    = 'Brand E'
 AND  d.campaign_key = a.campaign_key
WHERE a.period_start = '2026-07-01'
  AND a.grain = 'monthly'
GROUP BY a.grain

UNION ALL

SELECT 'looker published', 112114;
