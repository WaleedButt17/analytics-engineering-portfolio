CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_e_v2` AS
WITH by_utm AS (

  SELECT
    g.date,
    g.source,
    g.campaign,
    MAX(g.sessions)                 AS sessions,
    MAX(g.average_session_duration) AS avg_session_duration,
    SUM(IF(g.event_name = 'registration_complete', g.event_count, 0)) AS leads,
    SUM(IF(g.event_name = 'first_visit',           g.event_count, 0)) AS new_users
  FROM `your-project.marketing.ga4_brand_e` g
  WHERE g.source IN ('google', 'meta')
  GROUP BY g.date, g.source, g.campaign
)
SELECT
  p.date,
  CASE p.source WHEN 'meta' THEN 'Meta' WHEN 'google' THEN 'Google' END AS channel,
  m.initiative,
  SUM(p.leads)      AS leads,
  SUM(p.sessions)   AS sessions,
  SUM(p.new_users)  AS new_users,

  SAFE_DIVIDE(SUM(p.avg_session_duration * p.sessions), SUM(p.sessions))
    AS avg_session_duration
FROM by_utm p
JOIN `your-project.marketing.dim_utm` m
  ON  m.property = 'ga4_property_E'
 AND  m.traffic_source    = p.source
 AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(p.campaign), NFKC), r'\s+', ' ')
 AND  m.brand  = 'Brand E'
 AND  m.in_model
GROUP BY p.date, channel, m.initiative;

CREATE OR REPLACE VIEW `your-project.marketing.dim_utm_complement` AS
SELECT * FROM UNNEST([
  STRUCT<property STRING, traffic_source STRING, utm_campaign STRING,
         brand STRING, initiative STRING,
         is_paid BOOL, in_model BOOL,
         status STRING, sessions_observed INT64, evidence STRING>

  ('ga4_property_E','PARTNER','initiative_f3_syllabus','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',193,'Initiative F3 course pages; partner portal referral, not paid'),
  ('ga4_property_E','partner','initiative_f3_syllabus','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',6,'Lowercase variant of the row above, same source'),
  ('ga4_property_E','whatsapp','initiative_f3_course_registration','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',128,'Initiative F3 registration, WhatsApp distribution'),
  ('ga4_property_E','email','initiative_f3_course_registration','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',1,'Same utm, email distribution'),
  ('ga4_property_E','email','initiative_f3_modules','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',4,'Initiative F3 module pages, email distribution'),

  ('ga4_property_E','email','brand_h_ep_01_season_02','Brand H',NULL,
   FALSE, FALSE,'owned_media',110,'Podcast episode 1 season 2, email. Brand has no paid GA4 presence'),
  ('ga4_property_E','email','brand_h_ep_01_season_02/season-1','Brand H',NULL,
   FALSE, FALSE,'owned_media',2,'Path suffix left on the utm value by the tagging'),

  ('ga4_property_E','newsletter','brand_c_clinical_case_1','Brand C',NULL,
   FALSE, FALSE,'owned_media',4,'Brand C clinical case, newsletter'),
  ('ga4_property_E','email','brand_c_message_1','Brand C',NULL,
   FALSE, FALSE,'owned_media',2,'Brand C messaging, email'),
  ('ga4_property_E','email','brand_c_message_2','Brand C',NULL,
   FALSE, FALSE,'owned_media',1,'Brand C messaging, email'),

  ('ga4_property_E','email','product_y_event',NULL,NULL,
   FALSE, FALSE,'out_of_scope',21,'Another product outside the six brands'),
  ('ga4_property_E','email','other_ta_message_1',NULL,NULL,
   FALSE, FALSE,'out_of_scope',3,'Messaging for another therapy area, no brand layer in scope'),
  ('ga4_property_E','email','other_ta_study-update',NULL,NULL,
   FALSE, FALSE,'out_of_scope',1,'Study update for another product, no brand layer in scope'),
  ('ga4_property_E','mass email','other_ta_message_2',NULL,NULL,
   FALSE, FALSE,'out_of_scope',10,'Unidentified send, no brand evidence')
]);

CREATE OR REPLACE VIEW `your-project.marketing.qc_utm_orphan_v2` AS
WITH observed AS (
  SELECT
    'ga4_property_E' AS property, source AS traffic_source, campaign AS utm_campaign,
    MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  GROUP BY date, source, campaign
  UNION ALL
  SELECT 'ga4_property_D', source, campaign, MAX(sessions)
  FROM `your-project.marketing.ga4_brand_d`
  GROUP BY date, source, campaign
),
aggregated AS (
  SELECT
    property, traffic_source, utm_campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ') AS utm_key,
    SUM(sessions) AS sessions
  FROM observed
  GROUP BY property, traffic_source, utm_campaign
),
known AS (
  SELECT property, traffic_source, utm_key
  FROM `your-project.marketing.dim_utm`
  UNION DISTINCT
  SELECT property, traffic_source,
         REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ')
  FROM `your-project.marketing.dim_utm_complement`
)
SELECT a.property, a.traffic_source, a.utm_campaign, a.sessions
FROM aggregated a
LEFT JOIN known c
  ON  c.property = a.property
 AND  c.traffic_source    = a.traffic_source
 AND  c.utm_key   = a.utm_key
WHERE c.property IS NULL
  AND a.sessions > 0
ORDER BY a.sessions DESC;
