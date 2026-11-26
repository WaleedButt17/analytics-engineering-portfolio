SELECT
  brand, grain, period_start, period_end,
  reach_count, reach_bound_upper, campaigns_in_period, reach_is_exact
FROM `your-project.marketing.vw_reach_period_brand`
WHERE grain = 'monthly' AND period_start = '2026-07-01'
ORDER BY brand;

SELECT
  brand, grain,
  COUNT(*)                   AS periods,
  COUNTIF(reach_is_exact) AS exact,
  ROUND(COUNTIF(reach_is_exact) / COUNT(*) * 100, 1) AS pct_exact
FROM `your-project.marketing.vw_reach_period_brand_initiative`
GROUP BY brand, grain
ORDER BY brand, grain;

SELECT * FROM `your-project.marketing.qc_reach_additive`
WHERE period_start >= '2026-05-01';

SELECT * FROM `your-project.marketing.qc_reach_missing`;

SELECT
  channel,
  SUM(sessions)  AS sessions,
  SUM(leads)     AS leads,
  SUM(new_users) AS new_users,
  COUNT(*)       AS n_rows,
  COUNT(DISTINCT FORMAT('%t|%t|%t', report_date, channel, initiative)) AS combinations
FROM `your-project.marketing.vw_brand_e_v2`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY channel
ORDER BY channel;

SELECT * FROM `your-project.marketing.qc_utm_orphan_v2` LIMIT 50;

SELECT * FROM `your-project.marketing.ga4_users_period`
WHERE period_start = '2026-07-01'
LIMIT 20;

WITH by_group AS (
  SELECT date, source, campaign, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY date, source, campaign
  UNION ALL
  SELECT date, source, campaign, MAX(sessions)
  FROM `your-project.marketing.ga4_brand_d`
  WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY date, source, campaign
)
SELECT
  u.brand,
  u.initiative,
  p.source,
  p.campaign             AS utm_campaign,
  SUM(p.sessions)        AS sessions_july,
  COUNT(DISTINCT p.date) AS days_with_traffic,
  ROUND(SUM(p.sessions) / COUNT(DISTINCT p.date), 1) AS sessions_by_day
FROM by_group p
JOIN `your-project.marketing.dim_utm` u
  ON  u.traffic_source  = p.source
 AND  u.utm_key = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
 AND  u.in_model
GROUP BY u.brand, u.initiative, p.source, utm_campaign
ORDER BY sessions_july ASC;

WITH daily AS (
  SELECT SUM(s) AS sessions_sum_daily FROM (
    SELECT MAX(g.sessions) AS s
    FROM `your-project.marketing.ga4_brand_e` g
    JOIN `your-project.marketing.dim_utm` u
      ON  u.property = 'ga4_property_E'
     AND  u.traffic_source    = g.source
     AND  u.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
     AND  u.brand  = 'Brand C'
     AND  u.in_model
    WHERE g.date BETWEEN '2026-07-01' AND '2026-07-31'
    GROUP BY g.date, g.source, g.campaign
  )
)
SELECT
  sessions_sum_daily,
  439 AS looker_july,
  ROUND((sessions_sum_daily - 439) / 439 * 100, 1) AS pct_over_looker
FROM daily;

WITH by_day AS (
  SELECT u.brand, g.date, g.source, g.campaign, MAX(g.sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e` g
  JOIN `your-project.marketing.dim_utm` u
    ON  u.property = 'ga4_property_E'
   AND  u.traffic_source    = g.source
   AND  u.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
   AND  u.in_model
  WHERE g.date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY u.brand, g.date, g.source, g.campaign

  UNION ALL

  SELECT u.brand, g.date, g.source, g.campaign, MAX(g.sessions)
  FROM `your-project.marketing.ga4_brand_d` g
  JOIN `your-project.marketing.dim_utm` u
    ON  u.property = 'ga4_property_D'
   AND  u.traffic_source    = g.source
   AND  u.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
   AND  u.in_model
  WHERE g.date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY u.brand, g.date, g.source, g.campaign
)
SELECT
  brand,
  COUNT(*)                            AS rows_day_utm,
  SUM(sessions)                       AS sessions_total,
  COUNTIF(sessions < 50)              AS rows_under_50,
  SUM(IF(sessions < 50, sessions, 0)) AS sessions_in_rows_under_50,
  ROUND(SUM(IF(sessions < 50, sessions, 0)) / SUM(sessions) * 100, 1)
    AS pct_traffic_in_risk
FROM by_day
GROUP BY brand
ORDER BY pct_traffic_in_risk DESC;
