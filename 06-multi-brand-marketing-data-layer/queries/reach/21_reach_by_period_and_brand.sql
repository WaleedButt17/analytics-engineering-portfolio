CREATE OR REPLACE VIEW `your-project.marketing.vw_reach_period_brand_initiative` AS
WITH campaign_period AS (
  SELECT
    a.grain,
    a.period_start,
    a.period_end,
    d.brand,
    d.initiative,
    d.campaign_name,
    a.reach
  FROM `your-project.marketing.meta_reach_period` a
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Meta'
   AND  d.campaign_key = a.campaign_key
  WHERE a.reach IS NOT NULL
)
SELECT
  grain,
  period_start,
  ANY_VALUE(period_end)        AS period_end,
  brand,
  initiative,
  'Meta'                        AS channel,

  IF(COUNT(DISTINCT campaign_name) = 1, SUM(reach), NULL) AS reach_count,

  SUM(reach)                    AS reach_bound_upper,
  COUNT(DISTINCT campaign_name)       AS campaigns_in_period,
  COUNT(DISTINCT campaign_name) = 1   AS reach_is_exact,
  FALSE                         AS reach_is_additive
FROM campaign_period
GROUP BY grain, period_start, brand, initiative;

CREATE OR REPLACE VIEW `your-project.marketing.vw_reach_period_brand` AS
WITH campaign_period AS (
  SELECT
    a.grain, a.period_start, a.period_end,
    d.brand, d.campaign_name, a.reach
  FROM `your-project.marketing.meta_reach_period` a
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Meta'
   AND  d.campaign_key = a.campaign_key
  WHERE a.reach IS NOT NULL
)
SELECT
  grain,
  period_start,
  ANY_VALUE(period_end)      AS period_end,
  brand,
  'Meta'                      AS channel,
  IF(COUNT(DISTINCT campaign_name) = 1, SUM(reach), NULL) AS reach_count,
  SUM(reach)                  AS reach_bound_upper,
  COUNT(DISTINCT campaign_name)     AS campaigns_in_period,
  COUNT(DISTINCT campaign_name) = 1 AS reach_is_exact,
  FALSE                       AS reach_is_additive
FROM campaign_period
GROUP BY grain, period_start, brand;

CREATE OR REPLACE VIEW `your-project.marketing.qc_reach_additive` AS
WITH daily AS (
  SELECT
    d.brand,
    DATE_TRUNC(f.date, MONTH) AS period_start,
    SUM(f.reach)              AS reach_summed
  FROM `your-project.marketing.facebook_ads_campaigns_v2` f
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Meta'
   AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
  GROUP BY d.brand, period_start
)
SELECT
  p.brand,
  p.period_start,
  p.reach_count                AS reach_deduplicated,
  p.reach_bound_upper,
  p.campaigns_in_period,
  d.reach_summed,
  ROUND(SAFE_DIVIDE(d.reach_summed - p.reach_bound_upper,
                    p.reach_bound_upper) * 100, 1) AS overstatement_pct
FROM `your-project.marketing.vw_reach_period_brand` p
JOIN daily d
  ON  d.brand       = p.brand
 AND  d.period_start = p.period_start
WHERE p.grain = 'monthly'
ORDER BY p.period_start DESC, p.brand;

CREATE OR REPLACE VIEW `your-project.marketing.qc_reach_missing` AS
WITH spend_amount AS (
  SELECT
    d.brand,
    DATE_TRUNC(f.date, MONTH) AS period_start,
    ROUND(SUM(f.spend), 2)    AS spend
  FROM `your-project.marketing.facebook_ads_campaigns_v2` f
  JOIN `your-project.marketing.dim_campaign` d
    ON  d.channel       = 'Meta'
   AND  d.campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(f.campaign), NFKC), r'\s+', ' ')
  WHERE f.date >= '2025-07-01'
  GROUP BY d.brand, period_start
  HAVING SUM(f.spend) > 0
)
SELECT
  g.brand,
  g.period_start,
  g.spend,
  'no monthly reach row' AS problem
FROM spend_amount g
LEFT JOIN `your-project.marketing.vw_reach_period_brand` p
  ON  p.brand       = g.brand
 AND  p.period_start = g.period_start
 AND  p.grain          = 'monthly'
WHERE p.brand IS NULL
ORDER BY g.period_start DESC;
