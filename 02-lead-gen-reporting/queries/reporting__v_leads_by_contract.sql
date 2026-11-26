CREATE OR REPLACE VIEW `your-project.reporting.v_leads_by_contract` AS
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
    DATE(date_sold) AS lead_date,
    contract AS contract_name,
    CASE
      WHEN contract LIKE '% - PB' THEN
        TRIM(SPLIT(REPLACE(contract, ' - PB', ''), ' - ')[ORDINAL(ARRAY_LENGTH(SPLIT(REPLACE(contract, ' - PB', ''), ' - ')))])
      WHEN contract LIKE '%Catchall%' OR contract LIKE '%Catcahall%' THEN 'Catchall'
      ELSE TRIM(SPLIT(contract, ' - ')[ORDINAL(ARRAY_LENGTH(SPLIT(contract, ' - ')))])
    END AS group_code,
    CASE
      WHEN contract IN ('CONTRACT_01','CONTRACT_02','CONTRACT_03') THEN 'CU'
      WHEN LOWER(contract) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(contract) LIKE '%veteran kit%' THEN 'Veteran Kit'
      WHEN LOWER(contract) LIKE '%credit union%' OR LOWER(contract) LIKE '%zoho%' THEN 'CU'
      WHEN LOWER(contract) LIKE '%labor lead%' THEN 'Labor Lead'
      WHEN LOWER(contract) LIKE '%will kit%' AND LOWER(contract) LIKE '%final expense%' THEN 'Final Expense'
      WHEN LOWER(contract) LIKE '%will kit%' AND LOWER(contract) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(contract) LIKE '%no cost law%' AND LOWER(contract) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(contract) LIKE '%no cost law%' AND LOWER(contract) LIKE '%women%' THEN 'Womens Market NCL'
      WHEN LOWER(contract) LIKE '%no cost law%' THEN 'No Cost Law'
      WHEN LOWER(contract) LIKE '%will kit%' THEN 'No Cost Law'
      WHEN LOWER(contract) LIKE '%safetykit%' THEN 'Child Safety Kit'
      WHEN LOWER(contract) LIKE '%child safe kit spanish%' THEN 'Child Safe Kit Spanish'
      WHEN LOWER(contract) LIKE '%final expense%' THEN 'Final Expense'
      ELSE 'Other'
    END AS product,
    CASE
      WHEN UPPER(contract) LIKE '%CAD%' OR UPPER(contract) LIKE '%GROUP_04%' OR UPPER(contract) LIKE '%GROUP_05%'
        OR UPPER(contract) LIKE '%GROUP_06%' OR UPPER(contract) LIKE '%GROUP_07%' OR UPPER(contract) LIKE '% - CA%' THEN 'CAD'
      WHEN UPPER(contract) LIKE '%NY%' THEN 'NY'
      ELSE 'US'
    END AS region,
    COUNT(*) AS leads,
    COUNTIF(utm_source IS NOT NULL AND utm_source != '') AS leads_paid
  FROM deduped_sold
  WHERE rn = 1
    AND contract IS NOT NULL AND contract != ''
    AND DATE(date_sold) < '2026-05-20'
    AND COALESCE(affiliate, '') NOT LIKE '%Partner B%'
    AND COALESCE(advertiser, '') NOT IN ('N/A', '', 'Advertiser A: Advertiser C', 'Advertiser A: Advertiser D')
    AND contract NOT IN ('CONTRACT_02', 'CONTRACT_03', 'CONTRACT_01')
    AND advertiser IS NOT NULL
  GROUP BY 1, 2, 3, 4, 5
),
live AS (
  SELECT
    DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') AS lead_date,
    contract_name,
    CASE
      WHEN contract_name LIKE '% - PB' THEN
        TRIM(SPLIT(REPLACE(contract_name, ' - PB', ''), ' - ')[ORDINAL(ARRAY_LENGTH(SPLIT(REPLACE(contract_name, ' - PB', ''), ' - ')))])
      WHEN contract_name LIKE '%Catchall%' OR contract_name LIKE '%Catcahall%' THEN 'Catchall'
      ELSE TRIM(SPLIT(contract_name, ' - ')[ORDINAL(ARRAY_LENGTH(SPLIT(contract_name, ' - ')))])
    END AS group_code,
    CASE
      WHEN contract_name IN ('CONTRACT_01','CONTRACT_02','CONTRACT_03') THEN 'CU'
      WHEN LOWER(contract_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(contract_name) LIKE '%veteran kit%' THEN 'Veteran Kit'
      WHEN LOWER(contract_name) LIKE '%credit union%' OR LOWER(contract_name) LIKE '%zoho%' THEN 'CU'
      WHEN LOWER(contract_name) LIKE '%labor lead%' THEN 'Labor Lead'
      WHEN LOWER(contract_name) LIKE '%will kit%' AND LOWER(contract_name) LIKE '%final expense%' THEN 'Final Expense'
      WHEN LOWER(contract_name) LIKE '%will kit%' AND LOWER(contract_name) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(contract_name) LIKE '%no cost law%' AND LOWER(contract_name) LIKE '%spanish%' THEN 'Spanish NCL'
      WHEN LOWER(contract_name) LIKE '%no cost law%' AND LOWER(contract_name) LIKE '%women%' THEN 'Womens Market NCL'
      WHEN LOWER(contract_name) LIKE '%no cost law%' THEN 'No Cost Law'
      WHEN LOWER(contract_name) LIKE '%will kit%' THEN 'No Cost Law'
      WHEN LOWER(contract_name) LIKE '%safetykit%' THEN 'Child Safety Kit'
      WHEN LOWER(contract_name) LIKE '%child safe kit spanish%' THEN 'Child Safe Kit Spanish'
      WHEN LOWER(contract_name) LIKE '%final expense%' THEN 'Final Expense'
      ELSE 'Other'
    END AS product,
    CASE
      WHEN UPPER(contract_name) LIKE '%CAD%' OR UPPER(contract_name) LIKE '%GROUP_04%' OR UPPER(contract_name) LIKE '%GROUP_05%'
        OR UPPER(contract_name) LIKE '%GROUP_06%' OR UPPER(contract_name) LIKE '%GROUP_07%' OR UPPER(contract_name) LIKE '% - CA%' THEN 'CAD'
      WHEN UPPER(contract_name) LIKE '%NY%' THEN 'NY'
      ELSE 'US'
    END AS region,
    COUNT(*) AS leads,
    COUNTIF(utm_source IS NOT NULL AND utm_source != '') AS leads_paid
  FROM deduped_events
  WHERE rn = 1
    AND contract_name IS NOT NULL AND contract_name != ''
    AND DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') >= '2026-05-20'
    AND COALESCE(affiliate_name, '') NOT LIKE '%Partner B%'
    AND COALESCE(advertiser_name, '') NOT IN ('N/A', '', 'Advertiser A: Advertiser C', 'Advertiser A: Advertiser D')
    AND contract_name NOT IN ('CONTRACT_02', 'CONTRACT_03', 'CONTRACT_01')
    AND advertiser_name IS NOT NULL
  GROUP BY 1, 2, 3, 4, 5
)
SELECT * FROM historical
UNION ALL
SELECT * FROM live;
