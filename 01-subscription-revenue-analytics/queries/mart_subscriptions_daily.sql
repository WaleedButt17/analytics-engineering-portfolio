CREATE OR REPLACE VIEW `your-project.marts.mart_subscriptions_daily`
AS WITH

loop_subs AS (
  SELECT
    CAST(subscription_id AS STRING) AS subscription_id,
    CAST(customer_email AS STRING) AS customer_email,
    CAST(store AS STRING) AS store,
    'loop' AS platform,
    CAST(status AS STRING) AS status,
    CAST(cancellation_reason AS STRING) AS cancellation_reason,
    created_date,
    cancelled_date,
    paused_date,
    SAFE_DIVIDE(
      CAST(total_line_item_discounted_price AS FLOAT64),
      NULLIF(CAST(billing_interval_count AS FLOAT64), 0)
    ) AS monthly_value,
    CAST(last_payment_status AS STRING) AS last_payment_status,
    CAST(UPPER(country_code) AS STRING) AS country_code,
    CAST(next_billing_date AS DATE) AS next_billing_date,
    CAST(completed_orders_count AS INT64) AS completed_orders_count
  FROM `your-project.staging.stg_loop_subscriptions`
),

cc_subs AS (
  SELECT
    CAST(purchase_id AS STRING) AS subscription_id,
    CAST(NULL AS STRING) AS customer_email,
    CAST(NULL AS STRING) AS store,
    'checkoutchamp' AS platform,
    CAST(CASE
      WHEN status = 'ACTIVE' THEN 'ACTIVE'
      WHEN status = 'CANCELLED' THEN 'CANCELLED'
      WHEN status = 'PAUSED' THEN 'PAUSED'
      WHEN status IN ('RECYCLE_FAILED', 'RECYCLE_BILLING') THEN 'ACTIVE'
      WHEN status = 'COMPLETE' THEN 'CANCELLED'
      ELSE status
    END AS STRING) AS status,
    CAST(cancel_reason AS STRING) AS cancellation_reason,
    DATE(date_created) AS created_date,
    CAST(last_cancellation_date AS DATE) AS cancelled_date,
    CAST(NULL AS DATE) AS paused_date,
    SAFE_DIVIDE(
      CAST(price AS FLOAT64),
      SAFE_DIVIDE(CAST(billing_interval_days AS FLOAT64), 30.0)
    ) AS monthly_value,
    CAST(NULL AS STRING) AS last_payment_status,
    CAST(UPPER(country) AS STRING) AS country_code,
    CAST(DATE(next_bill_date) AS DATE) AS next_billing_date,
    CAST(billing_cycle_number AS INT64) AS completed_orders_count
  FROM `your-project.staging.stg_cc_purchases`
),

all_subs AS (
  SELECT * FROM loop_subs
  UNION ALL
  SELECT * FROM cc_subs
),

avg_months_cancelled AS (
  SELECT
    platform,
    ROUND(AVG(DATE_DIFF(cancelled_date, created_date, DAY) / 30.0), 2) AS avg_months_before_cancellation
  FROM all_subs
  WHERE status = 'CANCELLED'
  AND cancelled_date IS NOT NULL
  AND created_date IS NOT NULL
  GROUP BY platform
),

customer_first_order AS (
  SELECT customer_email, MIN(order_date) AS first_order_date
  FROM `your-project.staging.stg_shopify_orders`
  WHERE customer_email IS NOT NULL
  GROUP BY customer_email
),

shopify_new_customers AS (
  SELECT first_order_date AS order_date, COUNT(DISTINCT customer_email) AS new_customers
  FROM customer_first_order
  GROUP BY first_order_date
),

shopify_take_rate AS (
  SELECT
    order_date AS snapshot_date,
    SAFE_DIVIDE(
      COUNT(DISTINCT CASE
        WHEN order_type = 'NEW_SALE'
        OR source_name = 'subscription_contract_checkout_one'
        THEN order_id
      END),
      COUNT(DISTINCT order_id)
    ) AS subscription_take_rate
  FROM `your-project.staging.stg_shopify_orders`
  WHERE line_type = 'product'
  GROUP BY order_date
),

daily_new AS (
  SELECT
    a.created_date AS snapshot_date,
    a.platform,
    a.country_code,
    COUNT(DISTINCT a.subscription_id) AS new_subscribers,
    COUNT(DISTINCT CASE WHEN a.cancelled_date = a.created_date THEN a.subscription_id END) AS zero_day_churn,
    COUNT(DISTINCT CASE
      WHEN a.cancelled_date = a.created_date
      AND a.next_billing_date IS NOT NULL
      AND DATE_DIFF(a.next_billing_date, a.cancelled_date, DAY) <= 3
      THEN a.subscription_id
    END) AS upcoming_order_churn,
    COUNT(DISTINCT CASE WHEN a.cancellation_reason = 'Too expensive to continue' AND a.cancelled_date = a.created_date THEN a.subscription_id END) AS cancel_too_expensive,
    COUNT(DISTINCT CASE WHEN a.cancellation_reason = 'Already have enough stock' AND a.cancelled_date = a.created_date THEN a.subscription_id END) AS cancel_enough_stock,
    COUNT(DISTINCT CASE WHEN a.cancellation_reason = 'Not satisfied with the product' AND a.cancelled_date = a.created_date THEN a.subscription_id END) AS cancel_not_satisfied,
    COUNT(DISTINCT CASE WHEN a.cancellation_reason = 'Other reason' AND a.cancelled_date = a.created_date THEN a.subscription_id END) AS cancel_other
  FROM all_subs a
  WHERE a.created_date IS NOT NULL
  AND a.created_date < CURRENT_DATE()
  GROUP BY a.created_date, a.platform, a.country_code
),

daily_churned AS (
  SELECT
    cancelled_date AS snapshot_date,
    platform,
    country_code,
    COUNT(DISTINCT subscription_id) AS churned_subscribers
  FROM all_subs
  WHERE cancelled_date IS NOT NULL
  AND cancelled_date < CURRENT_DATE()
  GROUP BY cancelled_date, platform, country_code
),

daily_paused AS (
  SELECT
    paused_date AS snapshot_date,
    platform,
    country_code,
    COUNT(DISTINCT subscription_id) AS paused_subscribers
  FROM all_subs
  WHERE paused_date IS NOT NULL
  GROUP BY paused_date, platform, country_code
),

loop_daily_mrr AS (
  SELECT
    l.snapshot_date,
    l.country_code,
    SUM(CASE WHEN l.status = 'ACTIVE'
      THEN SAFE_DIVIDE(
        CAST(COALESCE(NULLIF(l.discounted_price, 0), l.total_line_item_discounted_price) AS NUMERIC),
        NULLIF(CAST(l.billing_interval_count AS NUMERIC), 0)
      ) * COALESCE(CAST(er.rate AS NUMERIC), NUMERIC '1')
      ELSE 0 END) AS mrr_including_recovery,
    SUM(CASE WHEN l.status = 'ACTIVE' AND l.last_payment_status = 'SUCCESS'
      THEN SAFE_DIVIDE(
        CAST(COALESCE(NULLIF(l.discounted_price, 0), l.total_line_item_discounted_price) AS NUMERIC),
        NULLIF(CAST(l.billing_interval_count AS NUMERIC), 0)
      ) * COALESCE(CAST(er.rate AS NUMERIC), NUMERIC '1')
      ELSE 0 END) AS mrr_excluding_recovery,
    COUNT(DISTINCT CASE WHEN l.status = 'ACTIVE' AND l.last_payment_status = 'SUCCESS' THEN l.subscription_id END) AS payment_success_count,
    COUNT(DISTINCT CASE WHEN l.status = 'ACTIVE' AND l.last_payment_status = 'FAILED' THEN l.subscription_id END) AS payment_failed_count,
    SUM(CASE
      WHEN l.status = 'ACTIVE'
      AND SAFE_CAST(l.next_billing_date_epoch AS INT64) IS NOT NULL
      AND DATE(TIMESTAMP_SECONDS(SAFE_CAST(l.next_billing_date_epoch AS INT64))) BETWEEN l.snapshot_date AND DATE_ADD(l.snapshot_date, INTERVAL 30 DAY)
      THEN CAST(COALESCE(NULLIF(l.discounted_price, 0), l.total_line_item_discounted_price) AS FLOAT64) * COALESCE(er.rate, 1.0)
      ELSE 0
    END) AS forecasted_30d_revenue_gross,
    COUNT(DISTINCT CASE
      WHEN l.status = 'ACTIVE'
      AND SAFE_CAST(l.next_billing_date_epoch AS INT64) IS NOT NULL
      AND DATE(TIMESTAMP_SECONDS(SAFE_CAST(l.next_billing_date_epoch AS INT64))) BETWEEN l.snapshot_date AND DATE_ADD(l.snapshot_date, INTERVAL 30 DAY)
      THEN l.subscription_id
    END) AS forecasted_30d_orders_gross
  FROM (
    SELECT
      DATE(ingested_at) AS snapshot_date,
      CAST(UPPER(country_code) AS STRING) AS country_code,
      CAST(subscription_id AS STRING) AS subscription_id,
      CAST(status AS STRING) AS status,
      CAST(last_payment_status AS STRING) AS last_payment_status,
      COALESCE(NULLIF(CAST(discounted_price AS FLOAT64), 0), CAST(total_line_item_discounted_price AS FLOAT64)) AS discounted_price,
      CAST(total_line_item_discounted_price AS FLOAT64) AS total_line_item_discounted_price,
      billing_interval_count,
      UPPER(currency_code) AS currency_code,
      next_billing_date_epoch
    FROM `your-project.raw.daily_loop_subscriptions`
    WHERE DATE(ingested_at) < CURRENT_DATE()
    QUALIFY ROW_NUMBER() OVER (PARTITION BY subscription_id, DATE(ingested_at) ORDER BY ingested_at DESC) = 1
  ) l
  LEFT JOIN `your-project.raw.daily_exchange_rates` er
    ON er.date = l.snapshot_date
    AND er.from_currency = l.currency_code
    AND er.to_currency = 'USD'
  GROUP BY l.snapshot_date, l.country_code
),

cc_daily_mrr AS (
  SELECT
    d.snapshot_date,
    CAST(UPPER(s.country) AS STRING) AS country_code,
    SUM(CASE WHEN s.status IN ('ACTIVE', 'RECYCLE_FAILED', 'RECYCLE_BILLING')
      THEN SAFE_DIVIDE(CAST(s.price AS NUMERIC), SAFE_DIVIDE(CAST(s.billing_interval_days AS NUMERIC), NUMERIC '30'))
      ELSE 0 END) AS mrr_including_recovery,
    CAST(0.0 AS FLOAT64) AS mrr_excluding_recovery,
    0 AS payment_success_count,
    0 AS payment_failed_count,
    SUM(CASE
      WHEN s.status IN ('ACTIVE', 'RECYCLE_FAILED', 'RECYCLE_BILLING')
      AND DATE(s.next_bill_date) BETWEEN d.snapshot_date AND DATE_ADD(d.snapshot_date, INTERVAL 30 DAY)
      THEN CAST(s.price AS NUMERIC) ELSE 0
    END) AS forecasted_30d_revenue_gross,
    COUNT(DISTINCT CASE
      WHEN s.status IN ('ACTIVE', 'RECYCLE_FAILED', 'RECYCLE_BILLING')
      AND DATE(s.next_bill_date) BETWEEN d.snapshot_date AND DATE_ADD(d.snapshot_date, INTERVAL 30 DAY)
      THEN CAST(s.purchase_id AS STRING)
    END) AS forecasted_30d_orders_gross
  FROM (
    SELECT date AS snapshot_date
    FROM UNNEST(GENERATE_DATE_ARRAY('2025-11-01', CURRENT_DATE() - 1)) AS date
  ) d
  CROSS JOIN `your-project.staging.stg_cc_purchases` s
  GROUP BY d.snapshot_date, CAST(UPPER(s.country) AS STRING)
),

loop_actual_active AS (
  SELECT
    DATE(ingested_at) AS snapshot_date,
    CAST(UPPER(country_code) AS STRING) AS country_code,
    COUNT(DISTINCT subscription_id) AS active_subscribers
  FROM (
    SELECT subscription_id, country_code, ingested_at
    FROM `your-project.raw.daily_loop_subscriptions`
    WHERE DATE(ingested_at) < CURRENT_DATE()
    AND status = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY subscription_id, DATE(ingested_at) ORDER BY ingested_at DESC) = 1
  )
  GROUP BY DATE(ingested_at), CAST(UPPER(country_code) AS STRING)
),

date_spine AS (
  SELECT DISTINCT snapshot_date, platform, country_code FROM daily_new
  UNION DISTINCT SELECT DISTINCT snapshot_date, platform, country_code FROM daily_churned
  UNION DISTINCT SELECT DISTINCT snapshot_date, 'loop' AS platform, country_code FROM loop_daily_mrr
  UNION DISTINCT SELECT DISTINCT snapshot_date, 'checkoutchamp' AS platform, country_code FROM cc_daily_mrr
),

daily_metrics AS (
  SELECT
    ds.snapshot_date,
    ds.platform,
    ds.country_code,
    COALESCE(dn.new_subscribers, 0) AS new_subscribers,
    COALESCE(dc.churned_subscribers, 0) AS churned_subscribers,
    COALESCE(dp.paused_subscribers, 0) AS paused_subscribers,
    COALESCE(dn.zero_day_churn, 0) AS zero_day_churn,
    COALESCE(dn.upcoming_order_churn, 0) AS upcoming_order_churn,
    COALESCE(dn.cancel_too_expensive, 0) AS cancel_too_expensive,
    COALESCE(dn.cancel_enough_stock, 0) AS cancel_enough_stock,
    COALESCE(dn.cancel_not_satisfied, 0) AS cancel_not_satisfied,
    COALESCE(dn.cancel_other, 0) AS cancel_other,
    CASE WHEN ds.platform = 'loop' THEN COALESCE(lm.mrr_including_recovery, 0)
         WHEN ds.platform = 'checkoutchamp' THEN COALESCE(CAST(cm.mrr_including_recovery AS FLOAT64), 0)
         ELSE 0 END AS mrr_including_recovery,
    CASE WHEN ds.platform = 'loop' THEN COALESCE(lm.mrr_excluding_recovery, 0)
         ELSE 0 END AS mrr_excluding_recovery,
    CASE WHEN ds.platform = 'loop' THEN COALESCE(lm.forecasted_30d_revenue_gross, 0)
         WHEN ds.platform = 'checkoutchamp' THEN COALESCE(CAST(cm.forecasted_30d_revenue_gross AS FLOAT64), 0)
         ELSE 0 END AS forecasted_30d_revenue_gross,
    CASE WHEN ds.platform = 'loop' THEN COALESCE(lm.forecasted_30d_orders_gross, 0)
         WHEN ds.platform = 'checkoutchamp' THEN COALESCE(cm.forecasted_30d_orders_gross, 0)
         ELSE 0 END AS forecasted_30d_orders_gross,
    CASE WHEN ds.platform = 'loop' THEN COALESCE(lm.payment_success_count, 0) ELSE 0 END AS payment_success_count,
    CASE WHEN ds.platform = 'loop' THEN COALESCE(lm.payment_failed_count, 0) ELSE 0 END AS payment_failed_count
  FROM date_spine ds
  LEFT JOIN daily_new dn ON ds.snapshot_date = dn.snapshot_date AND ds.platform = dn.platform AND ds.country_code = dn.country_code
  LEFT JOIN daily_churned dc ON ds.snapshot_date = dc.snapshot_date AND ds.platform = dc.platform AND ds.country_code = dc.country_code
  LEFT JOIN daily_paused dp ON ds.snapshot_date = dp.snapshot_date AND ds.platform = dp.platform AND ds.country_code = dp.country_code
  LEFT JOIN loop_daily_mrr lm ON ds.snapshot_date = lm.snapshot_date AND ds.country_code = lm.country_code AND ds.platform = 'loop'
  LEFT JOIN cc_daily_mrr cm ON ds.snapshot_date = cm.snapshot_date AND ds.country_code = cm.country_code AND ds.platform = 'checkoutchamp'
),

running_active AS (
  SELECT
    snapshot_date, platform, country_code,
    SUM(new_subscribers) OVER (PARTITION BY platform, country_code ORDER BY snapshot_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    - SUM(churned_subscribers) OVER (PARTITION BY platform, country_code ORDER BY snapshot_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    AS active_subscribers,
    new_subscribers, churned_subscribers, paused_subscribers, zero_day_churn, upcoming_order_churn,
    mrr_including_recovery, mrr_excluding_recovery, forecasted_30d_revenue_gross, forecasted_30d_orders_gross,
    payment_success_count, payment_failed_count,
    cancel_too_expensive, cancel_enough_stock, cancel_not_satisfied, cancel_other
  FROM daily_metrics
  WHERE platform IN ('loop', 'checkoutchamp')
),

combined_metrics AS (
  SELECT
    r.snapshot_date, 'combined' AS platform, CAST(r.country_code AS STRING) AS country_code,
    SUM(CASE WHEN r.platform = 'loop'
      THEN COALESCE(la.active_subscribers, r.active_subscribers)
      ELSE r.active_subscribers
    END) AS active_subscribers,
    SUM(r.new_subscribers) AS new_subscribers,
    SUM(r.churned_subscribers) AS churned_subscribers,
    SUM(r.paused_subscribers) AS paused_subscribers,
    SUM(r.zero_day_churn) AS zero_day_churn,
    SUM(r.upcoming_order_churn) AS upcoming_order_churn,
    SUM(r.mrr_including_recovery) AS mrr_including_recovery,
    SUM(r.mrr_excluding_recovery) AS mrr_excluding_recovery,
    SUM(r.forecasted_30d_revenue_gross) AS forecasted_30d_revenue_gross,
    SUM(r.forecasted_30d_orders_gross) AS forecasted_30d_orders_gross,
    SUM(r.payment_success_count) AS payment_success_count,
    SUM(r.payment_failed_count) AS payment_failed_count,
    SUM(r.cancel_too_expensive) AS cancel_too_expensive,
    SUM(r.cancel_enough_stock) AS cancel_enough_stock,
    SUM(r.cancel_not_satisfied) AS cancel_not_satisfied,
    SUM(r.cancel_other) AS cancel_other
  FROM running_active r
  LEFT JOIN loop_actual_active la
    ON r.snapshot_date = la.snapshot_date
    AND r.country_code = la.country_code
    AND r.platform = 'loop'
  GROUP BY r.snapshot_date, r.country_code
),

cc_payment AS (
  SELECT transaction_date,
    SUM(first_attempt_success) AS cc_first_attempt_success,
    SUM(eventually_succeeded) AS cc_eventually_succeeded,
    SUM(total_billing_cycles) AS cc_total_billing_cycles
  FROM `your-project.marts.mart_cc_payment_health`
  GROUP BY transaction_date
)

SELECT
  r.snapshot_date, r.platform, r.country_code,
  CASE WHEN r.platform = 'loop'
    THEN COALESCE(la.active_subscribers, r.active_subscribers)
    ELSE r.active_subscribers
  END AS active_subscribers,
  SUM(CASE WHEN r.platform = 'loop'
    THEN COALESCE(la.active_subscribers, r.active_subscribers)
    ELSE r.active_subscribers
  END) OVER (PARTITION BY r.snapshot_date, r.platform) AS total_active_subscribers,
  CASE WHEN EXTRACT(DAY FROM r.snapshot_date) = 1
    THEN CASE WHEN r.platform = 'loop'
      THEN COALESCE(la.active_subscribers, r.active_subscribers)
      ELSE r.active_subscribers
    END
    ELSE NULL
  END AS active_subscribers_start,
  r.new_subscribers, r.churned_subscribers, r.paused_subscribers, r.zero_day_churn, r.upcoming_order_churn,
  r.mrr_including_recovery, r.mrr_excluding_recovery, r.forecasted_30d_revenue_gross, r.forecasted_30d_orders_gross,
  r.payment_success_count, r.payment_failed_count,
  SAFE_DIVIDE(r.payment_success_count, r.payment_success_count + r.payment_failed_count) AS payment_success_rate,
  SAFE_DIVIDE(r.churned_subscribers, r.active_subscribers) AS churn_rate,
  SAFE_DIVIDE(r.zero_day_churn, r.new_subscribers) AS zero_day_churn_rate,
  SAFE_DIVIDE(r.upcoming_order_churn, r.active_subscribers) AS upcoming_order_churn_rate,
  r.cancel_too_expensive, r.cancel_enough_stock, r.cancel_not_satisfied, r.cancel_other,
  str.subscription_take_rate, a.avg_months_before_cancellation,
  SAFE_DIVIDE(p.cc_first_attempt_success, COUNT(*) OVER (PARTITION BY r.snapshot_date, r.platform)) AS cc_first_attempt_success,
  SAFE_DIVIDE(p.cc_eventually_succeeded, COUNT(*) OVER (PARTITION BY r.snapshot_date, r.platform)) AS cc_eventually_succeeded,
  SAFE_DIVIDE(p.cc_total_billing_cycles, COUNT(*) OVER (PARTITION BY r.snapshot_date, r.platform)) AS cc_total_billing_cycles,
  SAFE_DIVIDE(nc.new_customers, COUNT(*) OVER (PARTITION BY r.snapshot_date, r.platform)) AS shopify_new_customers_allocated
FROM running_active r
LEFT JOIN loop_actual_active la
  ON r.snapshot_date = la.snapshot_date
  AND r.country_code = la.country_code
  AND r.platform = 'loop'
LEFT JOIN avg_months_cancelled a ON r.platform = a.platform
LEFT JOIN cc_payment p ON r.snapshot_date = p.transaction_date AND r.platform = 'checkoutchamp'
LEFT JOIN shopify_new_customers nc ON r.snapshot_date = nc.order_date
LEFT JOIN shopify_take_rate str ON r.snapshot_date = str.snapshot_date

UNION ALL

SELECT
  c.snapshot_date, c.platform, c.country_code, c.active_subscribers,
  SUM(c.active_subscribers) OVER (PARTITION BY c.snapshot_date, c.platform) AS total_active_subscribers,
  CASE WHEN EXTRACT(DAY FROM c.snapshot_date) = 1 THEN c.active_subscribers ELSE NULL END AS active_subscribers_start,
  c.new_subscribers, c.churned_subscribers, c.paused_subscribers, c.zero_day_churn, c.upcoming_order_churn,
  c.mrr_including_recovery, c.mrr_excluding_recovery, c.forecasted_30d_revenue_gross, c.forecasted_30d_orders_gross,
  c.payment_success_count, c.payment_failed_count,
  SAFE_DIVIDE(c.payment_success_count, c.payment_success_count + c.payment_failed_count) AS payment_success_rate,
  SAFE_DIVIDE(c.churned_subscribers, c.active_subscribers) AS churn_rate,
  SAFE_DIVIDE(c.zero_day_churn, c.new_subscribers) AS zero_day_churn_rate,
  SAFE_DIVIDE(c.upcoming_order_churn, c.active_subscribers) AS upcoming_order_churn_rate,
  c.cancel_too_expensive, c.cancel_enough_stock, c.cancel_not_satisfied, c.cancel_other,
  str.subscription_take_rate, NULL AS avg_months_before_cancellation,
  SAFE_DIVIDE(p.cc_first_attempt_success, COUNT(*) OVER (PARTITION BY c.snapshot_date)) AS cc_first_attempt_success,
  SAFE_DIVIDE(p.cc_eventually_succeeded, COUNT(*) OVER (PARTITION BY c.snapshot_date)) AS cc_eventually_succeeded,
  SAFE_DIVIDE(p.cc_total_billing_cycles, COUNT(*) OVER (PARTITION BY c.snapshot_date)) AS cc_total_billing_cycles,
  SAFE_DIVIDE(nc.new_customers, COUNT(*) OVER (PARTITION BY c.snapshot_date)) AS shopify_new_customers_allocated
FROM combined_metrics c
LEFT JOIN cc_payment p ON c.snapshot_date = p.transaction_date
LEFT JOIN shopify_new_customers nc ON c.snapshot_date = nc.order_date
LEFT JOIN shopify_take_rate str ON c.snapshot_date = str.snapshot_date;
