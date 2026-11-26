CREATE OR REPLACE VIEW `your-project.reporting.v_leads_by_state_daterange` AS
SELECT
  lead_date,
  state,
  region,
  product,
  CAST(SUM(leads) AS INT64) AS leads
FROM `your-project`.reporting.v_leads_by_state
GROUP BY 1, 2, 3, 4;
