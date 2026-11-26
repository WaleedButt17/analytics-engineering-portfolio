CREATE OR REPLACE VIEW `your-project.marketing.vw_attribution_brand_e` AS
WITH first_touch AS (
  SELECT
    date AS report_date,
    source_medium_first_touch AS source_medium,
    IF(campaign_first_touch IN ('be_aon', 'PMax - Brand E AON'),
       'be_aon', campaign_first_touch) AS campaign_name,
    STRING_AGG(DISTINCT campaign_first_touch ORDER BY campaign_first_touch) AS name_first_touch,
    SUM(sessions)    AS session_count,
    SUM(total_users) AS user_count
  FROM `your-project.marketing.stg_ga4_brand_e_first_touch`
  GROUP BY 1, 2, 3
),
session_cte AS (
  SELECT
    date AS report_date,
    session_source_medium AS source_medium,
    IF(campaign IN ('be_aon', 'PMax - Brand E AON'),
       'be_aon', campaign) AS campaign_name,
    STRING_AGG(DISTINCT campaign ORDER BY campaign) AS name_session,
    SUM(sessions)   AS session_count,
    SUM(totalusers) AS user_count
  FROM `your-project.marketing.ga4_brand_e_sessions`
  GROUP BY 1, 2, 3
)
SELECT
  COALESCE(p.report_date, s.report_date)               AS report_date,
  COALESCE(p.source_medium, s.source_medium) AS source_medium,
  COALESCE(p.campaign_name, s.campaign_name)           AS campaign_name,

  p.name_first_touch,
  s.name_session,

  p.session_count AS sessions_first_touch,
  p.user_count AS users_first_touch,

  s.session_count AS sessions_session,
  s.user_count AS users_session,

  s.session_count - p.session_count             AS difference_sessions,
  SAFE_DIVIDE(s.session_count, p.session_count) AS ratio_sessions,

  'First user source/medium and First user campaign name' AS fields_first_touch,
  'Session source/medium and Session campaign' AS fields_session
FROM first_touch p
FULL OUTER JOIN session_cte s
  ON  p.report_date        = s.report_date
 AND  p.source_medium = s.source_medium
 AND  p.campaign_name      = s.campaign_name;

SELECT
  SUM(sessions_first_touch) AS sessions_first_touch,
  SUM(sessions_session)       AS sessions_session,
  ROUND(SAFE_DIVIDE(SUM(sessions_session), SUM(sessions_first_touch)), 3) AS ratio
FROM `your-project.marketing.vw_attribution_brand_e`
WHERE report_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND source_medium = 'google / cpc'
  AND campaign_name = 'be_aon';
