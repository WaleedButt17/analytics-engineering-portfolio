SELECT
  'Form Submission' AS kpi, SUM(leads)                AS bigquery,   15 AS document
FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
WHERE period_start = DATE '2026-08-10'
UNION ALL SELECT 'Clicks Org 1', SUM(clicks_assoc_org_1),     1279
  FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
  WHERE period_start = DATE '2026-08-10'
UNION ALL SELECT 'Clicks Org 2', SUM(clicks_assoc_org_2),      144
  FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
  WHERE period_start = DATE '2026-08-10'
UNION ALL SELECT 'ORG 3',         SUM(clicks_assoc_org_3),   53
  FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
  WHERE period_start = DATE '2026-08-10'
UNION ALL SELECT 'ORG 4',             SUM(clicks_assoc_org_4),       45
  FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
  WHERE period_start = DATE '2026-08-10'
UNION ALL SELECT 'ORG 5',            SUM(clicks_assoc_org_5),      39
  FROM `your-project.marketing.vw_brand_a_rollup_weekly_v3`
  WHERE period_start = DATE '2026-08-10';

SELECT button, SUM(clicks) AS bigquery
FROM `your-project.marketing.tf_brand_a_weekly_buttons`(
       DATE '2026-08-10', DATE '2026-08-16')
GROUP BY button ORDER BY button;

SELECT COUNT(*) AS n_rows, SUM(clicks) AS bigquery, 444 AS document
FROM `your-project.marketing.tf_brand_a_weekly_orientation_v2`(
       DATE '2026-08-10', DATE '2026-08-16');

SELECT report_date, SUM(sessions) AS session_count, SUM(leads) AS leads
FROM `your-project.marketing.vw_brand_a_v3`
WHERE report_date BETWEEN DATE '2026-08-10' AND DATE '2026-08-16'
GROUP BY report_date ORDER BY report_date;

SELECT channel, campaign_name, spend_amount, impression_count, click_count, session_count,
       clicks_associations, clicks_video_start, clicks_button_a, clicks_button_b
FROM `your-project.marketing.tf_brand_b_campaign`(
       DATE '2026-08-01', DATE '2026-08-15')
ORDER BY channel, campaign_name;
