CREATE OR REPLACE VIEW `your-project.reporting.v_lead_order_recap` AS
WITH weekly_leads_by_contract AS (
  SELECT
    group_code,
    product,
    region,
    SUM(leads) AS leads_to_date,
    SUM(leads_paid) AS leads_paid_to_date
  FROM `your-project`.reporting.v_leads_by_contract
  WHERE lead_date >= DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND group_code != 'Catchall'
  GROUP BY 1, 2, 3
),

weekly_leads_by_product AS (
  SELECT
    product,
    SUM(leads) AS total_product_leads
  FROM `your-project`.reporting.v_leads_by_contract
  WHERE lead_date >= DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND group_code != 'Catchall'
  GROUP BY 1
),

weekly_spend_by_product AS (
  SELECT
    CASE WHEN product = 'Credit Union Benefit' THEN 'CU' ELSE product END AS product,
    SUM(main_spend) AS total_main_spend,
    SUM(research_spend) AS total_research_spend
  FROM `your-project`.staging.v_spend_by_campaign
  WHERE date >= DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND product NOT IN ('Unknown', 'All Products')
  GROUP BY 1
),

contract_spend AS (
  SELECT
    wlc.group_code,
    wlc.product,
    wlc.region,
    wlc.leads_to_date,
    wlc.leads_paid_to_date,
    ROUND(
      SAFE_DIVIDE(wlc.leads_to_date, wlp.total_product_leads) * COALESCE(ws.total_main_spend, 0)
    , 2) AS main_spend,
    ROUND(
      SAFE_DIVIDE(wlc.leads_to_date, wlp.total_product_leads) * COALESCE(ws.total_research_spend, 0)
    , 2) AS research_spend
  FROM weekly_leads_by_contract wlc
  LEFT JOIN weekly_leads_by_product wlp
    ON wlc.product = wlp.product
  LEFT JOIN weekly_spend_by_product ws
    ON wlc.product = ws.product
),

budget AS (
  SELECT
    group_code,
    CAST(budget AS FLOAT64) AS budget,
    week_start
  FROM `your-project`.Mapping.Lead_Order_Budget
  WHERE CAST(week_start AS DATE) = DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
)

SELECT
  cs.group_code,
  cs.product,
  cs.region,
  cs.leads_to_date,
  cs.leads_paid_to_date,
  cs.main_spend,
  cs.research_spend,
  COALESCE(b.budget, 0) AS budget,
  CASE
    WHEN COALESCE(b.budget, 0) > 0
    THEN ROUND(cs.main_spend / b.budget * 100, 1)
    ELSE NULL
  END AS pct_budget
FROM contract_spend cs
LEFT JOIN budget b
  ON cs.group_code = b.group_code
ORDER BY cs.product, cs.region, cs.leads_to_date DESC;
