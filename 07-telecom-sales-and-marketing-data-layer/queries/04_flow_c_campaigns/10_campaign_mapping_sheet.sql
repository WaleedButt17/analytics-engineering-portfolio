CREATE OR REPLACE EXTERNAL TABLE `your-project.client_dataset.ext_campaign_mapping` (
  platform    STRING,
  campaign_name       STRING,
  brand         STRING,
  channel         STRING,
  kpi           STRING,
  account        STRING,
  ga4_property STRING,
  lead_basis    STRING,
  status        STRING,
  notes         STRING
)
OPTIONS (
  format            = 'GOOGLE_SHEETS',
  uris              = ['YOUR_MAPPING_SHEET_URL'],
  sheet_range       = 'bigquery mapping!A1:J5000',
  skip_leading_rows = 1
);

CREATE OR REPLACE VIEW `your-project.client_dataset.dim_campaign_client_v2` AS
SELECT
  LOWER(TRIM(platform))              AS platform,
  TRIM(campaign_name)                        AS campaign_name,
  LOWER(REGEXP_REPLACE(TRIM(campaign_name), r'\s+', ' ')) AS campaign_key,
  TRIM(brand)                          AS brand,
  NULLIF(TRIM(channel), '')              AS channel,
  UPPER(TRIM(kpi))                     AS kpi,
  TRIM(account)                         AS account,
  NULLIF(TRIM(ga4_property), '')      AS ga4_property,
  NULLIF(TRIM(lead_basis), '')         AS lead_basis,
  NULLIF(TRIM(status), '')             AS status,
  NULLIF(TRIM(notes), '')              AS notes
FROM `your-project.client_dataset.ext_campaign_mapping`
WHERE campaign_name IS NOT NULL AND TRIM(campaign_name) != '';

CREATE OR REPLACE VIEW `your-project.client_dataset.qc_campaigns_without_mapping_v2` AS
WITH spend_totals AS (
  SELECT 'google' AS platform, campaign, SUM(spend) AS spend,
         MIN(date) AS date_from, MAX(date) AS date_to
  FROM `your-project.client_dataset.google_ads_campaigns` GROUP BY campaign
  UNION ALL
  SELECT 'meta', campaign, SUM(spend), MIN(date), MAX(date)
  FROM `your-project.client_dataset.facebook_ads_campaigns` GROUP BY campaign
)
SELECT g.platform, g.campaign, ROUND(g.spend, 0) AS spend, g.date_from, g.date_to
FROM spend_totals g
LEFT JOIN `your-project.client_dataset.dim_campaign_client_v2` d
  ON d.platform = g.platform
 AND d.campaign_key = LOWER(REGEXP_REPLACE(TRIM(g.campaign), r'\s+', ' '))
WHERE d.campaign_name IS NULL
ORDER BY g.spend DESC;

CREATE OR REPLACE VIEW `your-project.client_dataset.qc_mapping_without_spend_v2` AS
WITH spend_totals AS (
  SELECT DISTINCT 'google' AS platform,
         LOWER(REGEXP_REPLACE(TRIM(campaign), r'\s+', ' ')) AS campaign_key
  FROM `your-project.client_dataset.google_ads_campaigns`
  UNION DISTINCT
  SELECT DISTINCT 'meta',
         LOWER(REGEXP_REPLACE(TRIM(campaign), r'\s+', ' '))
  FROM `your-project.client_dataset.facebook_ads_campaigns`
)
SELECT d.platform, d.campaign_name, d.brand, d.channel, d.notes
FROM `your-project.client_dataset.dim_campaign_client_v2` d
LEFT JOIN spend_totals g USING (platform, campaign_key)
WHERE g.campaign_key IS NULL
ORDER BY d.platform, d.campaign_name;
