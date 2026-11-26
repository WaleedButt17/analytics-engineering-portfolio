CREATE OR REPLACE VIEW `your-project.ads_data.ads_unified` AS
SELECT
  date,
  'meta'                                          AS platform,
  LOWER(campaign)                                 AS campaign,
  'meta'                                          AS source,
  COALESCE(spend, 0)                              AS spend,
  COALESCE(clicks, 0)                             AS clicks,
  COALESCE(actions_omni_app_install, 0)           AS installs,
  COALESCE(impressions, 0)                        AS impressions
FROM `your-project.ads_data.Meta Ads`

UNION ALL

SELECT
  date,
  'TikTok'                                        AS platform,
  LOWER(campaign)                                 AS campaign,
  'tiktok'                                        AS source,
  COALESCE(spend, 0)                              AS spend,
  COALESCE(clicks, 0)                             AS clicks,
  COALESCE(conversions, 0)                        AS installs,
  COALESCE(impressions, 0)                        AS impressions
FROM `your-project.ads_data.TikTok Ads`

UNION ALL

SELECT
  date,
  'Google Ads'                                    AS platform,
  LOWER(campaign)                                 AS campaign,
  'Google Ads'                                    AS source,
  COALESCE(spend, 0)                              AS spend,
  COALESCE(clicks, 0)                             AS clicks,
  COALESCE(conversions, 0)                        AS installs,
  COALESCE(impressions, 0)                        AS impressions
FROM `your-project.ads_data.Google Ads`;
