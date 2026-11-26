SELECT
  FORMAT_DATE('%Y-%m', date) AS month_start,
  COUNT(*)                   AS n_rows,
  COUNT(DISTINCT first_user_source_medium)        AS media_first_touch,
  COUNT(DISTINCT first_user_manual_campaign_name) AS campaign_names,
  SUM(sessions)              AS session_count,
  SUM(newusers)              AS users_new
FROM `your-project.marketing.ga4_brand_e_first_touch`
GROUP BY month_start
ORDER BY month_start;

CREATE OR REPLACE VIEW `your-project.marketing.stg_ga4_brand_e_first_touch` AS
SELECT
  date,
  first_user_source_medium                        AS source_medium_first_touch,
  first_user_manual_campaign_name                 AS campaign_first_touch,
  REGEXP_REPLACE(NORMALIZE(TRIM(first_user_manual_campaign_name), NFKC), r'\s+', ' ')
                                                  AS utm_key,
  SUM(sessions)    AS sessions,
  SUM(totalusers)  AS total_users,
  SUM(newusers)    AS new_users
FROM `your-project.marketing.ga4_brand_e_first_touch`
GROUP BY 1,2,3,4;

CREATE OR REPLACE VIEW `your-project.marketing.vw_attribution_compared` AS
WITH session_cte AS (
  SELECT
    date                  AS report_date,
    session_source_medium AS source_medium,
    STRING_AGG(DISTINCT campaign ORDER BY campaign LIMIT 20) AS campaign_names,
    SUM(sessions)         AS sessions,
    SUM(totalusers)       AS total_users
  FROM `your-project.marketing.ga4_brand_e_sessions`
  GROUP BY 1,2
),
first AS (
  SELECT
    date                       AS report_date,
    source_medium_first_touch  AS source_medium,
    STRING_AGG(DISTINCT campaign_first_touch ORDER BY campaign_first_touch LIMIT 20) AS campaign_names,
    SUM(sessions)              AS sessions,
    SUM(total_users)           AS total_users
  FROM `your-project.marketing.stg_ga4_brand_e_first_touch`
  GROUP BY 1,2
)
SELECT
  COALESCE(s.report_date, p.report_date)               AS report_date,
  COALESCE(s.source_medium, p.source_medium) AS source_medium,

  s.campaign_names      AS campaigns_session,
  p.campaign_names      AS campaigns_first_touch,

  s.sessions      AS sessions_session,
  p.sessions      AS sessions_first_touch,
  s.total_users   AS users_session,
  p.total_users   AS users_first_touch,

  s.sessions - p.sessions             AS difference_sessions,
  SAFE_DIVIDE(s.sessions, p.sessions) AS ratio_sessions,

  CASE
    WHEN p.source_medium IS NULL THEN 'session_only'
    WHEN s.source_medium IS NULL THEN 'first_touch_only'
    ELSE 'both'
  END AS presence
FROM session_cte s
FULL OUTER JOIN first p
  ON s.report_date = p.report_date AND s.source_medium = p.source_medium;

CREATE OR REPLACE VIEW `your-project.marketing.vw_attribution_brand_e_first_touch` AS
SELECT
  report_date,
  source_medium,
  campaigns_session AS campaign_names,
  'session' AS base_attribution,
  sessions_session       AS session_count,
  users_session       AS user_count,
  'Each session attributed to the campaign, regardless of how the person first arrived' AS definition
FROM `your-project.marketing.vw_attribution_compared`
WHERE sessions_session IS NOT NULL

UNION ALL

SELECT
  report_date,
  source_medium,
  campaigns_first_touch AS campaign_names,
  'first_touch' AS base_attribution,
  sessions_first_touch,
  users_first_touch,
  'Only people whose FIRST visit to the site came from this campaign. This is the basis the Looker dashboard uses'
FROM `your-project.marketing.vw_attribution_compared`
WHERE sessions_first_touch IS NOT NULL;

CREATE OR REPLACE VIEW `your-project.marketing.qc_attribution_divergence` AS
SELECT
  FORMAT_DATE('%Y-%m', report_date) AS month_start,
  presence,
  COUNT(*)                    AS n_rows,
  SUM(COALESCE(sessions_session, sessions_first_touch)) AS session_count
FROM `your-project.marketing.vw_attribution_compared`
GROUP BY month_start, presence
ORDER BY month_start, presence;

CREATE OR REPLACE VIEW `your-project.marketing.qc_first_touch_freshness` AS
WITH pt AS (
  SELECT MAX(date) AS last_first_touch
  FROM `your-project.marketing.ga4_brand_e_first_touch`
),
ss AS (
  SELECT MAX(date) AS last_session
  FROM `your-project.marketing.ga4_brand_e_sessions`
)
SELECT
  pt.last_first_touch,
  ss.last_session,
  DATE_DIFF(ss.last_session, pt.last_first_touch, DAY) AS days_ago
FROM pt CROSS JOIN ss
WHERE pt.last_first_touch < DATE_SUB(ss.last_session, INTERVAL 2 DAY);

SELECT
  SUM(sessions)   AS first_touch_sessions_brand_e_aon,
  SUM(total_users) AS users_sum_daily_bound_upper
FROM `your-project.marketing.stg_ga4_brand_e_first_touch`
WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
  AND source_medium_first_touch = 'google / cpc'
  AND campaign_first_touch = 'be_aon';

SELECT
  campaign,
  SUM(sessions)   AS session_count,
  SUM(totalusers) AS users_sum_daily
FROM `your-project.marketing.ga4_brand_e_sessions`
WHERE date BETWEEN '2026-07-01' AND '2026-07-31'
  AND session_source_medium = 'google / cpc'
GROUP BY campaign
ORDER BY session_count DESC;
