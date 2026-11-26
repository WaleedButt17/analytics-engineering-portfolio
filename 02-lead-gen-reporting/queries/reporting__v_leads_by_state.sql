CREATE OR REPLACE VIEW `your-project.reporting.v_leads_by_state` AS
WITH returned_ids AS (
  SELECT r.lead_id
  FROM `your-project`.Leadspedia.Lead_Returns r
  WHERE r.event_type = 'lead_return_approved'
    AND NOT EXISTS (
      SELECT 1 FROM `your-project`.Leadspedia.Lead_Returns u
      WHERE u.lead_id = r.lead_id AND u.event_type = 'lead_unreturned'
        AND TIMESTAMP(u.inserted_at) > TIMESTAMP(r.inserted_at)
    )
    AND NOT EXISTS (
      SELECT 1 FROM `your-project`.Leadspedia.Events_Leadspedia e
      WHERE e.lead_id = r.lead_id AND e.event_type = 'lead_sold'
        AND TIMESTAMP(e.inserted_at) > TIMESTAMP(r.inserted_at)
    )
),
deduped_sold AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY lead_id ORDER BY date_sold DESC) AS rn
  FROM `your-project`.Leadspedia.Lead_Sold
  WHERE (returned IS NULL OR returned != 'Yes')
    AND lead_id NOT IN (SELECT lead_id FROM returned_ids)
),
hist_ids AS (
  SELECT lead_id FROM deduped_sold
  WHERE rn = 1 AND date_sold IS NOT NULL AND DATE(date_sold) < '2026-05-20'
),
deduped_events AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY lead_id, event_type
      ORDER BY CASE WHEN advertiser_name = 'N/A' THEN 1 ELSE 0 END, inserted_at DESC
    ) AS rn
  FROM `your-project`.Leadspedia.Events_Leadspedia
  WHERE event_type = 'lead_sold'
    AND lead_id NOT IN (SELECT lead_id FROM returned_ids)
    AND lead_id NOT IN (SELECT lead_id FROM hist_ids)
),
historical AS (
  SELECT
    DATE(date_created) AS lead_date,
    CASE
      WHEN UPPER(TRIM(state)) IN (
        'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA',
        'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
        'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT',
        'VA','WA','WV','WI','WY','DC',
        'AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT'
      ) THEN UPPER(TRIM(state))
      ELSE 'Other'
    END AS state,
    CASE
      WHEN LOWER(campaign) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(campaign) LIKE '%veteran kit%' THEN 'Veteran Kit'
      WHEN LOWER(campaign) LIKE '%will kit%' AND LOWER(campaign) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(campaign) LIKE '%no cost law%' AND LOWER(campaign) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(campaign) LIKE '%no cost law%' AND LOWER(campaign) LIKE '%women%' THEN 'Womens Market NCL'
      WHEN LOWER(campaign) LIKE '%no cost law%' THEN 'No Cost Law'
      WHEN LOWER(campaign) LIKE '%will kit%' THEN 'No Cost Law'
      WHEN LOWER(campaign) LIKE '%safetykit%' THEN 'Child Safety Kit'
      WHEN LOWER(campaign) LIKE '%child safe kit spanish%' THEN 'Child Safe Kit Spanish'
      WHEN LOWER(campaign) LIKE '%credit union%' OR LOWER(campaign) LIKE '%zoho%' THEN 'CU'
      WHEN LOWER(campaign) LIKE '%labor lead%' THEN 'Labor Lead'
      WHEN LOWER(campaign) LIKE '%final expense%' THEN 'Final Expense'
      WHEN LOWER(campaign) LIKE '%mortgage%' THEN 'Mortgage Protection'
      ELSE 'Other'
    END AS product,
    CASE
      WHEN UPPER(TRIM(state)) IN ('AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT') THEN 'CAD'
      WHEN UPPER(TRIM(state)) = 'NY' AND LOWER(campaign) NOT LIKE '%labor%' AND LOWER(campaign) NOT LIKE '%labour%' THEN 'NY'
      ELSE 'US'
    END AS region,
    COUNT(*) AS leads
  FROM deduped_sold
  WHERE rn = 1
    AND state IS NOT NULL AND state != ''
    AND date_sold IS NOT NULL
    AND DATE(date_sold) < '2026-05-20'
  GROUP BY 1, 2, 3, 4
),
live AS (
  SELECT
    DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') AS lead_date,
    CASE
      WHEN UPPER(TRIM(state)) IN (
        'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA',
        'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
        'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT',
        'VA','WA','WV','WI','WY','DC',
        'AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT'
      ) THEN UPPER(TRIM(state))
      ELSE 'Other'
    END AS state,
    CASE
      WHEN LOWER(campaign_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(campaign_name) LIKE '%veteran kit%' THEN 'Veteran Kit'
      WHEN LOWER(campaign_name) LIKE '%will kit%' AND LOWER(campaign_name) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(campaign_name) LIKE '%no cost law%' AND LOWER(campaign_name) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(campaign_name) LIKE '%no cost law%' AND LOWER(campaign_name) LIKE '%women%' THEN 'Womens Market NCL'
      WHEN LOWER(campaign_name) LIKE '%no cost law%' THEN 'No Cost Law'
      WHEN LOWER(campaign_name) LIKE '%will kit%' THEN 'No Cost Law'
      WHEN LOWER(campaign_name) LIKE '%safetykit%' THEN 'Child Safety Kit'
      WHEN LOWER(campaign_name) LIKE '%child safe kit spanish%' THEN 'Child Safe Kit Spanish'
      WHEN LOWER(campaign_name) LIKE '%credit union%' OR LOWER(campaign_name) LIKE '%zoho%' THEN 'CU'
      WHEN LOWER(campaign_name) LIKE '%labor lead%' THEN 'Labor Lead'
      WHEN LOWER(campaign_name) LIKE '%final expense%' THEN 'Final Expense'
      WHEN LOWER(campaign_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
      ELSE 'Other'
    END AS product,
    CASE
      WHEN UPPER(TRIM(state)) IN ('AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT') THEN 'CAD'
      WHEN UPPER(TRIM(state)) = 'NY' AND LOWER(campaign_name) NOT LIKE '%labor%' AND LOWER(campaign_name) NOT LIKE '%labour%' THEN 'NY'
      ELSE 'US'
    END AS region,
    COUNT(*) AS leads
  FROM deduped_events
  WHERE rn = 1
    AND state IS NOT NULL AND state != ''
    AND DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') >= '2026-05-20'
  GROUP BY 1, 2, 3, 4
)
SELECT * FROM historical
UNION ALL
SELECT * FROM live;
