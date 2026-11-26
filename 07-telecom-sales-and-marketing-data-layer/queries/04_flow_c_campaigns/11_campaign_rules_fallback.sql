CREATE TABLE IF NOT EXISTS `your-project.client_dataset.dim_campaign_override` (
  campaign    STRING  NOT NULL OPTIONS(description="Exact campaign name"),
  platform  STRING           OPTIONS(description="google or meta. NULL applies to both"),
  subchannel    STRING           OPTIONS(description="Call Center, E-commerce, or (no channel)"),
  segment    STRING           OPTIONS(description="Residential or Business"),
  scope      STRING           OPTIONS(description="national, region, tier_size, tier_traffic_light, market, multi_market"),
  geo_value   STRING           OPTIONS(description="The region, tier or market name"),
  campaign_type        STRING           OPTIONS(description="performance, traffic, awareness"),
  note        STRING           OPTIONS(description="Why this override exists")
);

DELETE FROM `your-project.client_dataset.dim_campaign_override` WHERE TRUE;

INSERT INTO `your-project.client_dataset.dim_campaign_override`
  (campaign, platform, subchannel, segment, scope, geo_value, campaign_type, note)
VALUES
  ('Central campaign - Market 1 - Market 8', 'meta', NULL, NULL, 'multi_market', 'Market 1 + Market 8', NULL,
   'Names a region and two markets. The region rule would swallow both'),
  ('Speed plan promo (Market 1 - Market 8)', 'google', NULL, NULL, 'multi_market', 'Market 1 + Market 8', NULL,
   'Two markets in one campaign'),
  ('Red market campaign Market 7 single 2026', 'google', NULL, NULL, 'market', 'Market 7', NULL,
   'Says "red market" but targets one named market. The traffic light rule would hide that'),
  ('Boost District 1 Ecommerce', 'meta', NULL, NULL, 'market', 'Market 1', NULL,
   'District 1 is a district inside Market 1, not a market'),
  ('Boost District 2 Ecommerce', 'meta', NULL, NULL, 'market', 'Market 1', NULL,
   'District 2 is a district inside Market 1, not a market'),
  ('District 1 2025 Market 1', 'google', NULL, NULL, 'market', 'Market 1', NULL,
   'District of Market 1'),
  ('District 2 2025 Market 1 videos', 'google', NULL, NULL, 'market', 'Market 1', NULL,
   'District of Market 1'),
  ('Yellow districts Region 7 campaign 2026', 'google', NULL, NULL, 'tier_traffic_light', 'Yellow', NULL,
   'Names both a traffic light tier and a region. The tier is the targeting'),
  ('CC phone number campaign all markets', 'google', 'Call Center', NULL, 'national', '(all markets)', NULL,
   'All markets is effectively national coverage, not a tier');

CREATE OR REPLACE VIEW `your-project.client_dataset.dim_campaign_rules_v2` AS
WITH campaigns AS (
  SELECT DISTINCT 'google' AS platform, account_name AS account, campaign
  FROM `your-project.client_dataset.google_ads_campaigns`
  WHERE campaign IS NOT NULL
  UNION DISTINCT
  SELECT DISTINCT 'meta', account_name, campaign
  FROM `your-project.client_dataset.facebook_ads_campaigns`
  WHERE campaign IS NOT NULL
),
rules AS (
  SELECT
    platform,
    account,
    campaign,

    CASE
      WHEN REGEXP_CONTAINS(account,   r'(?i)ecommerce|e-commerce')   THEN 'E-commerce'
      WHEN REGEXP_CONTAINS(account,   r'(?i)call\s*center')          THEN 'Call Center'
      WHEN REGEXP_CONTAINS(account,   r'(?i)youtube')                THEN '(no channel)'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\becc\b|e-?commerce')   THEN 'E-commerce'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bcc\b|call\s*center')  THEN 'Call Center'
      ELSE '(no channel)'
    END AS subchannel,

    CASE
      WHEN REGEXP_CONTAINS(account,   r'(?i)business')               THEN 'Business'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)business|entrepreneurs') THEN 'Business'
      ELSE 'Residential'
    END AS segment,

    CASE
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bexcl\s+mkt1\b')                     THEN 'national'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)large\s+markets?')                 THEN 'tier_size'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)medium\s+markets?')                THEN 'tier_size'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)small\s+markets?')                  THEN 'tier_size'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bred\b')                          THEN 'tier_traffic_light'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\byellow\b')                      THEN 'tier_traffic_light'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bgreen\b')                            THEN 'tier_traffic_light'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+1\b')                           THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+2\b')                        THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+3\b')                           THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+4\b')                            THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+5\b')                          THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+6\b')                            THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+7\b|\bcentral\s+campaign\b') THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+8\b')                    THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+9\b')                  THEN 'region'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bmkt1\b|market\s+1\b')       THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bmkt2\b|market\s+2\b')                THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bmkt3\b|market\s+3\b')                  THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+4\b')                             THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+5\b')                            THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+6\b')                             THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+7\b')                              THEN 'market'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+8\b')                       THEN 'market'
      ELSE 'national'
    END AS scope,

    CASE
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bexcl\s+mkt1\b')                     THEN '(national excl Market 1)'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)large\s+markets?')                 THEN 'Large'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)medium\s+markets?')                THEN 'Medium'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)small\s+markets?')                  THEN 'Small'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bred\b')                          THEN 'Red'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\byellow\b')                      THEN 'Yellow'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bgreen\b')                            THEN 'Green'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+1\b')                           THEN 'Region 1'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+2\b')                        THEN 'Region 2'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+3\b')                           THEN 'Region 3'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+4\b')                            THEN 'Region 4'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+5\b')                          THEN 'Region 5'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+6\b')                            THEN 'Region 6'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+7\b|\bcentral\s+campaign\b') THEN 'Region 7'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+8\b')                    THEN 'Region 8'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bregion\s+9\b')                  THEN 'Region 9'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bmkt1\b|market\s+1\b')       THEN 'Market 1'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bmkt2\b|market\s+2\b')                THEN 'Market 2'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)\bmkt3\b|market\s+3\b')                  THEN 'Market 3'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+4\b')                             THEN 'Market 4'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+5\b')                            THEN 'Market 5'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+6\b')                             THEN 'Market 6'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+7\b')                              THEN 'Market 7'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)market\s+8\b')                       THEN 'Market 8'
      ELSE '(national)'
    END AS geo_value,

    CASE
      WHEN REGEXP_CONTAINS(campaign, r'(?i)traffic|\bclicks\b')                          THEN 'traffic'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)pmax|performance max|demand\s|search|lead gen|conversion|conv\.') THEN 'performance'
      WHEN REGEXP_CONTAINS(campaign, r'(?i)video|masthead|in-stream|shorts?|yt brand|boost|recognition|institutional|visibility|reach|interaction') THEN 'awareness'
      ELSE 'other'
    END AS campaign_type
  FROM campaigns
)
SELECT
  r.platform,
  r.account,
  r.campaign,
  COALESCE(o.subchannel,  r.subchannel)  AS subchannel,
  COALESCE(o.segment,  r.segment)  AS segment,
  COALESCE(o.scope,    r.scope)    AS scope,
  COALESCE(o.geo_value, r.geo_value) AS geo_value,
  COALESCE(o.campaign_type,      r.campaign_type)      AS campaign_type,
  o.campaign IS NOT NULL             AS is_override,
  o.note                             AS override_note
FROM rules r
LEFT JOIN `your-project.client_dataset.dim_campaign_override` o
  ON o.campaign = r.campaign
 AND (o.platform IS NULL OR o.platform = r.platform);

CREATE OR REPLACE VIEW `your-project.client_dataset.qc_campaigns_unclassified_v2` AS
WITH spend_totals AS (
  SELECT 'google' AS platform, account_name AS account, campaign, SUM(spend) AS spend
  FROM `your-project.client_dataset.google_ads_campaigns` GROUP BY account, campaign
  UNION ALL
  SELECT 'meta', account_name, campaign, SUM(spend)
  FROM `your-project.client_dataset.facebook_ads_campaigns` GROUP BY account, campaign
)
SELECT
  d.platform, d.account, d.campaign, ROUND(g.spend, 0) AS spend,
  d.subchannel, d.scope, d.geo_value, d.campaign_type,
  d.subchannel = '(no channel)' AS no_channel,
  d.scope   = 'national' AND d.geo_value = '(national)' AS no_geography,
  d.campaign_type     = 'other'    AS no_type
FROM `your-project.client_dataset.dim_campaign_rules_v2` d
JOIN spend_totals g USING (platform, account, campaign)
WHERE d.subchannel = '(no channel)'
   OR (d.scope = 'national' AND d.geo_value = '(national)')
   OR d.campaign_type = 'other'
ORDER BY g.spend DESC;
