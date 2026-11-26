CREATE OR REPLACE VIEW `your-project.reporting.v_leads_by_state_weekly` AS
SELECT
  state,
  region,
  product,
  CAST(SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)) THEN leads ELSE 0 END) AS INT64) AS this_week,
  CAST(SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), MONTH) THEN leads ELSE 0 END) AS INT64) AS mtd,
  CAST(SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), YEAR) THEN leads ELSE 0 END) AS INT64) AS ytd,
  CAST(SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), MONTH) THEN leads ELSE 0 END) 
    - SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)) THEN leads ELSE 0 END) AS INT64) AS mtd_delta,
  CAST(SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), YEAR) THEN leads ELSE 0 END)
    - SUM(CASE WHEN lead_date >= DATE_TRUNC(CURRENT_DATE(), MONTH) THEN leads ELSE 0 END) AS INT64) AS ytd_delta
FROM `your-project`.reporting.v_leads_by_state
GROUP BY 1, 2, 3;
