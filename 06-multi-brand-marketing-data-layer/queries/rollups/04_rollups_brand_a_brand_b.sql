CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_a_v3` AS
WITH expanded AS (
  SELECT
    grain,
    CASE grain
      WHEN 'weekly'   THEN DATE_TRUNC(report_date, WEEK(MONDAY))
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                              DATE_TRUNC(report_date, MONTH),
                              DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 15 DAY))
      WHEN 'monthly'  THEN DATE_TRUNC(report_date, MONTH)
    END AS period_start,
    CASE grain
      WHEN 'weekly'   THEN DATE_ADD(DATE_TRUNC(report_date, WEEK(MONDAY)), INTERVAL 6 DAY)
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                              DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 14 DAY),
                              LAST_DAY(report_date))
      WHEN 'monthly'  THEN LAST_DAY(report_date)
    END AS period_end,
    v.*
  FROM `your-project.marketing.vw_brand_a_v3` v

  CROSS JOIN UNNEST(['weekly', 'biweekly', 'monthly']) AS grain
),
base AS (
  SELECT
    grain, period_start, period_end, initiative, channel,
    SUM(sessions)  AS sessions,
    SUM(new_users) AS new_users,
    SAFE_DIVIDE(
      SUM(CAST(avg_session_duration AS FLOAT64) * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS avg_session_duration,
    SUM(leads)                      AS leads,
    SUM(clicks_orientation)         AS clicks_orientation,
    SUM(clicks_buttons_total)       AS clicks_buttons_total,
    SUM(clicks_segment_1)     AS clicks_segment_1,
    SUM(clicks_segment_2) AS clicks_segment_2,
    SUM(clicks_assoc_org_1)     AS clicks_assoc_org_1,
    SUM(clicks_assoc_org_3) AS clicks_assoc_org_3,
    SUM(clicks_assoc_org_5)    AS clicks_assoc_org_5,
    SUM(clicks_assoc_org_4)     AS clicks_assoc_org_4,
    SUM(clicks_assoc_org_2)     AS clicks_assoc_org_2,
    SUM(spend) AS spend, SUM(clicks) AS clicks, SUM(impressions) AS impressions
  FROM expanded
  WHERE initiative IS NOT NULL
  GROUP BY grain, period_start, period_end, initiative, channel
)
SELECT
  'Brand A' AS brand,
  grain, period_start, period_end, initiative, channel,
  sessions, new_users, avg_session_duration,
  leads, clicks_orientation, clicks_buttons_total,
  clicks_segment_1, clicks_segment_2,
  clicks_assoc_org_1, clicks_assoc_org_3, clicks_assoc_org_5,
  clicks_assoc_org_4, clicks_assoc_org_2,
  spend, clicks, impressions,
  SAFE_DIVIDE(clicks, impressions)       AS ctr,
  SAFE_DIVIDE(spend, clicks)             AS cpc,

  SAFE_DIVIDE(leads, clicks_orientation) AS rate_conversion,
  'brand_a_v3' AS contract_version
FROM base;

CREATE OR REPLACE VIEW `your-project.marketing.rollup_base_brand_b_v3` AS
WITH expanded AS (
  SELECT
    grain,
    CASE grain
      WHEN 'weekly'   THEN DATE_TRUNC(report_date, WEEK(MONDAY))
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                              DATE_TRUNC(report_date, MONTH),
                              DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 15 DAY))
      WHEN 'monthly'  THEN DATE_TRUNC(report_date, MONTH)
    END AS period_start,
    CASE grain
      WHEN 'weekly'   THEN DATE_ADD(DATE_TRUNC(report_date, WEEK(MONDAY)), INTERVAL 6 DAY)
      WHEN 'biweekly' THEN IF(EXTRACT(DAY FROM report_date) <= 15,
                              DATE_ADD(DATE_TRUNC(report_date, MONTH), INTERVAL 14 DAY),
                              LAST_DAY(report_date))
      WHEN 'monthly'  THEN LAST_DAY(report_date)
    END AS period_end,
    v.*
  FROM `your-project.marketing.vw_brand_b_v3` v
  CROSS JOIN UNNEST(['weekly', 'biweekly', 'monthly']) AS grain
),
base AS (
  SELECT
    grain, period_start, period_end, initiative, channel,
    SUM(sessions) AS sessions,
    SAFE_DIVIDE(
      SUM(CAST(avg_session_duration AS FLOAT64) * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS avg_session_duration,
    SAFE_DIVIDE(
      SUM(bounce_rate * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS bounce_rate,
    SAFE_DIVIDE(
      SUM(engagement_rate * CAST(sessions AS FLOAT64)),
      SUM(CAST(sessions AS FLOAT64))
    ) AS engagement_rate,
    SUM(clicks_partner_1)   AS clicks_partner_1,
    SUM(clicks_partner_2)    AS clicks_partner_2,
    SUM(video_1)   AS video_1,
    SUM(video_2) AS video_2,
    SUM(button_b)      AS button_b,
    SUM(button_a)  AS button_a,
    SUM(spend) AS spend, SUM(clicks) AS clicks, SUM(impressions) AS impressions
  FROM expanded
  WHERE initiative IS NOT NULL
  GROUP BY grain, period_start, period_end, initiative, channel
)
SELECT
  'Brand B' AS brand,
  grain, period_start, period_end, initiative, channel,
  sessions,
  CAST(avg_session_duration AS BIGNUMERIC) AS avg_session_duration,
  bounce_rate, engagement_rate,
  clicks_partner_1, clicks_partner_2, video_1, video_2,
  button_b, button_a,
  spend, clicks, impressions,
  SAFE_DIVIDE(clicks, impressions) AS ctr,
  SAFE_DIVIDE(spend, clicks)       AS cpc,
  SAFE_DIVIDE(
    clicks_partner_1 + clicks_partner_2 + video_1
    + video_2 + button_b + button_a,
    sessions
  ) AS cvr_micro_events
FROM base;

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_a_rollup_weekly_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_a_v3` WHERE grain = 'weekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_a_rollup_biweekly_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_a_v3` WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_a_rollup_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_a_v3` WHERE grain = 'monthly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_rollup_weekly_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_b_v3` WHERE grain = 'weekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_rollup_biweekly_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_b_v3` WHERE grain = 'biweekly';

CREATE OR REPLACE VIEW `your-project.marketing.vw_brand_b_rollup_v3` AS
SELECT * EXCEPT(grain) FROM `your-project.marketing.rollup_base_brand_b_v3` WHERE grain = 'monthly';
