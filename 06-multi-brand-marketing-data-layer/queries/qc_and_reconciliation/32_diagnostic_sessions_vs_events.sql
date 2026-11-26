WITH old_version AS (
  SELECT
    m.initiative,
    p.campaign,
    p.source,
    SUM(p.sessions) AS sessions,
    SUM(p.leads)    AS leads
  FROM (
    SELECT date, source, campaign,
           MAX(sessions) AS sessions,
           SUM(IF(event_name = 'registration_complete', event_count, 0)) AS leads
    FROM `your-project.marketing.ga4_brand_e`
    GROUP BY date, source, campaign
  ) p
  JOIN `your-project.marketing.dim_utm` m
    ON  m.property = 'ga4_property_E'
   AND  m.traffic_source    = p.source
   AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
   AND  m.brand  = 'Brand F'
   AND  m.in_model
  GROUP BY m.initiative, p.campaign, p.source
),
new_version AS (
  SELECT
    m.initiative,
    s.campaign,
    s.source,
    SUM(s.sessions)         AS sessions,
    SUM(IFNULL(e.leads, 0)) AS leads
  FROM `your-project.marketing.stg_ga4_sessions_base` s
  LEFT JOIN `your-project.marketing.stg_ga4_events_base` e
    ON  e.property = s.property AND e.date = s.date
   AND  e.source    = s.source    AND e.utm_key = s.utm_key
  JOIN `your-project.marketing.dim_utm` m
    ON  m.property = s.property
   AND  m.traffic_source    = s.source
   AND  m.utm_key   = s.utm_key
   AND  m.brand  = 'Brand F'
   AND  m.in_model
  WHERE s.property = 'ga4_property_E'
  GROUP BY m.initiative, s.campaign, s.source
)
SELECT
  COALESCE(v.initiative, n.initiative) AS initiative,
  COALESCE(v.campaign,   n.campaign)   AS campaign,
  COALESCE(v.source,     n.source)     AS source,
  v.sessions AS ses_event,
  n.sessions AS ses_session,
  IFNULL(n.sessions, 0) - IFNULL(v.sessions, 0) AS diff_sessions,
  v.leads    AS reads_event,
  n.leads    AS reads_session,
  IFNULL(n.leads, 0) - IFNULL(v.leads, 0) AS diff_leads
FROM old_version v
FULL OUTER JOIN new_version n USING (initiative, campaign, source)
WHERE IFNULL(n.sessions, 0) != IFNULL(v.sessions, 0)
   OR IFNULL(n.leads, 0)    != IFNULL(v.leads, 0)
ORDER BY ABS(IFNULL(n.sessions, 0) - IFNULL(v.sessions, 0)) DESC;
