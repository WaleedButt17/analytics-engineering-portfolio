CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_c_v2` AS
SELECT
  g.date,
  'Google'           AS channel,
  d.initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns_v2` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
 AND  d.brand    = 'Brand C'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
GROUP BY g.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_e_v2` AS
SELECT
  g.date,
  'Google'           AS channel,
  d.initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns_v2` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
 AND  d.brand    = 'Brand E'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
GROUP BY g.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_f` AS
SELECT
  g.date,
  'Google'           AS channel,
  d.initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns_v2` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
 AND  d.brand    = 'Brand F'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
GROUP BY g.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_g` AS
SELECT
  g.date,
  'Google'           AS channel,
  d.initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns_v2` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
 AND  d.brand    = 'Brand G'
 AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
GROUP BY g.date, d.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_google_brand_b_v3` AS
SELECT
  g.date,
  'Google'        AS channel,
  'Brand B AON' AS initiative,
  SUM(g.spend)       AS spend,
  SUM(g.clicks)      AS clicks,
  SUM(g.impressions) AS impressions,
  CAST(NULL AS NUMERIC) AS reach_daily
FROM `your-project.marketing.google_ads_campaigns_v2` g
JOIN `your-project.marketing.dim_campaign` d
  ON  d.channel       = 'Google'
  AND d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
  AND (d.id_account  = g.account_id OR g.account_id IS NULL)
WHERE d.brand = 'Brand B'
GROUP BY g.date;

WITH old_version AS (
  SELECT d.brand, ROUND(SUM(g.spend), 2) AS spend,
         SUM(g.clicks) AS clicks, COUNT(DISTINCT g.date) AS days
  FROM `your-project.marketing.google_ads_campaigns` g
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Google'
   AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
  GROUP BY d.brand
),
new_version AS (
  SELECT d.brand, ROUND(SUM(g.spend), 2) AS spend,
         SUM(g.clicks) AS clicks, COUNT(DISTINCT g.date) AS days
  FROM `your-project.marketing.google_ads_campaigns_v2` g
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Google'
   AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(g.campaign), NFKC), r'\s+', ' ')
  GROUP BY d.brand
)
SELECT
  COALESCE(v.brand, n.brand) AS brand,
  v.spend AS spend_production, n.spend AS spend_v2,
  ROUND(IFNULL(n.spend,0) - IFNULL(v.spend,0), 2) AS difference,
  v.days  AS days_production,  n.days  AS days_v2
FROM old_version v
FULL OUTER JOIN new_version n USING (brand)
ORDER BY brand;
