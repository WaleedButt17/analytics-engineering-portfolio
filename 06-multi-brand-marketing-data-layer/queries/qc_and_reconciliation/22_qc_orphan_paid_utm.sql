CREATE OR REPLACE VIEW `your-project.marketing.qc_utm_orphan_paid` AS
WITH observed AS (
  SELECT 'ga4_property_E' AS property, date, source AS traffic_source,
         campaign AS utm_campaign, MAX(sessions) AS sessions
  FROM `your-project.marketing.ga4_brand_e`
  WHERE date >= '2025-07-01'
  GROUP BY date, source, campaign
  UNION ALL
  SELECT 'ga4_property_D', date, source, campaign, MAX(sessions)
  FROM `your-project.marketing.ga4_brand_d`
  WHERE date >= '2025-07-01'
  GROUP BY date, source, campaign
),
aggregated AS (
  SELECT
    property,
    traffic_source,
    utm_campaign,
    REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ') AS utm_key,
    SUM(sessions) AS sessions,
    MIN(date)     AS first_day,
    MAX(date)     AS last_day
  FROM observed
  GROUP BY property, traffic_source, utm_campaign
),
known AS (

  SELECT property, LOWER(TRIM(traffic_source)) AS traffic_source, utm_key
  FROM `your-project.marketing.dim_utm`
  UNION DISTINCT
  SELECT property, LOWER(TRIM(traffic_source)),
         REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ')
  FROM `your-project.marketing.dim_utm_complement`
)
SELECT
  a.property, a.traffic_source, a.utm_campaign, a.sessions,
  a.first_day, a.last_day
FROM aggregated a
LEFT JOIN known c
  ON  c.property = a.property
 AND  c.traffic_source    = LOWER(TRIM(a.traffic_source))
 AND  c.utm_key   = a.utm_key
WHERE c.property IS NULL

  AND a.utm_campaign NOT IN
      ('(direct)','(organic)','(not set)','(cross-network)','(referral)',
       '(ai-assistant)','(data not available)','')
  AND a.utm_campaign IS NOT NULL

  AND LOWER(TRIM(a.traffic_source)) NOT IN
      ('email','mail','newsletter','whatsapp','messaging','mass email',
       'partner','rte','groups-society','realaudiences','(direct)','(not set)',
       '(data not available)','bing','yahoo','duckduckgo')
  AND NOT REGEXP_CONTAINS(LOWER(a.utm_campaign), r'^\(.*\)$')
  AND NOT REGEXP_CONTAINS(LOWER(a.traffic_source), r'\.(com|io|net|org|mx|live|microsoft)')

ORDER BY a.sessions DESC;

CREATE OR REPLACE VIEW `your-project.marketing.dim_utm_complement` AS
SELECT * FROM UNNEST([
  STRUCT<property STRING, traffic_source STRING, utm_campaign STRING,
         brand STRING, initiative STRING,
         is_paid BOOL, in_model BOOL,
         status STRING, sessions_observed INT64, evidence STRING>

  ('ga4_property_E','meta','aon_brand_c','Brand C',NULL,
   TRUE, FALSE,'previous_agency',22522,
   'Ran 2025-05-09 to 2025-06-25. Earliest catalogued Brand C campaign is 2025-12-01 and the catalogue itself begins 2025-07-21, so this predates it entirely'),
  ('ga4_property_E','equativ','aon_brand_c','Brand C',NULL,
   TRUE, FALSE,'programmatic_alt',6850,
   'Equativ programmatic, 2025-05-12 to 2025-06-25. The client excluded programmatic on 18 August'),
  ('ga4_property_E','newsletter','aon_brand_c','Brand C',NULL,
   FALSE, FALSE,'owned_media',51,
   'Tail of the same tag reused in a newsletter, 2025-07 to 2025-08'),
  ('ga4_property_E','equative','aon_brand_g','Brand G',NULL,
   TRUE, FALSE,'programmatic_alt',299,
   'Equativ misspelled in the tagging. Same exclusion as aon_brand_g, which the client ruled an account warm-up'),

  ('ga4_property_E','PARTNER','initiative_f3_syllabus','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',193,'Initiative F3 course pages, partner portal referral'),
  ('ga4_property_E','partner','initiative_f3_syllabus','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',6,'Lowercase spelling of the row above'),
  ('ga4_property_E','whatsapp','initiative_f3_course_registration','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',128,'Initiative F3 registration, WhatsApp distribution'),
  ('ga4_property_E','email','initiative_f3_course_registration','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',1,'Same utm, email distribution'),
  ('ga4_property_E','email','initiative_f3_modules','Brand F','Initiative F3 2026',
   FALSE, FALSE,'owned_media',4,'Initiative F3 module pages, email'),

  ('ga4_property_E','email','brand_h_ep_01_season_02','Brand H',NULL,
   FALSE, FALSE,'owned_media',110,'Podcast, email. The brand has no PAID GA4 presence, which is the narrower and correct claim'),
  ('ga4_property_E','email','brand_h_ep_01_season_02/season-1','Brand H',NULL,
   FALSE, FALSE,'owned_media',2,'Path suffix left on the utm value by the tagging'),
  ('ga4_property_E','newsletter','brand_h_ep03','Brand H',NULL,
   FALSE, FALSE,'owned_media',224,'Podcast episode 3, newsletter'),

  ('ga4_property_E','newsletter','brand_c_clinical_case_1','Brand C',NULL,
   FALSE, FALSE,'owned_media',4,'Clinical case, newsletter'),
  ('ga4_property_E','email','brand_c_message_1','Brand C',NULL,
   FALSE, FALSE,'owned_media',2,'Brand messaging, email'),
  ('ga4_property_E','email','brand_c_message_2','Brand C',NULL,
   FALSE, FALSE,'owned_media',1,'Brand messaging, email'),

  ('ga4_property_E','email','product_y_event',NULL,NULL,
   FALSE, FALSE,'out_of_scope',21,'Another product with no layer in this engagement'),
  ('ga4_property_E','email','other_ta_message_1',NULL,NULL,
   FALSE, FALSE,'out_of_scope',3,'Messaging for another therapy area, no brand layer in scope'),
  ('ga4_property_E','email','other_ta_study-update',NULL,NULL,
   FALSE, FALSE,'out_of_scope',1,'Study update for another product, no brand layer in scope'),
  ('ga4_property_E','mass email','other_ta_message_2',NULL,NULL,
   FALSE, FALSE,'out_of_scope',10,'Unidentified send, no brand evidence')
]);
