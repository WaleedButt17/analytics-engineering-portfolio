CREATE OR REPLACE VIEW `your-project.marketing.dim_utm` AS
SELECT
  property, traffic_source, utm_campaign,

  REGEXP_REPLACE(NORMALIZE(TRIM(utm_campaign), NFKC), r'\s+', ' ') AS utm_key,
  brand, initiative, is_paid, in_model, status, evidence
FROM UNNEST([
  STRUCT<property STRING, traffic_source STRING, utm_campaign STRING, brand STRING,
         initiative STRING, is_paid BOOL, in_model BOOL,
         status STRING, evidence STRING>
  ('ga4_property_E', 'google', 'PMax - Brand E AON', 'Brand E', 'Brand E AON', TRUE, TRUE, 'mapped', 'Exact campaign name match + identical start date'),
  ('ga4_property_E', 'meta', 'bc_condition_aon', 'Brand C', 'Brand C AON', TRUE, TRUE, 'mapped', 'Identical start to Brand C Dec 2025 (two campaigns, same brand)'),
  ('ga4_property_E', 'meta', 'initiative_c1_meet', 'Brand C', 'Initiative C1', TRUE, TRUE, 'mapped', 'Identical start to Forms - Initiative C1 (Brand C) February 2026'),
  ('ga4_property_E', 'meta', 'initiative_f1_course_ondemand', 'Brand F', 'Initiative F1', TRUE, TRUE, 'mapped', 'Identical start to both Initiative F1 campaigns'),
  ('ga4_property_E', 'meta', 'be_aon', 'Brand E', 'Brand E AON', TRUE, TRUE, 'mapped', 'Start within 1 day of Forms - Brand E AON'),
  ('ga4_property_E', 'google', 'Performance Max - Ondemand Initiative G1', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Exact campaign name match + identical start date'),
  ('ga4_property_E', 'google', 'PMax - Therapy Area 1  2025', 'Brand G', 'Therapy Area 1 AON', TRUE, TRUE, 'mapped', 'Exact campaign name match. Initiative is blank in the catalogue | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'meta', 'AON_TA1_registration', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Identical start to Forms - Brand G AON Oct 2025'),
  ('ga4_property_E', 'google', 'PMax - Therapy Area 2 2025', 'Brand F', 'Brand F AON', TRUE, TRUE, 'mapped', 'Exact campaign name match. Initiative is blank in the catalogue | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'google', 'PMax Initiative C1 (Brand C) 2026', 'Brand C', 'Initiative C1', TRUE, TRUE, 'mapped', 'Exact campaign name match + start within 1 day'),
  ('ga4_property_E', 'meta', 'panel_on_demand_initiative_g1_v2', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Identical start to Traffic Ondemand Initiative G1'),
  ('ga4_property_E', 'meta', 'panel_initiative_g1', 'Brand G', 'Therapy Area 1 AON', TRUE, TRUE, 'mapped', '99.8% of its sessions fall on days Brand G was spending (919 of 921). Initiative undetermined | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'meta', 'event_f2_4_sept', 'Brand F', 'Initiative F2', TRUE, TRUE, 'mapped', 'Identical start to both Initiative F2 August 2025 campaigns'),
  ('ga4_property_E', 'google', 'panel_initiative_g1', 'Brand G', 'Therapy Area 1 AON', TRUE, TRUE, 'mapped', '98.5% of its sessions fall on days Brand G was spending (600 of 609). Also identical start to PMax and Demand Gen Therapy Area 1 2025 | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'google', 'be_aon', 'Brand E', 'Brand E AON', TRUE, TRUE, 'mapped', 'Start within 1 day of PMax - Brand E AON'),
  ('ga4_property_E', 'meta', 'AON_TA1_awareness', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Identical start to Traffic - Brand G AON Sep 2025'),
  ('ga4_property_E', 'meta', 'initiative_f3_registration', 'Brand F', 'Initiative F3 2026', TRUE, TRUE, 'mapped', 'Identical start to both Initiative F3 2026 campaigns'),
  ('ga4_property_E', 'meta', 'event_product_x_31_july', 'Brand F', 'Brand F AON', TRUE, TRUE, 'mapped', 'Identical start to two July 2025 campaigns. Brand certain, initiative ambiguous | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'google', 'PMax - Initiative F3 2026', 'Brand F', 'Initiative F3 2026', TRUE, TRUE, 'mapped', 'Exact campaign name match + start within 1 day'),
  ('ga4_property_E', 'meta', 'panel_on_demand_initiative_g1_v1', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Identical start to Traffic Ondemand Initiative G1'),
  ('ga4_property_E', 'google', 'event_f2_4_sept', 'Brand F', 'Initiative F2', TRUE, TRUE, 'mapped', 'Same utm already evidenced on meta'),
  ('ga4_property_E', 'google', 'bc_condition_aon', 'Brand C', 'Brand C AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta and on the Brand D property'),
  ('ga4_property_E', 'google', 'initiative_c1_meet', 'Brand C', 'Initiative C1', TRUE, TRUE, 'mapped', 'Identical start to PMax Initiative C1 (Brand C) 2026'),
  ('ga4_property_E', 'google', 'initiative_f3_registration', 'Brand F', 'Initiative F3 2026', TRUE, TRUE, 'mapped', 'Identical start to PMax - Initiative F3 2026'),
  ('ga4_property_E', 'google', 'event-f2-rte', 'Brand F', 'Brand F AON', TRUE, TRUE, 'mapped', 'Identical start to PMax - Therapy Area 2 2025 | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'google', 'AON_TA1_registration', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta. Start within 1 day'),
  ('ga4_property_E', 'meta', 'aon_ta1_registration', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Lowercase variant of an evidenced utm'),
  ('ga4_property_E', 'google', 'AON_TA1_awareness', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta'),
  ('ga4_property_E', 'google', 'initiative_f1_course_ondemand', 'Brand F', 'Initiative F1', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta'),
  ('ga4_property_E', 'meta', '"e"" ""vent_product_x_31_july"', 'Brand F', 'Brand F AON', TRUE, TRUE, 'mapped', 'Malformed variant of an evidenced utm | Client 18 Aug: 2025 always-on campaign with no named initiative; assigned brand AON to avoid nulls.'),
  ('ga4_property_E', 'meta', 'initiative_c1_meet)', 'Brand C', 'Initiative C1', TRUE, TRUE, 'mapped', 'Identical start to Initiative C1 May 2026 + variant of an evidenced utm'),
  ('ga4_property_E', 'google', 'aon_ta1_registration', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Lowercase variant of an evidenced utm'),
  ('ga4_property_E', 'meta', 'aon_ta1_awareness', 'Brand G', 'Brand G AON', TRUE, TRUE, 'mapped', 'Lowercase variant of an evidenced utm'),
  ('ga4_property_D', 'meta', 'brand_d_aon', 'Brand D', 'Brand D AON', TRUE, TRUE, 'mapped', 'Identical start to Traffic - Brand D AON'),
  ('ga4_property_D', 'meta', 'bc_condition_aon', 'Brand C', 'Brand C AON', TRUE, TRUE, 'mapped', 'Identical start to Brand C Dec 2025. THE PRINCIPAL CORRECTION'),
  ('ga4_property_D', 'meta', 'CAMPAIGN_ID_2', 'Brand D', 'Brand D AON', TRUE, TRUE, 'mapped', 'The utm is the campaign_id of Brand D Interaction'),
  ('ga4_property_D', 'google', 'bc_condition_aon', 'Brand C', 'Brand C AON', TRUE, TRUE, 'mapped', 'Identical start to PMax Initiative C1 (Brand C) 2026 + same utm evidenced elsewhere'),
  ('ga4_property_D', 'meta', 'brand_d', 'Brand D', 'Brand D AON', TRUE, TRUE, 'mapped', 'Identical start to Traffic - Brand D AON'),
  ('ga4_property_E', 'google', '(organic)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_E', 'google', '(referral)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_E', 'google', '(not set)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_E', 'meta', '(referral)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_E', 'google', '(direct)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_E', 'meta', 'timely_referral', NULL, NULL, FALSE, FALSE, 'not_paid', '100% of its sessions on days with no spend at all in the account (52 of 52 days)'),
  ('ga4_property_E', 'google', 'event_forum_2024', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_D', 'google', '(organic)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value. Currently counted as paid Google'),
  ('ga4_property_D', 'google', 'Shopping Free Listings', NULL, NULL, FALSE, FALSE, 'not_paid', 'Google free listings. Not paid media'),
  ('ga4_property_D', 'meta', '(referral)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_D', 'google', '(not set)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_D', 'meta', '(not set)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_E', 'google', 'aon_brand_g', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_E', 'google', 'Category Event Forum 2025', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_E', 'google', 'Brand Event Forum 2025', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_E', 'google', 'panel_on_demand_initiative_g1', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Client 18 Aug: Brand G, Initiative G1. In model.'),
  ('ga4_property_E', 'meta', 'panel_on_demand_initiative_g1', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Client 18 Aug: Brand G, Initiative G1. In model.'),
  ('ga4_property_E', 'meta', 'panel_initiative_g1_carousel_1', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Client 18 Aug: Brand G, Initiative G1. In model.'),
  ('ga4_property_E', 'meta', 'panel_initiative_g1_carousel_3', 'Brand G', 'Initiative G1', TRUE, TRUE, 'mapped', 'Client 18 Aug: Brand G, Initiative G1. In model.'),
  ('ga4_property_E', 'google', 'BNN_EVENTFORUM_LANDINGS_PRODUCTS_DISPLAY_TRAFFIC', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_E', 'meta', 'programme_x_2024', NULL, NULL, FALSE, FALSE, 'no_evidence', 'No match. Zero sessions'),
  ('ga4_property_E', 'meta', 'partner_2024', NULL, NULL, FALSE, FALSE, 'no_evidence', 'No match. Zero sessions'),
  ('ga4_property_E', 'google', 'partner_2024', NULL, NULL, FALSE, FALSE, 'no_evidence', 'No match. Zero sessions'),
  ('ga4_property_E', 'meta', 'aon_brand_c', NULL, NULL, FALSE, FALSE, 'no_evidence', 'No match. Zero sessions'),
  ('ga4_property_E', 'meta', 'initiative_f1_2024', NULL, NULL, FALSE, FALSE, 'no_evidence', 'No match. Zero sessions'),
  ('ga4_property_E', 'google', 'CAMPAIGN_EVENTFORUM_2025 DEMAND GEN', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_E', 'meta', 'other_disease_awareness', NULL, NULL, FALSE, FALSE, 'no_evidence', 'No match. Zero sessions'),
  ('ga4_property_E', 'google', 'Brand Campaign Event Forum 2025 - Previous LP', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: account warm-up period under a general naming convention, before it formally became the Brand G campaign. Excluded from modelling and reconciliation.'),
  ('ga4_property_E', 'meta', 'corrupt_string_1', NULL, NULL, FALSE, FALSE, 'no_evidence', 'Corrupt string. Zero sessions'),
  ('ga4_property_E', 'meta', 'corrupt_string_2', NULL, NULL, FALSE, FALSE, 'no_evidence', 'Corrupt string. Zero sessions'),
  ('ga4_property_D', 'google', 'brand_d_2021-prev-agency', NULL, NULL, FALSE, FALSE, 'out_of_scope', 'Client 18 Aug: not an agency-managed campaign. Previous agency, corrupt utm, or pre-2025 content.'),
  ('ga4_property_D', 'google', 'brand_d_2022-prev-agency', NULL, NULL, FALSE, FALSE, 'out_of_scope', 'Client 18 Aug: not an agency-managed campaign. Previous agency, corrupt utm, or pre-2025 content.'),
  ('ga4_property_D', 'meta', 'corrupt_string_3', NULL, NULL, FALSE, FALSE, 'out_of_scope', 'Client 18 Aug: not an agency-managed campaign. Previous agency, corrupt utm, or pre-2025 content.'),
  ('ga4_property_D', 'meta', 'content_september', NULL, NULL, FALSE, FALSE, 'out_of_scope', 'Client 18 Aug: not an agency-managed campaign. Previous agency, corrupt utm, or pre-2025 content.'),
  ('ga4_property_D', 'meta', 'content_october', NULL, NULL, FALSE, FALSE, 'out_of_scope', 'Client 18 Aug: not an agency-managed campaign. Previous agency, corrupt utm, or pre-2025 content.'),
  ('ga4_property_D', 'dv360', 'brand_d_aon', 'Brand D', 'Brand D AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta. July reconciles to Looker dv360/cpm tile: 663 vs 665'),
  ('ga4_property_D', 'dv360', 'bc_condition_aon', 'Brand C', 'Brand C AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta for Brand C on both properties'),
  ('ga4_property_D', 'dv360', 'brand_d', 'Brand D', 'Brand D AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on meta'),
  ('ga4_property_D', 'dv360', 'be_aon', 'Brand E', 'Brand E AON', TRUE, TRUE, 'mapped', 'Same utm evidenced on the portal property'),
  ('ga4_property_D', 'dv360', '(not set)', NULL, NULL, FALSE, FALSE, 'not_paid', 'GA4 system value'),
  ('ga4_property_D', 'teads', 'brand_campaign_brand_d-smart-targeting', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'teads', 'aon_brand_c', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'programmatic', 'aon_brand_d', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'teads', 'brand_campaign_brand_d-custom-audience', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'fb-SiteLink', 'CAMPAIGN_ID_3', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'fb-SiteLink', 'CAMPAIGN_ID_4', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'teads', 'brand_campaign_brand_d-retargeting-with-pixel', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'facebook', 'brand_d', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'fb', 'CAMPAIGN_ID_3', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'fb', 'CAMPAIGN_ID_4', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'instagram', 'brand_d', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.'),
  ('ga4_property_D', 'nativeads', 'bc_condition_aon', NULL, NULL, TRUE, FALSE, 'out_of_scope', 'Client 18 Aug: historical activity. No connector or spend source to be added; outside current scope.')
]);

CREATE OR REPLACE VIEW `your-project.marketing.qc_utm_orphan` AS
WITH events_cte AS (
  SELECT 'ga4_property_E' AS property, source, campaign, event_name, event_count
  FROM `your-project.marketing.ga4_brand_e`
  UNION ALL
  SELECT 'ga4_property_D', source, campaign, event_name, event_count
  FROM `your-project.marketing.ga4_brand_d`
)
SELECT e.property, e.source, e.campaign,
       SUM(IF(e.event_name='session_start', e.event_count, 0)) AS session_count
FROM events_cte e
LEFT JOIN `your-project.marketing.dim_utm` m
  ON  m.property = e.property
 AND  m.traffic_source    = e.source
 AND  m.utm_key   = REGEXP_REPLACE(NORMALIZE(TRIM(e.campaign), NFKC), r'\s+', ' ')
WHERE e.source IN ('google','meta')
  AND m.utm_key IS NULL
GROUP BY 1,2,3
HAVING session_count > 0
ORDER BY session_count DESC;
