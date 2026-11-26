SELECT
  d.campaign_key,
  d.brand,
  d.channel,
  d.spend_total                        AS catalogue,
  ROUND(SUM(g.spend), 2)               AS ours,
  ROUND(SUM(g.spend) - d.spend_total, 2)                       AS difference,
  ROUND(100 * SAFE_DIVIDE(SUM(g.spend) - d.spend_total, d.spend_total), 1) AS pct,
  MIN(g.date)                          AS first_day,
  MAX(g.date)                          AS last_day,
  COUNT(DISTINCT g.date)               AS days_active
FROM `your-project.marketing.dim_campaign` d
JOIN `your-project.marketing.facebook_ads_campaigns_v2` g
  ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
WHERE d.brand = 'Brand C'
  AND LOWER(d.campaign_key) LIKE '%forms%'
GROUP BY d.campaign_key, d.brand, d.channel, d.spend_total;

WITH daily AS (
  SELECT
    g.date,
    SUM(g.spend) AS spend,
    ANY_VALUE(d.spend_total) AS catalogue
  FROM `your-project.marketing.dim_campaign` d
  JOIN `your-project.marketing.facebook_ads_campaigns_v2` g
    ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')

  WHERE d.campaign_key = 'Forms - Initiative C1 (Brand C) May 2026'
  GROUP BY g.date
),

cum_cte AS (
  SELECT
    date,
    spend,
    SUM(spend) OVER (ORDER BY date) AS cum,
    catalogue
  FROM daily
)
SELECT
  MAX(IF(cum <= catalogue, date, NULL))          AS cutoff_implicit,
  MAX(date)                                      AS last_day,
  DATE_DIFF(MAX(date), MAX(IF(cum <= catalogue, date, NULL)), DAY) AS days_after_cutoff,
  ROUND(MAX(catalogue), 2)                        AS catalogue,
  ROUND(SUM(spend), 2)                           AS ours,
  ROUND(SUM(IF(cum > catalogue, spend, 0)), 2)   AS spend_after_cutoff
FROM cum_cte;

WITH daily AS (
  SELECT
    d.campaign_key,
    d.brand,
    g.date,
    SUM(g.spend) AS spend,
    ANY_VALUE(d.spend_total) AS catalogue
  FROM `your-project.marketing.dim_campaign` d
  JOIN `your-project.marketing.facebook_ads_campaigns_v2` g
    ON d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
  WHERE d.spend_total IS NOT NULL AND d.spend_total > 0
  GROUP BY d.campaign_key, d.brand, g.date
),
cumulative AS (
  SELECT *, SUM(spend) OVER (PARTITION BY campaign_key ORDER BY date) AS cum
  FROM daily
)
SELECT
  campaign_key,
  brand,
  MAX(IF(cum <= catalogue, date, NULL)) AS cutoff_implicit,
  MAX(date)                             AS last_day,
  ROUND(MAX(catalogue), 2)               AS catalogue,
  ROUND(SUM(spend), 2)                  AS ours,
  ROUND(100 * SAFE_DIVIDE(SUM(spend) - MAX(catalogue), MAX(catalogue)), 1) AS pct
FROM cumulative
GROUP BY campaign_key, brand
HAVING ABS(pct) > 1
ORDER BY cutoff_implicit DESC, pct DESC;
