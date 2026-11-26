SELECT
  COUNT(*)                                                        AS n_rows,
  SUM(event_count)                                                AS all_events,
  SUM(IF(event_name = 'click_orientation', event_count, 0))       AS only_orientation
FROM `your-project.marketing.ga4_brand_a_orientation_v3`
WHERE date BETWEEN DATE '2026-08-10' AND DATE '2026-08-16';

SELECT
  SUM(event_count) AS no_guards,
  SUM(IF(customevent_cta_name = 'orientation', event_count, 0)) AS after_cta,
  SUM(IF(customevent_cta_name = 'orientation'
         AND customevent_item_id = '(not set)', event_count, 0)) AS after_item,
  SUM(IF(customevent_cta_name = 'orientation'
         AND customevent_item_id = '(not set)'
         AND customevent_association_name = '(not set)', event_count, 0)) AS after_assoc,
  SUM(IF(customevent_cta_name = 'orientation'
         AND customevent_item_id = '(not set)'
         AND customevent_association_name = '(not set)'
         AND customevent_form_id = '(not set)', event_count, 0)) AS after_form
FROM `your-project.marketing.ga4_brand_a_orientation_v3`
WHERE date BETWEEN DATE '2026-08-10' AND DATE '2026-08-16'
  AND event_name = 'click_orientation';

SELECT
  customevent_cta_name,
  customevent_item_id,
  customevent_association_name,
  customevent_form_id,
  COUNT(*)         AS n_rows,
  SUM(event_count) AS events_cte
FROM `your-project.marketing.ga4_brand_a_orientation_v3`
WHERE date BETWEEN DATE '2026-08-10' AND DATE '2026-08-16'
  AND event_name = 'click_orientation'
GROUP BY 1, 2, 3, 4
ORDER BY events_cte DESC;

SELECT date, COUNT(*) AS n_rows, SUM(event_count) AS events_cte
FROM `your-project.marketing.ga4_brand_a_orientation_v3`
WHERE date BETWEEN DATE '2026-08-10' AND DATE '2026-08-16'
  AND event_name = 'click_orientation'
GROUP BY date ORDER BY date;

SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT FORMAT('%t|%t|%t', date, session_source_medium, page_location))
    AS match_keys,
  COUNT(DISTINCT FORMAT('%t|%t|%t|%t|%t', date, session_source_medium,
                        page_location, campaign, event_name))
    AS combinations_real
FROM `your-project.marketing.ga4_brand_a_orientation_v3`
WHERE date BETWEEN DATE '2026-08-10' AND DATE '2026-08-16';

SELECT SUM(clicks) AS week32
FROM `your-project.marketing.tf_brand_a_weekly_orientation_v2`(
       DATE '2026-08-03', DATE '2026-08-09');
