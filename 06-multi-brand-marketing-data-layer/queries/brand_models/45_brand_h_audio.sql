SELECT
  FORMAT_DATE('%Y-%m', date)        AS month_start,
  campaign,
  COUNT(DISTINCT date)              AS days,
  SUM(campaign_impressions)         AS impression_count,
  SUM(campaign_clicks)              AS click_count,
  ROUND(SUM(campaign_spend), 2)     AS spend_spotify,
  SUM(campaign_completes)           AS listen_100
FROM `your-project.marketing.spotify_campaigns`
GROUP BY month_start, campaign
ORDER BY month_start;

CREATE OR REPLACE VIEW `your-project.marketing.stg_spotify_brand_h` AS
SELECT
  date,
  'Spotify' AS channel,
  campaign  AS campaign_platform,
  SUM(campaign_impressions)      AS impression_count,
  SUM(campaign_clicks)           AS click_count,
  SUM(campaign_spend)            AS spend_spotify,
  SUM(campaign_first_quartiles)  AS listen_25,
  SUM(campaign_midpoints)        AS listen_50,
  SUM(campaign_third_quartiles)  AS listen_75,
  SUM(campaign_completes)        AS listen_100,

  SUM(campaign_reach)            AS daily_reach_non_additive,
  SUM(campaign_starts)           AS starts,
  SUM(campaign_listeners)        AS listeners
FROM `your-project.marketing.spotify_campaigns`

WHERE campaign = 'Client_BH_2_2026_Agency'
GROUP BY date, campaign;

CREATE OR REPLACE TABLE FUNCTION
`your-project.marketing.tf_brand_h_audio`(start_date DATE, end_date DATE) AS (
  SELECT
    'Brand H Audio' AS campaign_name,
    SUM(impression_count)    AS impression_count,
    SUM(click_count)          AS click_count,
    SUM(listen_25)      AS listen_25,
    SUM(listen_50)      AS listen_50,
    SUM(listen_75)      AS listen_75,
    SUM(listen_100)     AS listen_100,
    SAFE_DIVIDE(SUM(click_count), SUM(impression_count))      AS ctr,
    SAFE_DIVIDE(SUM(listen_100), SUM(impression_count)) AS ltr,
    ROUND(SUM(spend_spotify), 2)                   AS spend_spotify_reference
  FROM `your-project.marketing.stg_spotify_brand_h`
  WHERE date BETWEEN start_date AND end_date

  HAVING impression_count > 0
);

CREATE OR REPLACE VIEW `your-project.marketing.qc_spotify_campaign_new` AS
SELECT campaign_platform, MIN(date) AS first_day, MAX(date) AS last_day,
       SUM(impression_count) AS impression_count
FROM `your-project.marketing.stg_spotify_brand_h`
WHERE campaign_platform != 'Client_BH_2_2026_Agency'
GROUP BY campaign_platform;

SELECT '2-15 Aug (as published)' AS period, *
FROM `your-project.marketing.tf_brand_h_audio`('2026-08-02','2026-08-15')
UNION ALL
SELECT '1-15 Aug (actual period)', *
FROM `your-project.marketing.tf_brand_h_audio`('2026-08-01','2026-08-15');
