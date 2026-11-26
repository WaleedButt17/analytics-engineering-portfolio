CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_user_acquisition_funnel` AS
WITH user_events AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_date,
    platform,
    traffic_source_name AS campaign,
    interaction_type,
    event_timestamp
  FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
),
installs AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS install_date,
    platform,
    campaign
  FROM user_events
  WHERE event_name = 'first_open'
  GROUP BY user_pseudo_id, platform, campaign
),
favorites_screen AS (
  SELECT DISTINCT
    e.user_pseudo_id
  FROM `your-project.analytics_XXXXXXXXX.events_*` e,
  UNNEST(e.event_params) AS ep
  WHERE e.event_name = 'screen_view_manual'
    AND ep.key = 'screen_name'
    AND ep.value.string_value = 'FavoritesScreen'
    AND e.user_pseudo_id IN (SELECT user_pseudo_id FROM installs)
    AND _TABLE_SUFFIX >= '20240101'
),
signups AS (
  SELECT DISTINCT user_pseudo_id
  FROM user_events
  WHERE event_name = 'signup_completed'
),
interactions AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS interaction_count
  FROM user_events
  WHERE event_name = 'content_action'
    AND interaction_type IN (
      'like', 'unlike', 'share', 'save', 'unsave',
      'comment', 'comment_submit', 'report', 'click'
    )
  GROUP BY user_pseudo_id
),
first_interaction AS (
  SELECT DISTINCT i.user_pseudo_id
  FROM interactions i
  INNER JOIN signups s ON i.user_pseudo_id = s.user_pseudo_id
  WHERE i.interaction_count >= 1
),
active_users AS (
  SELECT DISTINCT i.user_pseudo_id
  FROM interactions i
  INNER JOIN signups s ON i.user_pseudo_id = s.user_pseudo_id
  WHERE i.interaction_count >= 2
),
funnel_base AS (
  SELECT
    i.install_date,
    i.platform,
    i.campaign,
    COUNT(DISTINCT i.user_pseudo_id)                                                   AS installs,
    COUNT(DISTINCT CASE WHEN fs.user_pseudo_id IS NOT NULL THEN i.user_pseudo_id END)  AS favorites_screen_users,
    COUNT(DISTINCT CASE WHEN s.user_pseudo_id  IS NOT NULL THEN i.user_pseudo_id END)  AS signups,
    COUNT(DISTINCT CASE WHEN fi.user_pseudo_id IS NOT NULL THEN i.user_pseudo_id END)  AS first_interactions,
    COUNT(DISTINCT CASE WHEN au.user_pseudo_id IS NOT NULL THEN i.user_pseudo_id END)  AS active_users
  FROM installs i
  LEFT JOIN favorites_screen fs ON i.user_pseudo_id = fs.user_pseudo_id
  LEFT JOIN signups s            ON i.user_pseudo_id = s.user_pseudo_id
  LEFT JOIN first_interaction fi ON i.user_pseudo_id = fi.user_pseudo_id
  LEFT JOIN active_users au      ON i.user_pseudo_id = au.user_pseudo_id
  GROUP BY i.install_date, i.platform, i.campaign
)

SELECT
  PARSE_DATE('%Y%m%d', install_date) AS event_date,
  platform,
  campaign,
  1                                  AS stage_order,
  '1. Install'                       AS stage_name,
  installs                           AS users,
  installs                           AS prev_stage_users,
  0                                  AS dropoff_users,
  100.00                             AS stage_conv_pct,
  0.00                               AS dropoff_pct,
  installs                           AS installs,
  favorites_screen_users             AS favorites_screen_users,
  signups                            AS signups,
  first_interactions                 AS first_interactions,
  active_users                       AS active_users
FROM funnel_base

UNION ALL
SELECT
  PARSE_DATE('%Y%m%d', install_date),
  platform,
  campaign,
  2,
  '2. FavoritesScreen',
  favorites_screen_users,
  installs,
  installs - favorites_screen_users,
  ROUND(SAFE_DIVIDE(favorites_screen_users, installs) * 100, 2),
  ROUND(SAFE_DIVIDE(installs - favorites_screen_users, installs) * 100, 2),
  installs,
  favorites_screen_users,
  signups,
  first_interactions,
  active_users
FROM funnel_base

UNION ALL
SELECT
  PARSE_DATE('%Y%m%d', install_date),
  platform,
  campaign,
  3,
  '3. Signup',
  signups,
  favorites_screen_users,
  favorites_screen_users - signups,
  ROUND(SAFE_DIVIDE(signups, favorites_screen_users) * 100, 2),
  ROUND(SAFE_DIVIDE(favorites_screen_users - signups, favorites_screen_users) * 100, 2),
  installs,
  favorites_screen_users,
  signups,
  first_interactions,
  active_users
FROM funnel_base

UNION ALL
SELECT
  PARSE_DATE('%Y%m%d', install_date),
  platform,
  campaign,
  4,
  '4. First Interaction',
  first_interactions,
  signups,
  signups - first_interactions,
  ROUND(SAFE_DIVIDE(first_interactions, signups) * 100, 2),
  ROUND(SAFE_DIVIDE(signups - first_interactions, signups) * 100, 2),
  installs,
  favorites_screen_users,
  signups,
  first_interactions,
  active_users
FROM funnel_base

UNION ALL
SELECT
  PARSE_DATE('%Y%m%d', install_date),
  platform,
  campaign,
  5,
  '5. Active User',
  active_users,
  first_interactions,
  first_interactions - active_users,
  ROUND(SAFE_DIVIDE(active_users, first_interactions) * 100, 2),
  ROUND(SAFE_DIVIDE(first_interactions - active_users, first_interactions) * 100, 2),
  installs,
  favorites_screen_users,
  signups,
  first_interactions,
  active_users
FROM funnel_base

ORDER BY event_date, stage_order;
