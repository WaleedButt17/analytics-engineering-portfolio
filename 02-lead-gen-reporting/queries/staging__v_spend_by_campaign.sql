CREATE OR REPLACE VIEW `your-project.staging.v_spend_by_campaign` AS
WITH base AS (
  SELECT
    r.date,
    r.platform,
    r.campaign_id,
    COALESCE(m.campaign_name, r.campaign_name) AS campaign_name,
    r.adset_name,
    r.state,
    CASE
      WHEN r.platform = 'meta' THEN
        CASE
          WHEN LOWER(r.adset_name) LIKE '%mortgage%' OR LOWER(r.campaign_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
          WHEN LOWER(r.adset_name) LIKE '%spanishcreditunion%' OR LOWER(r.adset_name) LIKE '%spanish credit union%' THEN 'Unknown'
          WHEN LOWER(r.adset_name) LIKE '%veteran%' THEN 'Veteran Kit'
          WHEN LOWER(r.adset_name) LIKE '%spanishcsk%' OR LOWER(r.adset_name) LIKE '%spanish csk%' OR LOWER(r.adset_name) LIKE '%spanishchildsafe%' THEN 'Child Safe Kit Spanish'
          WHEN LOWER(r.adset_name) LIKE '%spanishnocostlaw%' OR LOWER(r.adset_name) LIKE '%spanish no cost law%' THEN 'Spanish NCL'
          WHEN LOWER(r.adset_name) LIKE '%nocostlaw%' OR LOWER(r.adset_name) LIKE '%no cost law%' OR LOWER(r.adset_name) LIKE '%nocolaw%' THEN 'No Cost Law'
          WHEN LOWER(r.adset_name) LIKE '%safetykit%' THEN 'Child Safety Kit'
          WHEN LOWER(r.adset_name) LIKE '%creditunion%' OR LOWER(r.adset_name) LIKE '%credit union%' THEN 'Credit Union Benefit'
          WHEN LOWER(r.adset_name) LIKE '%laborlead%' OR LOWER(r.adset_name) LIKE '%labor lead%' OR LOWER(r.adset_name) LIKE '%laborleads%' OR LOWER(r.adset_name) LIKE '%labour%' THEN 'Labor Lead'
          WHEN LOWER(r.adset_name) LIKE '%womensmarket%' OR LOWER(r.adset_name) LIKE '%womens market%' THEN 'Womens Market NCL'
          WHEN LOWER(r.adset_name) LIKE '%finalexpense%' OR LOWER(r.adset_name) LIKE '%final expense%' THEN 'Final Expense'
          WHEN LOWER(r.adset_name) LIKE '%partner d%' THEN 'Final Expense'
          WHEN LOWER(r.adset_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
          ELSE
            CASE
              WHEN LOWER(r.campaign_name) LIKE '%veteran%' THEN 'Veteran Kit'
              WHEN LOWER(r.campaign_name) LIKE '%spanishcsk%' OR LOWER(r.campaign_name) LIKE '%spanishchildsafe%' OR LOWER(r.campaign_name) LIKE '%child safe kit spanish%' THEN 'Child Safe Kit Spanish'
              WHEN LOWER(r.campaign_name) LIKE '%women%market%' THEN 'Womens Market NCL'
              WHEN LOWER(r.campaign_name) LIKE '%nocostlaw%' OR LOWER(r.campaign_name) LIKE '%no cost law%' OR LOWER(r.campaign_name) LIKE '%womensnocostlaw%' THEN 'No Cost Law'
              WHEN LOWER(r.campaign_name) LIKE '%safetykit%' THEN 'Child Safety Kit'
              WHEN LOWER(r.campaign_name) LIKE '%creditunion%' OR LOWER(r.campaign_name) LIKE '%credit union%' THEN 'Credit Union Benefit'
              WHEN LOWER(r.campaign_name) LIKE '%laborlead%' OR LOWER(r.campaign_name) LIKE '%labourleads%' OR LOWER(r.campaign_name) LIKE '%labour leads%' OR LOWER(r.campaign_name) LIKE '%labor%' OR LOWER(r.campaign_name) LIKE '%labour%' THEN 'Labor Lead'
              WHEN LOWER(r.campaign_name) LIKE '%womensmarket%' THEN 'Womens Market NCL'
              WHEN LOWER(r.campaign_name) LIKE '%finalexpense%' OR LOWER(r.campaign_name) LIKE '%final expense%' THEN 'Final Expense'
              WHEN LOWER(r.campaign_name) LIKE '%partner d%' THEN 'Final Expense'
              WHEN LOWER(r.campaign_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
              ELSE 'Unknown'
            END
        END
      ELSE
        CASE
          WHEN LOWER(r.campaign_name) LIKE '%veteran%' THEN 'Veteran Kit'
          WHEN LOWER(r.campaign_name) LIKE '%spanishcsk%' OR LOWER(r.campaign_name) LIKE '%spanish csk%' OR LOWER(r.campaign_name) LIKE '%spanishchildsafe%' OR LOWER(r.campaign_name) LIKE '%child safe kit spanish%' THEN 'Child Safe Kit Spanish'
          WHEN LOWER(r.campaign_name) LIKE '%women%market%' THEN 'Womens Market NCL'
          WHEN LOWER(r.campaign_name) LIKE '%nocostlaw%' OR LOWER(r.campaign_name) LIKE '%no cost law%' OR LOWER(r.campaign_name) LIKE '%womensnocostlaw%' THEN 'No Cost Law'
          WHEN LOWER(r.campaign_name) LIKE '%safetykit%' THEN 'Child Safety Kit'
          WHEN LOWER(r.campaign_name) LIKE '%creditunion%' OR LOWER(r.campaign_name) LIKE '%credit union%' THEN 'Credit Union Benefit'
          WHEN LOWER(r.campaign_name) LIKE '%laborlead%' OR LOWER(r.campaign_name) LIKE '%labourleads%' OR LOWER(r.campaign_name) LIKE '%labour leads%' OR LOWER(r.campaign_name) LIKE '%labor%' OR LOWER(r.campaign_name) LIKE '%labour%' THEN 'Labor Lead'
          WHEN LOWER(r.campaign_name) LIKE '%womensmarket%' THEN 'Womens Market NCL'
          WHEN LOWER(r.campaign_name) LIKE '%finalexpense%' OR LOWER(r.campaign_name) LIKE '%final expense%' THEN 'Final Expense'
          WHEN LOWER(r.campaign_name) LIKE '%partner d%' THEN 'Final Expense'
          WHEN LOWER(r.campaign_name) LIKE '%mortgage%' THEN 'Mortgage Protection'
          WHEN LOWER(r.campaign_name) LIKE '%allproducts%' THEN 'All Products'
          ELSE 'Unknown'
        END
    END AS product,
    COALESCE(NULLIF(a.phase, ''), NULLIF(m.phase, '')) AS phase,
    COALESCE(
      NULLIF(a.phase_changed_date, ''),
      NULLIF(CAST(m.phase_changed_date AS STRING), '')
    ) AS phase_changed_date,
    r.spend,
    r.impressions,
    r.clicks,
    r.conversions,
    r.conversion_value
  FROM `your-project`.staging.v_raw_spend r
  LEFT JOIN `your-project`.Mapping.dim_campaign m
    ON CAST(r.campaign_id AS STRING) = CAST(m.campaign_id AS STRING)
  LEFT JOIN `your-project`.Mapping.dim_adset a
    ON r.adset_id = a.adset_id
)
SELECT
  date,
  platform,
  campaign_id,
  campaign_name,
  adset_name,
  product,
  CASE
    WHEN LOWER(adset_name) LIKE 'ny/%' AND product != 'Labor Lead' THEN 'NY'
    WHEN LOWER(adset_name) LIKE 'cad/%' THEN 'CAD'
    WHEN state = 'New York' AND product != 'Labor Lead' THEN 'NY'
    WHEN state IN (
      'Ontario','Quebec','British Columbia','Alberta','Manitoba',
      'Saskatchewan','Nova Scotia','New Brunswick','Newfoundland and Labrador',
      'Prince Edward Island','Northwest Territories','Nunavut','Yukon',
      'Simcoe County','Grey County','Northumberland County'
    ) THEN 'CAD'
    WHEN LOWER(campaign_name) LIKE 'cad/%' OR LOWER(campaign_name) LIKE '%/cad/%' THEN 'CAD'
    WHEN LOWER(campaign_name) LIKE 'cad %' THEN 'CAD'
    WHEN LOWER(campaign_name) LIKE 'tx/%' THEN 'TX'
    ELSE 'US'
  END AS region,
  CASE
    WHEN phase IS NOT NULL AND phase_changed_date IS NULL THEN phase
    WHEN phase IS NOT NULL AND phase_changed_date IS NOT NULL THEN
      CASE WHEN date < SAFE_CAST(phase_changed_date AS DATE) THEN 'Research' ELSE phase END
    WHEN LOWER(campaign_name) LIKE '%research%' THEN 'Research'
    ELSE 'Regular Spend'
  END AS phase,
  CASE
    WHEN phase IS NOT NULL AND phase_changed_date IS NULL THEN
      CASE WHEN LOWER(phase) = 'research' THEN TRUE ELSE FALSE END
    WHEN phase IS NOT NULL AND phase_changed_date IS NOT NULL THEN
      CASE WHEN date < SAFE_CAST(phase_changed_date AS DATE) THEN TRUE ELSE FALSE END
    WHEN LOWER(campaign_name) LIKE '%research%' THEN TRUE
    ELSE FALSE
  END AS is_research,
  SUM(spend) AS spend,
  SUM(CASE
    WHEN phase IS NOT NULL AND phase_changed_date IS NULL THEN
      CASE WHEN LOWER(phase) = 'research' THEN 0 ELSE spend END
    WHEN phase IS NOT NULL AND phase_changed_date IS NOT NULL THEN
      CASE WHEN date < SAFE_CAST(phase_changed_date AS DATE) THEN 0 ELSE spend END
    WHEN LOWER(campaign_name) LIKE '%research%' THEN 0
    ELSE spend
  END) AS main_spend,
  SUM(CASE
    WHEN phase IS NOT NULL AND phase_changed_date IS NULL THEN
      CASE WHEN LOWER(phase) = 'research' THEN spend ELSE 0 END
    WHEN phase IS NOT NULL AND phase_changed_date IS NOT NULL THEN
      CASE WHEN date < SAFE_CAST(phase_changed_date AS DATE) THEN spend ELSE 0 END
    WHEN LOWER(campaign_name) LIKE '%research%' THEN spend
    ELSE 0
  END) AS research_spend,
  SUM(impressions) AS impressions,
  SUM(clicks) AS clicks,
  SUM(conversions) AS conversions,
  SUM(conversion_value) AS conversion_value
FROM base
GROUP BY date, platform, campaign_id, campaign_name, adset_name, product, region, phase, is_research;
