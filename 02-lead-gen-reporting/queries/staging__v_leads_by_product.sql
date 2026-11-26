CREATE OR REPLACE VIEW `your-project.staging.v_leads_by_product` AS
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
    AND DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') >= '2026-05-20'
    AND lead_id NOT IN (SELECT lead_id FROM returned_ids)
    AND lead_id NOT IN (SELECT lead_id FROM hist_ids)
),
all_events AS (
  SELECT
    TIMESTAMP(inserted_at) AS event_ts,
    DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') AS lead_date,
    event_type, lead_id, vertical_name, utm_source, utm_source_custom,
    advertiser_name, contract_name,
    SAFE_CAST(sold_price AS FLOAT64) AS sold_price,
    state, affiliate_name AS affiliate
  FROM deduped_events
  WHERE rn = 1
    AND inserted_at IS NOT NULL
    AND DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') >= '2026-05-20'
  UNION ALL
  SELECT
    created_on AS event_ts, DATE(created_on) AS lead_date,
    'lead_accepted' AS event_type, lead_id, vertical AS vertical_name,
    utm_source, NULL AS utm_source_custom, NULL AS advertiser_name,
    NULL AS contract_name, NULL AS sold_price, state, NULL AS affiliate
  FROM `your-project`.Leadspedia.Lead_Accepted
  WHERE created_on IS NOT NULL
    AND DATE(created_on) < '2026-05-20'
    AND post_response IN ('Lead Accepted', 'Imported')
  UNION ALL
  SELECT
    date_sold AS event_ts, DATE(date_sold) AS lead_date,
    'lead_sold' AS event_type, lead_id, vertical AS vertical_name,
    utm_source, utm_source_custom, advertiser AS advertiser_name,
    contract AS contract_name, price AS sold_price, state, affiliate
  FROM deduped_sold
  WHERE rn = 1 AND date_sold IS NOT NULL AND DATE(date_sold) < '2026-05-20'
),
normalized AS (
  SELECT
    lead_date AS date, event_type, lead_id, sold_price, state, affiliate,
    CASE
      WHEN LOWER(contract_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
      WHEN LOWER(contract_name) LIKE '%group_03%' OR LOWER(contract_name) LIKE '%women%market%' THEN 'Womens Market NCL'
      WHEN LOWER(vertical_name) LIKE '%will kit - notification%' OR LOWER(vertical_name) LIKE '%cu member notification%' OR LOWER(vertical_name) LIKE '%member notification%' THEN 'Credit Union Benefit'
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
      WHEN LOWER(utm_source) LIKE '%tiktok%'
        OR LOWER(utm_source) LIKE '%ttclid%'
        OR LOWER(utm_source_custom) LIKE '%tiktok%' THEN 'tiktok'
      WHEN LOWER(utm_source) LIKE '%taboola%'
        OR LOWER(utm_source_custom) LIKE '%taboola%' THEN 'taboola'
      WHEN LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%google%' THEN 'google'
      WHEN LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%fb%'
        OR LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%facebook%'
        OR LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%meta%'
        OR LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%ig%'
        OR LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%instagram%'
        OR LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%partner c%' THEN 'meta'
      WHEN LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%microsoft%'
        OR LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%bing%' THEN 'microsoft'
      WHEN LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%quora%' THEN 'quora'
      WHEN LOWER(COALESCE(utm_source, utm_source_custom)) LIKE '%nextdoor%' THEN 'nextdoor'
      WHEN (utm_source IS NULL OR utm_source = '') THEN 'organic'
      ELSE 'other'
    END AS platform,
    CASE
      WHEN state IN ('AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT') THEN 'CAD'
      WHEN (state IS NULL OR state = '') AND (UPPER(contract_name) LIKE '%CAD%' OR UPPER(contract_name) LIKE '%GROUP_04%' OR UPPER(contract_name) LIKE '%GROUP_05%' OR UPPER(contract_name) LIKE '%GROUP_06%' OR UPPER(contract_name) LIKE '%GROUP_07%' OR UPPER(contract_name) LIKE '% - CA%') THEN 'CAD'
      WHEN state = 'NY' AND LOWER(vertical_name) NOT LIKE '%labor%' AND LOWER(vertical_name) NOT LIKE '%labour%' THEN 'NY'
      ELSE 'US'
    END AS region,
    CASE
      WHEN LOWER(advertiser_name) LIKE '%advertiser b%' OR LOWER(advertiser_name) LIKE '%advb%' THEN 'Advertiser B'
      WHEN LOWER(advertiser_name) LIKE '%advertiser a: advertiser c%' OR LOWER(advertiser_name) LIKE '%advertiser c%' THEN 'Advertiser C'
      WHEN LOWER(advertiser_name) LIKE '%advertiser a: advertiser d%' OR LOWER(advertiser_name) LIKE '%advertiser d%' THEN 'Advertiser D'
      WHEN LOWER(advertiser_name) LIKE '%advertiser a:%' THEN 'Advertiser A'
      WHEN LOWER(advertiser_name) LIKE '%advertiser a%' THEN 'Advertiser A'
      WHEN LOWER(advertiser_name) LIKE '%partner b%' THEN 'Partner B'
      WHEN LOWER(advertiser_name) LIKE '%advertiser e%' OR LOWER(advertiser_name) LIKE '%out of territory%' THEN 'Advertiser E'
      WHEN advertiser_name IS NULL OR advertiser_name = '' OR LOWER(advertiser_name) = 'n/a' THEN 'N/A'
      ELSE advertiser_name
    END AS advertiser,
    contract_name
  FROM all_events
)
SELECT
  date, product, platform, region,
  COUNT(CASE WHEN event_type = 'lead_accepted' THEN 1 END) AS leads_accepted,
  COUNT(CASE WHEN event_type = 'lead_sold' THEN 1 END) AS leads_sold,
  COUNT(CASE WHEN event_type = 'lead_sold' AND platform != 'organic' THEN 1 END) AS leads_sold_paid,
  COUNT(CASE WHEN event_type = 'lead_sold' AND advertiser = 'Advertiser A' AND COALESCE(affiliate, '') != 'Partner B Group - PB' THEN 1 END) AS leads_sold_advertiser_a,
  COUNT(CASE WHEN event_type = 'lead_sold' AND advertiser = 'N/A' THEN 1 END) AS leads_sold_na,
  COUNT(CASE WHEN event_type = 'lead_sold' AND advertiser IN ('Advertiser A','N/A') AND COALESCE(affiliate, '') != 'Partner B Group - PB' THEN 1 END) AS leads_sold_advertiser_a_na,
  COUNT(CASE WHEN event_type = 'lead_sold' AND advertiser = 'Advertiser A' AND COALESCE(affiliate, '') != 'Partner B Group - PB' AND platform != 'organic' THEN 1 END) AS leads_sold_advertiser_a_paid,
  COUNT(CASE WHEN event_type = 'lead_sold' AND advertiser = 'N/A' AND platform != 'organic' THEN 1 END) AS leads_sold_na_paid,
  COUNT(CASE WHEN event_type = 'lead_sold' AND affiliate = 'Partner B Group - PB' THEN 1 END) AS leads_sold_partner_b,
  SUM(CASE WHEN event_type = 'lead_sold' THEN COALESCE(sold_price, 0) ELSE 0 END) AS revenue,
  MAX(CASE WHEN event_type = 'lead_sold' THEN advertiser END) AS advertiser,
  MAX(CASE WHEN event_type = 'lead_sold' THEN contract_name END) AS contract_name
FROM normalized
GROUP BY 1, 2, 3, 4;
