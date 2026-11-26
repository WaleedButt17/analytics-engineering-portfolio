CREATE OR REPLACE VIEW `your-project.reporting.v_financial_summary` AS
WITH

royalty_tier AS (
  SELECT royalty_rate_per_lead
  FROM `your-project`.staging.ytd_will_kit_leads
),

weekly_leads AS (
  SELECT
    DATE_TRUNC(date, WEEK(MONDAY)) AS week_start,
    advertiser,
    product,
    SUM(leads_sold) AS leads_sold
  FROM `your-project`.staging.v_leads_by_advertiser
  WHERE advertiser IS NOT NULL AND advertiser != ''
  GROUP BY 1, 2, 3
),

weekly_accepted AS (
  SELECT
    DATE_TRUNC(date, WEEK(MONDAY)) AS week_start,
    SUM(leads_accepted) AS leads_accepted
  FROM `your-project`.staging.v_leads_by_product
  GROUP BY 1
),

weekly_spend AS (
  SELECT
    DATE_TRUNC(date, WEEK(MONDAY)) AS week_start,
    product,
    platform,
    SUM(spend) AS spend
  FROM `your-project`.staging.v_spend_by_campaign
  WHERE product NOT IN ('Unknown', 'All Products')
  GROUP BY 1, 2, 3
),

paid_leads_total AS (
  SELECT
    DATE_TRUNC(date, WEEK(MONDAY)) AS week_start,
    product,
    SUM(leads_sold) AS total_leads_sold
  FROM `your-project`.staging.v_leads_by_advertiser
  WHERE advertiser IS NOT NULL AND advertiser != ''
  GROUP BY 1, 2
),

advertiser_product_share AS (
  SELECT
    wl.week_start,
    wl.advertiser,
    wl.product,
    wl.leads_sold,
    pt.total_leads_sold,
    SAFE_DIVIDE(wl.leads_sold, pt.total_leads_sold) AS lead_share
  FROM weekly_leads wl
  LEFT JOIN paid_leads_total pt
    ON wl.week_start = pt.week_start
    AND wl.product = pt.product
),

advertiser_spend AS (
  SELECT
    aps.week_start,
    aps.advertiser,
    SUM(ws.spend * aps.lead_share) AS allocated_spend
  FROM advertiser_product_share aps
  LEFT JOIN weekly_spend ws
    ON aps.week_start = ws.week_start
    AND aps.product = ws.product
  WHERE aps.advertiser NOT IN ('Advertiser D', 'N/A', 'Partner B')
  GROUP BY 1, 2
),

weekly_advertiser_totals AS (
  SELECT
    week_start,
    advertiser,
    SUM(leads_sold) AS leads_sold
  FROM weekly_leads
  GROUP BY 1, 2
),

kit_costs AS (
  SELECT
    wl.week_start,
    wl.advertiser,
    SUM(wl.leads_sold * kr.kit_cost) AS kit_cost
  FROM weekly_leads wl
  LEFT JOIN `your-project`.Leadspedia.kit_royalty_rates kr
    ON wl.product = kr.product
  WHERE wl.advertiser != 'Advertiser D'
  GROUP BY 1, 2
),

royalty_costs AS (
  SELECT
    wl.week_start,
    wl.advertiser,
    SUM(
      CASE
        WHEN kr.tiered_royalty_applies = TRUE
          AND wl.advertiser IN ('Advertiser A', 'N/A')
        THEN wl.leads_sold * rt.royalty_rate_per_lead
        WHEN kr.fixed_royalty > 0
          AND wl.advertiser != 'Advertiser D'
        THEN wl.leads_sold * kr.fixed_royalty
        ELSE 0
      END
    ) AS royalty_cost
  FROM weekly_leads wl
  LEFT JOIN `your-project`.Leadspedia.kit_royalty_rates kr
    ON wl.product = kr.product
  CROSS JOIN royalty_tier rt
  GROUP BY 1, 2
),

combined AS (
  SELECT
    wat.week_start,
    DATE_ADD(wat.week_start, INTERVAL 6 DAY) AS week_end,
    wat.advertiser,
    wa.leads_accepted,
    wat.leads_sold,
    ROUND(COALESCE(asp.allocated_spend, 0), 2)  AS ad_spend,
    ROUND(COALESCE(kc.kit_cost, 0), 2)           AS kit_cost,
    ROUND(COALESCE(rc.royalty_cost, 0), 2)       AS royalty_cost,
    ROUND(wat.leads_sold * 2.1124052309220329, 2) AS fixed_cpl_cost
  FROM weekly_advertiser_totals wat
  LEFT JOIN weekly_accepted wa
    ON wat.week_start = wa.week_start
  LEFT JOIN advertiser_spend asp
    ON wat.week_start = asp.week_start
    AND wat.advertiser = asp.advertiser
  LEFT JOIN kit_costs kc
    ON wat.week_start = kc.week_start
    AND wat.advertiser = kc.advertiser
  LEFT JOIN royalty_costs rc
    ON wat.week_start = rc.week_start
    AND wat.advertiser = rc.advertiser
)

SELECT
  week_start,
  week_end,
  advertiser,
  leads_accepted,
  leads_sold,
  ad_spend,
  kit_cost,
  royalty_cost,
  fixed_cpl_cost,
  ROUND(ad_spend + kit_cost + royalty_cost + fixed_cpl_cost, 2) AS total_cost,

  CASE
    WHEN advertiser IN ('Advertiser D', 'N/A', 'Advertiser C') THEN NULL
    WHEN leads_sold > 0
    THEN ROUND((ad_spend + kit_cost + royalty_cost + fixed_cpl_cost) / leads_sold, 4)
    ELSE NULL
  END AS total_cpl,

  CASE
    WHEN advertiser IN ('Advertiser D', 'N/A', 'Advertiser C') THEN NULL
    WHEN leads_sold > 0
    THEN FLOOR((ad_spend + kit_cost + royalty_cost + fixed_cpl_cost) / leads_sold + 4)
    ELSE NULL
  END AS sold_price,

  CASE
    WHEN advertiser IN ('Advertiser D', 'N/A', 'Advertiser C') THEN NULL
    WHEN leads_sold > 0
    THEN leads_sold * FLOOR((ad_spend + kit_cost + royalty_cost + fixed_cpl_cost) / leads_sold + 4)
    ELSE NULL
  END AS invoiced,

  CASE
    WHEN advertiser IN ('Advertiser D', 'N/A', 'Advertiser C') THEN NULL
    WHEN leads_sold > 0
    THEN (leads_sold * FLOOR((ad_spend + kit_cost + royalty_cost + fixed_cpl_cost) / leads_sold + 4))
         - (ad_spend + kit_cost + royalty_cost + fixed_cpl_cost)
    ELSE ROUND(-(kit_cost + royalty_cost + fixed_cpl_cost), 2)
  END AS profit

FROM combined
ORDER BY week_start DESC, advertiser;
