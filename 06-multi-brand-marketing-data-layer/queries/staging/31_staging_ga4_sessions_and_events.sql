CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_sessions_base` AS
WITH by_medium AS (

  SELECT
    'ga4_property_E' AS property,
    date,
    campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
    source,
    session_source_medium,
    sessions, average_session_duration, totalusers, newusers,
    SAFE_CAST(bounce_rate     AS FLOAT64) AS bounce_rate,
    SAFE_CAST(engagement_rate AS FLOAT64) AS engagement_rate
  FROM `your-project.marketing.ga4_brand_e_sessions`
  UNION ALL
  SELECT
    'ga4_property_D',
    date,
    campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' '),
    source,
    session_source_medium,
    sessions, average_session_duration, totalusers, newusers,
    SAFE_CAST(bounce_rate     AS FLOAT64),
    SAFE_CAST(engagement_rate AS FLOAT64)
  FROM `your-project.marketing.ga4_brand_d_sessions`
)

SELECT
  property,
  date,
  utm_key,
  ANY_VALUE(campaign) AS campaign,
  source,
  SUM(sessions)  AS sessions,
  SUM(newusers)  AS new_users,

  IF(COUNT(DISTINCT session_source_medium) = 1, SUM(totalusers), NULL) AS total_users,
  SUM(totalusers)                       AS total_users_bound_upper,
  COUNT(DISTINCT session_source_medium) AS media_cte,
  SAFE_DIVIDE(SUM(average_session_duration * sessions), SUM(sessions)) AS avg_session_duration,
  SAFE_DIVIDE(SUM(bounce_rate     * sessions), SUM(sessions)) AS bounce_rate,
  SAFE_DIVIDE(SUM(engagement_rate * sessions), SUM(sessions)) AS engagement_rate
FROM by_medium
GROUP BY property, date, utm_key, source;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_events_base` AS
WITH raw_value AS (
  SELECT
    'ga4_property_E' AS property,
    date,
    campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' ') AS utm_key,
    source,
    event_name,
    event_count
  FROM `your-project.marketing.ga4_brand_e`
  UNION ALL
  SELECT
    'ga4_property_D',
    date,
    campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(campaign), NFKC), r'\s+', ' '),
    source,
    event_name,
    event_count
  FROM `your-project.marketing.ga4_brand_d`
)
SELECT
  property,
  date,
  utm_key,
  ANY_VALUE(campaign) AS campaign,
  source,
  SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads
FROM raw_value
GROUP BY property, date, utm_key, source;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_c_v3` AS
SELECT
  s.date,
  CASE s.source
    WHEN 'meta'   THEN 'Meta'
    WHEN 'google' THEN 'Google'
    WHEN 'dv360'  THEN 'DV360'
  END AS channel,
  m.initiative,
  SUM(IFNULL(e.leads, 0)) AS leads,
  SUM(s.sessions)         AS sessions,
  SUM(s.new_users)        AS new_users,
  IF(LOGICAL_AND(s.media_cte = 1), SUM(s.total_users), NULL) AS total_users,
  SUM(s.total_users_bound_upper) AS total_users_bound_upper,
  SAFE_DIVIDE(SUM(s.avg_session_duration * s.sessions), SUM(s.sessions)) AS avg_session_duration,
  SAFE_DIVIDE(SUM(s.bounce_rate     * s.sessions), SUM(s.sessions)) AS bounce_rate,
  SAFE_DIVIDE(SUM(s.engagement_rate * s.sessions), SUM(s.sessions)) AS engagement_rate
FROM `your-project.marketing.stg_ga4_sessions_base` s
LEFT JOIN `your-project.marketing.stg_ga4_events_base` e
  ON  e.property = s.property
 AND  e.date      = s.date
 AND  e.source    = s.source
 AND  e.utm_key   = s.utm_key
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = s.property
 AND  m.traffic_source    = s.source
 AND  m.utm_key   = s.utm_key
 AND  m.brand  = 'Brand C'
 AND  m.in_model
GROUP BY s.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_e_v3` AS
SELECT
  s.date,
  CASE s.source WHEN 'meta' THEN 'Meta' WHEN 'google' THEN 'Google' END AS channel,
  m.initiative,
  SUM(IFNULL(e.leads, 0)) AS leads,
  SUM(s.sessions)         AS sessions,
  SUM(s.new_users)        AS new_users,
  IF(LOGICAL_AND(s.media_cte = 1), SUM(s.total_users), NULL) AS total_users,
  SUM(s.total_users_bound_upper) AS total_users_bound_upper,
  SAFE_DIVIDE(SUM(s.avg_session_duration * s.sessions), SUM(s.sessions)) AS avg_session_duration,
  SAFE_DIVIDE(SUM(s.bounce_rate     * s.sessions), SUM(s.sessions)) AS bounce_rate,
  SAFE_DIVIDE(SUM(s.engagement_rate * s.sessions), SUM(s.sessions)) AS engagement_rate
FROM `your-project.marketing.stg_ga4_sessions_base` s
LEFT JOIN `your-project.marketing.stg_ga4_events_base` e
  ON  e.property = s.property AND e.date = s.date
 AND  e.source    = s.source    AND e.utm_key = s.utm_key
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = s.property
 AND  m.traffic_source    = s.source
 AND  m.utm_key   = s.utm_key
 AND  m.brand  = 'Brand E'
 AND  m.in_model
WHERE s.property = 'ga4_property_E'
GROUP BY s.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_d_v3` AS
SELECT
  s.date,
  CASE s.source
    WHEN 'meta'  THEN 'Meta'
    WHEN 'dv360' THEN 'DV360'
  END AS channel,
  m.initiative,
  SUM(s.sessions)  AS sessions,
  SUM(s.new_users) AS new_users,
  IF(LOGICAL_AND(s.media_cte = 1), SUM(s.total_users), NULL) AS total_users,
  SUM(s.total_users_bound_upper) AS total_users_bound_upper,
  SAFE_DIVIDE(SUM(s.avg_session_duration * s.sessions), SUM(s.sessions)) AS avg_session_duration,
  SAFE_DIVIDE(SUM(s.bounce_rate     * s.sessions), SUM(s.sessions)) AS bounce_rate,
  SAFE_DIVIDE(SUM(s.engagement_rate * s.sessions), SUM(s.sessions)) AS engagement_rate
FROM `your-project.marketing.stg_ga4_sessions_base` s
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = s.property
 AND  m.traffic_source    = s.source
 AND  m.utm_key   = s.utm_key
 AND  m.brand  = 'Brand D'
 AND  m.in_model
WHERE s.property = 'ga4_property_D'
GROUP BY s.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.qc_media_looker` AS
WITH by_medium AS (
  SELECT 'ga4_property_E' AS property, date, campaign, source, session_source_medium, sessions
  FROM `your-project.marketing.ga4_brand_e_sessions`
  UNION ALL
  SELECT 'ga4_property_D', date, campaign, source, session_source_medium, sessions
  FROM `your-project.marketing.ga4_brand_d_sessions`
),
aggregated AS (
  SELECT
    m.brand,
    m.initiative,
    p.campaign,
    p.session_source_medium,
    DATE_TRUNC(p.date, MONTH) AS month_start,
    SUM(p.sessions)           AS sessions
  FROM by_medium p
  JOIN `your-project.marketing.dim_utm` m
    ON  m.property = p.property
   AND  m.traffic_source    = p.source
   AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
   AND  m.in_model
  GROUP BY m.brand, m.initiative, p.campaign, p.session_source_medium, month_start
)

SELECT
  brand,
  initiative,
  campaign,
  session_source_medium,
  month_start,
  sessions,
  ROUND(sessions / SUM(sessions) OVER (PARTITION BY brand, campaign, month_start) * 100, 1)
    AS pct_of_total
FROM aggregated
ORDER BY month_start DESC, brand, sessions DESC;
