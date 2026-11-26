CREATE OR REPLACE VIEW `your-project.marketing.dim_campaign` AS
SELECT
  TRIM(channel)                                        AS channel,
  TRIM(REGEXP_REPLACE(id_account, r'[\r\n].*$', ''))  AS id_account,
  TRIM(account_key)                                       AS account_key,
  CAST(campaign_id AS STRING)                        AS campaign_id,
  TRIM(campaign_name)                                      AS campaign_name,

  REGEXP_REPLACE(NORMALIZE(TRIM(campaign_name), NFKC), r'\s+', ' ') AS campaign_key,

  NULLIF(TRIM(category),  '')                       AS category,
  NULLIF(TRIM(brand),   '')                       AS brand,

  COALESCE(
    NULLIF(TRIM(initiative), ''),
    CASE REGEXP_REPLACE(NORMALIZE(TRIM(campaign_name), NFKC), r'\s+', ' ')
      WHEN 'PMax - Therapy Area 1 2025'          THEN 'Therapy Area 1 AON'
      WHEN 'Demand Gen - Therapy Area 1 2025'    THEN 'Therapy Area 1 AON'
      WHEN 'PMax - Therapy Area 2 2025'          THEN 'Brand F AON'
      WHEN 'Demand Gen - Therapy Area 2 2025'    THEN 'Brand F AON'
      WHEN 'Forms - Therapy Area 2 July 2025' THEN 'Brand F AON'
      WHEN 'Brand H_Video_Podcast_2026'   THEN 'Brand H AON'
    END
  )                                                  AS initiative,

  NULLIF(TRIM(initiative), '') IS NULL
    AND REGEXP_REPLACE(NORMALIZE(TRIM(campaign_name), NFKC), r'\s+', ' ') IN (
      'PMax - Therapy Area 1 2025', 'Demand Gen - Therapy Area 1 2025',
      'PMax - Therapy Area 2 2025', 'Demand Gen - Therapy Area 2 2025',
      'Forms - Therapy Area 2 July 2025', 'Brand H_Video_Podcast_2026'
    )                                                AS initiative_inferred,
  NULLIF(TRIM(objective),   '')                       AS objective,
  active_since,
  active_until,
  CAST(spend_total AS NUMERIC)                       AS spend_total,
  NULLIF(TRIM(notes), '')                            AS notes,
  NULLIF(TRIM(client_answer), '')                    AS client_answer,
  reviewed
FROM `your-project.marketing.dim_campaign_ext`
WHERE TRIM(COALESCE(channel, '')) != '';
