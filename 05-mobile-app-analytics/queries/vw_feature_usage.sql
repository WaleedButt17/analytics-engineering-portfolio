CREATE OR REPLACE VIEW `your-project.analytics_XXXXXXXXX.vw_feature_usage` AS
SELECT
  event_date,
  platform,
  traffic_source_name AS campaign,
  CASE
    WHEN event_name = 'screen_view_manual' AND screen_name = 'FavoritesScreen' THEN 'Trending Feed'
    WHEN event_name = 'screen_view_manual' AND screen_name = 'FollowingsScreen' THEN 'Following Feed'
    WHEN event_name IN ('video_like', 'video_like_fyp', 'video_like_home', 'video_like_followings') THEN 'Likes'
    WHEN event_name IN ('video_comment', 'video_comment_fyp', 'video_comment_home', 'video_comment_followings', 'video_comment_submit') THEN 'Comments'
    WHEN event_name IN ('notification_open', 'notification_receive', 'notification_dismiss', 'notification_mark_read', 'notification_mark_all_read', 'view_notifications', 'click_notification', 'notification_open_profile', 'notification_open_video', 'notification_open_order', 'notification_open_message') THEN 'Notifications'
    WHEN event_name = 'follow_contributor' THEN 'Follow Contributor'
    WHEN event_name = 'search_started' AND search_query IS NOT NULL THEN 'Search'
  END AS feature_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS total_users
FROM `your-project.analytics_XXXXXXXXX.vw_base_flat`
WHERE (
  (event_name = 'screen_view_manual' AND screen_name IN ('FavoritesScreen', 'FollowingsScreen'))
  OR (event_name = 'search_started' AND search_query IS NOT NULL)
  OR event_name IN (
    'video_like', 'video_like_fyp', 'video_like_home', 'video_like_followings',
    'video_comment', 'video_comment_fyp', 'video_comment_home', 'video_comment_followings', 'video_comment_submit',
    'notification_open', 'notification_receive', 'notification_dismiss', 'notification_mark_read', 'notification_mark_all_read', 'view_notifications', 'click_notification', 'notification_open_profile', 'notification_open_video', 'notification_open_order', 'notification_open_message',
    'follow_contributor'
  )
)
GROUP BY event_date, platform, campaign, feature_name;
