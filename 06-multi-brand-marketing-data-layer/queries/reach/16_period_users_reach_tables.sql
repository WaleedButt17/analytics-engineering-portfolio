CREATE TABLE IF NOT EXISTS `your-project.marketing.ga4_users_period` (
  property      STRING NOT NULL,
  site          STRING,
  utm_campaign   STRING,
  utm_key        STRING,
  grain          STRING NOT NULL,
  period_start DATE   NOT NULL,
  period_end    DATE   NOT NULL,
  total_users    INT64,
  new_users      INT64,
  sessions       INT64,
  loaded_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY period_start
CLUSTER BY grain, property;

CREATE TABLE IF NOT EXISTS `your-project.marketing.meta_reach_period` (
  account_key         STRING NOT NULL,
  account_label  STRING,
  campaign_name        STRING,
  campaign_key    STRING,
  campaign_id    STRING,
  grain          STRING NOT NULL,
  period_start DATE   NOT NULL,
  period_end    DATE   NOT NULL,
  reach          INT64,
  impressions    INT64,
  loaded_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY period_start
CLUSTER BY grain, account_key;

CREATE OR REPLACE VIEW `your-project.marketing.qc_users_period` AS
WITH period AS (
  SELECT property, grain, period_start, period_end, utm_key,
         total_users, sessions AS sessions_period
  FROM `your-project.marketing.ga4_users_period`
),
daily AS (
  SELECT 'ga4_property_E' AS property,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
         date, MAX(sessions) AS ses
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY 1,2,3
  UNION ALL
  SELECT 'ga4_property_D',
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' '),
         date, MAX(sessions)
  FROM `your-project.marketing.ga4_brand_d`
  GROUP BY 1,2,3
)
SELECT p.property, p.grain, p.period_start, p.utm_key,
       p.total_users,
       p.sessions_period,
       SUM(d.ses)                      AS sessions_summed,
       p.sessions_period - SUM(d.ses) AS difference
FROM period p
LEFT JOIN daily d
  ON  d.property = p.property
 AND  d.utm_key   = p.utm_key
 AND  d.date BETWEEN p.period_start AND p.period_end
GROUP BY 1,2,3,4,5,6
HAVING ABS(difference) > 2
ORDER BY ABS(difference) DESC;
