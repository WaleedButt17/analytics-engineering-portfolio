CREATE OR REPLACE VIEW `your-project.reporting.v_leads_by_advertiser` AS
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
historical_sold AS (
  SELECT
    DATE(date_sold) AS date,
    CASE
      WHEN LOWER(contract) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(vertical) LIKE '%veteran%' THEN 'Veteran Kit'
      WHEN LOWER(vertical) LIKE '%spanish%' AND LOWER(vertical) LIKE '%safetykit%' THEN 'Spanish Child Safety Kit'
      WHEN LOWER(vertical) LIKE '%spanish%' AND (LOWER(vertical) LIKE '%ncl%' OR LOWER(vertical) LIKE '%no cost%') THEN 'Spanish NCL'
      WHEN LOWER(vertical) LIKE '%child safe%' OR (LOWER(vertical) LIKE '%spanish%' AND LOWER(vertical) LIKE '%csk%') THEN 'Child Safe Kit Spanish'
      WHEN LOWER(vertical) LIKE '%no cost law%' OR LOWER(vertical) LIKE '%nocostlaw%' OR (LOWER(vertical) LIKE '%ncl%' AND LOWER(vertical) NOT LIKE '%spanish%') THEN 'No Cost Law'
      WHEN LOWER(vertical) LIKE '%safetykit%' AND LOWER(vertical) NOT LIKE '%spanish%' THEN 'Child Safety Kit'
      WHEN LOWER(vertical) LIKE '%credit union%' OR LOWER(vertical) LIKE '%creditunion%' THEN 'Credit Union Benefit'
      WHEN LOWER(vertical) LIKE '%labor%' OR LOWER(vertical) LIKE '%labour%' THEN 'Labor Lead'
      WHEN LOWER(vertical) LIKE '%womens%' OR LOWER(vertical) LIKE '%women%' THEN 'Womens Market NCL'
      WHEN LOWER(vertical) LIKE '%final expense%' THEN 'Final Expense'
      WHEN LOWER(vertical) LIKE '%mortgage%' THEN 'Mortgage Protection'
      ELSE vertical
    END AS product,
    CASE
      WHEN contract = 'CONTRACT_01' THEN 'Advertiser C'
      WHEN contract IN ('CONTRACT_02', 'CONTRACT_03') THEN 'Advertiser D'
      WHEN contract IN ('Child Safe Kit Spanish - US - GROUP_01', 'Will Kit - No Cost Law Spanish - US - GROUP_02') THEN 'Advertiser B'
      WHEN LOWER(contract) LIKE '%catchall%' THEN 'N/A'
      ELSE 'Advertiser A'
    END AS advertiser,
    contract AS contract_name,
    price AS sold_price
  FROM deduped_sold
  WHERE rn = 1 AND date_sold IS NOT NULL AND DATE(date_sold) < '2026-05-20'
),
live_sold AS (
  SELECT
    DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') AS date,
    CASE
      WHEN LOWER(contract_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(vertical_name) LIKE '%veteran%' THEN 'Veteran Kit'
      WHEN LOWER(vertical_name) LIKE '%spanish%' AND LOWER(vertical_name) LIKE '%safetykit%' THEN 'Spanish Child Safety Kit'
      WHEN LOWER(vertical_name) LIKE '%spanish%' AND (LOWER(vertical_name) LIKE '%ncl%' OR LOWER(vertical_name) LIKE '%no cost%') THEN 'Spanish NCL'
      WHEN LOWER(vertical_name) LIKE '%child safe%' OR (LOWER(vertical_name) LIKE '%spanish%' AND LOWER(vertical_name) LIKE '%csk%') THEN 'Child Safe Kit Spanish'
      WHEN LOWER(vertical_name) LIKE '%no cost law%' OR LOWER(vertical_name) LIKE '%nocostlaw%' OR (LOWER(vertical_name) LIKE '%ncl%' AND LOWER(vertical_name) NOT LIKE '%spanish%') THEN 'No Cost Law'
      WHEN LOWER(vertical_name) LIKE '%safetykit%' AND LOWER(vertical_name) NOT LIKE '%spanish%' THEN 'Child Safety Kit'
      WHEN LOWER(vertical_name) LIKE '%credit union%' OR LOWER(vertical_name) LIKE '%creditunion%' THEN 'Credit Union Benefit'
      WHEN LOWER(vertical_name) LIKE '%labor%' OR LOWER(vertical_name) LIKE '%labour%' THEN 'Labor Lead'
      WHEN LOWER(vertical_name) LIKE '%womens%' OR LOWER(vertical_name) LIKE '%women%' THEN 'Womens Market NCL'
      WHEN LOWER(vertical_name) LIKE '%final expense%' THEN 'Final Expense'
      WHEN LOWER(vertical_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
      ELSE vertical_name
    END AS product,
    CASE
      WHEN LOWER(advertiser_name) LIKE '%advertiser b%' OR LOWER(advertiser_name) LIKE '%advb%' THEN 'Advertiser B'
      WHEN LOWER(advertiser_name) LIKE '%advertiser a: advertiser c%' OR LOWER(advertiser_name) LIKE '%advertiser c%' THEN 'Advertiser C'
      WHEN LOWER(advertiser_name) LIKE '%advertiser a: advertiser d%' OR LOWER(advertiser_name) LIKE '%advertiser d%' THEN 'Advertiser D'
      WHEN advertiser_name IS NULL OR advertiser_name = '' OR LOWER(advertiser_name) = 'n/a' THEN 'N/A'
      ELSE 'Advertiser A'
    END AS advertiser,
    contract_name,
    SAFE_CAST(sold_price AS FLOAT64) AS sold_price
  FROM deduped_events
  WHERE rn = 1
    AND inserted_at IS NOT NULL
    AND DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') >= '2026-05-20'
)
SELECT
  date, product, advertiser,
  MAX(contract_name) AS contract_name,
  COUNT(*) AS leads_sold,
  SUM(COALESCE(sold_price, 0)) AS revenue
FROM (
  SELECT date, product, advertiser, contract_name, sold_price FROM historical_sold
  UNION ALL
  SELECT date, product, advertiser, contract_name, sold_price FROM live_sold
)
GROUP BY 1, 2, 3;
