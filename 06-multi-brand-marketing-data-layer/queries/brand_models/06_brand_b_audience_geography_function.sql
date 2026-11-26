CREATE OR REPLACE TABLE FUNCTION `your-project.marketing.tf_brand_b_population`(
  date_start DATE, date_end DATE
) AS
WITH campaign_names AS (
  SELECT DISTINCT campaign_platform, campaign_sheet
  FROM `your-project.marketing.dim_content_brand_b`
  WHERE channel = 'Google'
),

city_base AS (
  SELECT
    d.campaign,

    CASE WHEN d.city IN ('Capital City', 'Capital City Alt 1', 'Capital City Alt 2')
         THEN 'Capital' ELSE d.city END AS name_city,
    SUM(d.clicks) AS click_count
  FROM `your-project.marketing.google_ads_demographics_city` d
  JOIN campaign_names c ON c.campaign_platform = d.campaign
  WHERE d.date BETWEEN date_start AND date_end
    AND d.city IS NOT NULL AND d.city != ''
  GROUP BY 1, 2
),

city_rank AS (
  SELECT campaign, name_city,
    SAFE_DIVIDE(click_count, SUM(click_count) OVER (PARTITION BY campaign)) AS pct,
    ROW_NUMBER() OVER (PARTITION BY campaign ORDER BY click_count DESC) AS rn
  FROM city_base
)

SELECT
  c.campaign_sheet AS campaign_name,
  CONCAT(
    'The ', CAST(CAST(ROUND(c1.pct * 100) AS INT64) AS STRING),
    '% of clicks come from ', c1.name_city,
    IFNULL(CONCAT(', followed by ', CAST(CAST(ROUND(c2.pct * 100) AS INT64) AS STRING),
                  '% from ', c2.name_city), ''),
    '.'
  ) AS population
FROM campaign_names c
JOIN      city_rank c1 ON c1.campaign = c.campaign_platform AND c1.rn = 1
LEFT JOIN city_rank c2 ON c2.campaign = c.campaign_platform AND c2.rn = 2;
