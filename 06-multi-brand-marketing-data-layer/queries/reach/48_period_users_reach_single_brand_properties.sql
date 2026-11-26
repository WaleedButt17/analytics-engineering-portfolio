CREATE OR REPLACE VIEW `your-project.marketing.vw_users_period_brand` AS
WITH flagged AS (
  SELECT
    u.grain, u.period_start, u.period_end,
    m.brand, m.initiative,
    u.property, u.utm_key,
    u.total_users, u.new_users, u.sessions
  FROM `your-project.marketing.ga4_users_period` u
  JOIN `your-project.marketing.dim_utm_by_property` m
    ON  m.property = u.property
   AND  m.utm_key   = u.utm_key
),
count AS (
  SELECT grain, period_start, brand, initiative,
         MAX(n) AS n_utms
  FROM (
    SELECT grain, period_start, brand, initiative, property,
           COUNT(DISTINCT utm_key) AS n
    FROM flagged
    GROUP BY 1,2,3,4,5
  )
  GROUP BY 1,2,3,4
),
by_campaign AS (
  SELECT
    m.grain, m.period_start, ANY_VALUE(m.period_end) AS period_end,
    m.brand, m.initiative,
    ANY_VALUE(c.n_utms)                                   AS n_utms,
    IF(ANY_VALUE(c.n_utms) = 1, SUM(m.total_users), NULL) AS total_users,
    IF(ANY_VALUE(c.n_utms) = 1, SUM(m.new_users),   NULL) AS new_users,
    SUM(m.sessions)                                       AS sessions_period,
    IF(ANY_VALUE(c.n_utms) = 1, 'exact',
       'NA: the initiative is served by several utms and users cannot be summed') AS users_note
  FROM flagged m
  JOIN count c USING (grain, period_start, brand, initiative)
  GROUP BY m.grain, m.period_start, m.brand, m.initiative
),

single_brand AS (
  SELECT
    grain, period_start, period_end,
    CASE property
      WHEN 'ga4_property_B' THEN 'Brand B'
      WHEN 'ga4_property_A' THEN 'Brand A'
    END                        AS brand,
    CAST(NULL AS STRING)       AS initiative,
    1                          AS n_utms,
    total_users,
    new_users,
    sessions                   AS sessions_period,
    'exact: single-brand property total' AS users_note
  FROM `your-project.marketing.ga4_users_period`
  WHERE utm_key = '(property total)'
    AND property IN ('ga4_property_B', 'ga4_property_A')
)
SELECT * FROM by_campaign
UNION ALL
SELECT * FROM single_brand;

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
),
by_campaign AS (
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
  GROUP BY grain, period_start, brand, initiative
),

single_brand AS (
  SELECT
    grain,
    period_start,
    period_end,
    'Brand A'                  AS brand,
    CAST(NULL AS STRING)       AS initiative,
    'Meta'                     AS channel,
    reach                      AS reach_count,
    reach                      AS reach_bound_upper,
    1                          AS campaigns_in_period,
    TRUE                       AS reach_is_exact,
    FALSE                      AS reach_is_additive
  FROM `your-project.marketing.meta_reach_period`
  WHERE campaign_key = '(property total)'
    AND account_key = 'META_ACCOUNT_3'
    AND reach IS NOT NULL
)
SELECT * FROM by_campaign
UNION ALL
SELECT * FROM single_brand;

SELECT brand, grain, COUNT(*) AS n_rows, MAX(period_end) AS latest,
       COUNTIF(total_users IS NOT NULL) AS with_users
FROM `your-project.marketing.vw_users_period_brand`
GROUP BY 1,2 ORDER BY 1,2;

SELECT brand, grain, COUNT(*) AS n_rows, MAX(period_end) AS latest,
       COUNTIF(reach_count IS NOT NULL) AS with_reach
FROM `your-project.marketing.vw_reach_period_brand_initiative`
GROUP BY 1,2 ORDER BY 1,2;
