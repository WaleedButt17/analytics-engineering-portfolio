CREATE OR REPLACE VIEW `your-project.marketing.dim_utm_by_property` AS
SELECT property, utm_key,
       ANY_VALUE(utm_campaign) AS utm_campaign,
       ANY_VALUE(brand)     AS brand,
       ANY_VALUE(initiative)   AS initiative
FROM `your-project.marketing.dim_utm`
WHERE in_model
GROUP BY property, utm_key;

CREATE OR REPLACE VIEW `your-project.marketing.qc_utm_brand_ambiguous` AS
SELECT property, utm_key,
       COUNT(DISTINCT brand)   AS n_brands,
       COUNT(DISTINCT initiative) AS n_initiatives,
       STRING_AGG(DISTINCT brand)   AS brands,
       STRING_AGG(DISTINCT initiative) AS initiatives
FROM `your-project.marketing.dim_utm`
WHERE in_model
GROUP BY property, utm_key
HAVING COUNT(DISTINCT brand) > 1 OR COUNT(DISTINCT initiative) > 1;

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
)
SELECT
  m.grain, m.period_start, ANY_VALUE(m.period_end) AS period_end,
  m.brand, m.initiative,
  ANY_VALUE(c.n_utms)                                 AS n_utms,
  IF(ANY_VALUE(c.n_utms) = 1, SUM(m.total_users), NULL) AS total_users,
  IF(ANY_VALUE(c.n_utms) = 1, SUM(m.new_users),   NULL) AS new_users,
  SUM(m.sessions)                                     AS sessions_period,
  IF(ANY_VALUE(c.n_utms) = 1, 'exact',
     'NA: the initiative is served by several utms and users cannot be summed') AS users_note
FROM flagged m
JOIN count c USING (grain, period_start, brand, initiative)
GROUP BY m.grain, m.period_start, m.brand, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.vw_reach_period_brand_initiative` AS
WITH flagged AS (
  SELECT r.grain, r.period_start, r.period_end,
         d.brand, d.initiative, r.campaign_key, r.reach, r.impressions
  FROM `your-project.marketing.meta_reach_period` r
  JOIN `your-project.marketing.dim_campaign` d
    ON d.channel = 'Meta' AND d.campaign_key = r.campaign_key
),
count AS (
  SELECT grain, period_start, brand, initiative,
         COUNT(DISTINCT campaign_key) AS n_campaigns
  FROM flagged GROUP BY 1,2,3,4
)
SELECT
  m.grain, m.period_start, ANY_VALUE(m.period_end) AS period_end,
  m.brand, m.initiative,
  ANY_VALUE(c.n_campaigns)                               AS n_campaigns,
  IF(ANY_VALUE(c.n_campaigns) = 1, SUM(m.reach), NULL)   AS reach,
  SUM(m.impressions)                                    AS impressions_period,
  IF(ANY_VALUE(c.n_campaigns) = 1, 'exact',
     'NA: the initiative is served by several campaigns and reach cannot be summed') AS reach_note
FROM flagged m
JOIN count c USING (grain, period_start, brand, initiative)
GROUP BY m.grain, m.period_start, m.brand, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.qc_users_greater_than_sessions` AS
SELECT grain, period_start, brand, initiative,
       total_users, sessions_period,
       total_users - sessions_period AS excess
FROM `your-project.marketing.vw_users_period_brand`
WHERE total_users > sessions_period
ORDER BY excess DESC;

CREATE OR REPLACE VIEW `your-project.marketing.vw_conversion_period` AS
WITH leads AS (
  SELECT grain, period_start, brand, initiative,
         SUM(leads) AS leads, SUM(sessions) AS sessions
  FROM `your-project.marketing.rollup_base_brand_c`
  GROUP BY 1,2,3,4
  UNION ALL
  SELECT grain, period_start, brand, initiative,
         SUM(leads), SUM(sessions)
  FROM `your-project.marketing.rollup_base_brand_e`
  GROUP BY 1,2,3,4
)
SELECT
  u.grain,
  u.period_start,
  u.period_end,
  u.brand,
  u.initiative,
  l.leads,
  l.sessions,
  u.total_users,
  u.new_users,
  u.n_utms,
  SAFE_DIVIDE(l.leads, u.total_users) AS conversion_rate_users,
  SAFE_DIVIDE(l.leads, l.sessions)    AS conversion_rate_sessions,
  u.users_note,
  'not reconciled against Looker; see reconciliation record 5, section 13' AS conversion_users_note
FROM `your-project.marketing.vw_users_period_brand` u
LEFT JOIN leads l
  USING (grain, period_start, brand, initiative)
WHERE u.brand IN ('Brand C', 'Brand E');

CREATE OR REPLACE VIEW `your-project.marketing.vw_conversion_campaign_period` AS
WITH events_cte AS (
  SELECT 'ga4_property_E' AS property, date,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
         SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY 1,2,3
  UNION ALL
  SELECT 'ga4_property_D', date,
         REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' '),
         SUM(IF(event_name = 'registration_complete', event_count, 0))
  FROM `your-project.marketing.ga4_brand_d`
  GROUP BY 1,2,3
),
leads_period AS (
  SELECT u.grain, u.period_start, u.property, u.utm_key,
         SUM(e.leads) AS leads
  FROM `your-project.marketing.ga4_users_period` u
  JOIN events_cte e
    ON  e.property = u.property
   AND  e.utm_key   = u.utm_key
   AND  e.date BETWEEN u.period_start AND u.period_end
  GROUP BY 1,2,3,4
)
SELECT
  u.grain,
  u.period_start,
  u.period_end,
  u.property,
  u.site,
  m.brand,
  m.initiative,
  u.utm_campaign,
  l.leads,
  u.sessions,
  u.total_users,
  u.new_users,
  SAFE_DIVIDE(l.leads, u.total_users) AS conversion_rate_users,
  SAFE_DIVIDE(l.leads, u.sessions)    AS conversion_rate_sessions,
  'campaign x period x property: the grain Looker publishes at' AS grain_note
FROM `your-project.marketing.ga4_users_period` u
JOIN `your-project.marketing.dim_utm_by_property` m
  ON  m.property = u.property
 AND  m.utm_key   = u.utm_key

LEFT JOIN leads_period l
  ON  l.grain          = u.grain
 AND  l.period_start = u.period_start
 AND  l.property      = u.property
 AND  l.utm_key        = u.utm_key;
