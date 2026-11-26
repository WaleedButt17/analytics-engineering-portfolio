CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_signup_authentication` AS
WITH
installs AS (
  SELECT
    event_date,
    platform,
    COUNT(*) AS installs
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name = 'first_open'
  GROUP BY event_date, platform
),

agg AS (
  SELECT
    event_date,
    platform,
    method,
    COUNTIF(event_name = 'signup_completed')  AS signups,
    COUNTIF(event_name = 'signup_started')    AS signup_attempts,
    COUNTIF(event_name = 'signup_completed')  AS signup_successes
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
  WHERE event_name IN ('signup_completed', 'signup_started')
  GROUP BY event_date, platform, method
)

SELECT
  a.event_date,
  a.platform,
  a.method,
  a.signups,
  a.signup_attempts,
  a.signup_successes,
  ROUND(SAFE_DIVIDE(a.signup_successes, a.signup_attempts) * 100, 2) AS signup_success_rate_pct,
  i.installs,
  ROUND(SAFE_DIVIDE(a.signup_successes, i.installs) * 100, 2)        AS signup_from_install_rate_pct
FROM agg a
LEFT JOIN installs i USING (event_date, platform)
ORDER BY a.event_date, a.platform, a.method;
