CREATE OR REPLACE VIEW `your-project.staging.v_leads_by_affiliate` AS
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
)
SELECT
  DATE(date_sold) AS date, affiliate, COUNT(*) AS leads_sold
FROM deduped_sold
WHERE rn = 1 AND date_sold IS NOT NULL AND DATE(date_sold) < '2026-05-20'
GROUP BY 1, 2
UNION ALL
SELECT
  DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') AS date,
  affiliate_name AS affiliate,
  COUNT(*) AS leads_sold
FROM deduped_events
WHERE rn = 1
  AND inserted_at IS NOT NULL
  AND DATE(TIMESTAMP(inserted_at), 'America/Los_Angeles') >= '2026-05-20'
GROUP BY 1, 2;
