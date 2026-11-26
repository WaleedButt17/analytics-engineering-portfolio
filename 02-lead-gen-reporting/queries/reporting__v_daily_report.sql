CREATE OR REPLACE VIEW `your-project.reporting.v_daily_report` AS
SELECT
  date,
  product,
  platform,
  region,
  phase,
  spend,
  main_spend,
  research_spend,
  impressions,
  clicks,
  ad_conversions,
  leads_accepted,
  leads_sold,
  leads_sold_paid,
  leads_sold_advertiser_a,
  leads_sold_na,
  leads_sold_advertiser_a_na,
  leads_sold_advertiser_a_paid,
  leads_sold_na_paid,
  leads_sold_partner_b,
  revenue,
  cpl,
  CASE 
    WHEN date = CURRENT_DATE('America/Los_Angeles') THEN CONCAT('1 - ', FORMAT_DATE('%A', date))
    WHEN date = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 1 DAY) THEN CONCAT('2 - ', FORMAT_DATE('%A', date))
    WHEN date = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 2 DAY) THEN CONCAT('3 - ', FORMAT_DATE('%A', date))
    WHEN date = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 3 DAY) THEN CONCAT('4 - ', FORMAT_DATE('%A', date))
    WHEN date = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 4 DAY) THEN CONCAT('5 - ', FORMAT_DATE('%A', date))
    WHEN date = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 5 DAY) THEN CONCAT('6 - ', FORMAT_DATE('%A', date))
    WHEN date = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 6 DAY) THEN CONCAT('7 - ', FORMAT_DATE('%A', date))
    ELSE '8 - Other'
  END AS day_order
FROM `your-project`.reporting.v_performance_by_product;
