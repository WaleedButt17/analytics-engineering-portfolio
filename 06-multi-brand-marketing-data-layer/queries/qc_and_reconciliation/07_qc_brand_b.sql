CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_b_campaigns_orphan` AS
SELECT 'DV360' AS channel, campaign, ROUND(SUM(revenue_advertiser), 2) AS spend_amount,
       MIN(date) AS since_date, MAX(date) AS until_date
FROM `your-project.marketing.dv360_campaign_v2`
WHERE LOWER(campaign) LIKE '%brand b%'
  AND campaign NOT IN (SELECT campaign_platform
                       FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2 HAVING SUM(revenue_advertiser) > 0

UNION ALL

SELECT 'Google', campaign, ROUND(SUM(spend), 2), MIN(date), MAX(date)
FROM `your-project.marketing.google_ads_campaigns`
WHERE account_id = 'GOOGLE_ADS_ACCOUNT_B'
  AND campaign NOT IN (SELECT campaign_platform
                       FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2 HAVING SUM(spend) > 0;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_b_content_orphan` AS
SELECT
  session_manual_ad_content AS content,
  session_source_medium,
  SUM(event_count) AS events_cte,
  MIN(date) AS since_date, MAX(date) AS until_date
FROM `your-project.marketing.ga4_brand_b_events_content`
WHERE event_name IN ('click_association','video_engagement','click_home_buttons')
  AND (STARTS_WITH(LOWER(session_source_medium), 'dv360 /')
       OR LOWER(session_source_medium) = 'google / cpc')
  AND session_manual_ad_content NOT IN (
        SELECT content FROM `your-project.marketing.dim_content_brand_b`)
GROUP BY 1, 2 HAVING SUM(event_count) > 0;

CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_b_spend_sessions` AS
SELECT report_date, campaign_name, channel, spend_amount, session_count,
  CASE WHEN spend_amount = 0 AND session_count > 0 THEN 'sessions without spend'
       WHEN spend_amount > 0 AND session_count = 0 THEN 'spend without sessions'
  END AS problem
FROM `your-project.marketing.vw_brand_b_campaign_v3`
WHERE (spend_amount = 0 AND session_count > 0) OR (spend_amount > 0 AND session_count = 0);

CREATE OR REPLACE VIEW `your-project.marketing.qc_brand_b_freshness` AS
SELECT 'dv360_campaign_v2' AS source_table, MAX(date) AS last_date,
       DATE_DIFF(CURRENT_DATE('Etc/GMT+6'), MAX(date), DAY) AS days_ago
FROM `your-project.marketing.dv360_campaign_v2`
UNION ALL
SELECT 'google_ads_campaigns', MAX(date),
       DATE_DIFF(CURRENT_DATE('Etc/GMT+6'), MAX(date), DAY)
FROM `your-project.marketing.google_ads_campaigns`
UNION ALL
SELECT 'ga4_brand_b_events_content', MAX(date),
       DATE_DIFF(CURRENT_DATE('Etc/GMT+6'), MAX(date), DAY)
FROM `your-project.marketing.ga4_brand_b_events_content`;
