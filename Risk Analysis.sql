-- ============================================================
-- FCR QUERY 1 — Risk Tier Summary Dashboard
-- ============================================================
SELECT
    risk_tier,
    COUNT(*)                            AS customer_count,
    ROUND(AVG(composite_risk_score), 2) AS avg_risk_score,
    ROUND(AVG(total_spend), 2)          AS avg_total_spend,
    SUM(aml_alert)                      AS alerts_triggered,
    ROUND(100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (), 2)       AS pct_of_customers
FROM fcr_master_risk_table
GROUP BY risk_tier
ORDER BY avg_risk_score DESC;


-- ============================================================
-- FCR QUERY 2 — Top 20 Highest Risk Customers
-- ============================================================
SELECT TOP 20
    customer_id,
    dominant_state,
    total_orders,
    ROUND(total_spend, 2)           AS total_spend,
    ROUND(composite_risk_score, 2)  AS risk_score,
    risk_tier,
    total_flags_fired,
    high_velocity_flag,
    structuring_flag,
    behavioral_flag,
    aml_alert
FROM fcr_master_risk_table
WHERE risk_tier IN ('CRITICAL', 'HIGH')
ORDER BY composite_risk_score DESC;


-- ============================================================
-- FCR QUERY 3 — AML Alert Investigation
-- What did flagged customers actually buy?
-- ============================================================
SELECT
    f.customer_id,
    f.risk_tier,
    f.composite_risk_score,
    p.product_category_name,
    COUNT(DISTINCT o.order_id)      AS orders_in_category,
    ROUND(SUM(i.revenue), 2)        AS revenue_in_category,
    ROUND(AVG(pay.payment_value),2) AS avg_payment
FROM fcr_master_risk_table f
JOIN fact_orders o           ON f.customer_id  = o.customer_id
JOIN fact_order_items i      ON o.order_id     = i.order_id
JOIN dim_products p          ON i.product_id   = p.product_id
JOIN order_payments pay      ON o.order_id     = pay.order_id
WHERE f.aml_alert = 1
GROUP BY f.customer_id, f.risk_tier,
         f.composite_risk_score, p.product_category_name
ORDER BY f.composite_risk_score DESC, revenue_in_category DESC;


-- ============================================================
-- FCR QUERY 4 — Structuring Pattern Detection
-- Customers with suspicious transaction patterns
-- ============================================================
SELECT
    f.customer_id,
    f.dominant_state,
    s.total_transactions,
    ROUND(s.avg_transaction_value, 2) AS avg_txn_value,
    s.round_number_txns,
    s.below_threshold_txns,
    s.unusual_installment_txns,
    ROUND(s.structuring_risk_score, 2) AS structuring_score,
    f.risk_tier
FROM fcr_master_risk_table f
JOIN fcr_structuring_features s ON f.customer_id = s.customer_id
WHERE s.structuring_flag = 1
ORDER BY s.structuring_risk_score DESC;


-- ============================================================
-- FCR QUERY 5 — Geographic Risk Heatmap
-- Which states have highest concentration of risk?
-- ============================================================
SELECT
    dominant_state,
    COUNT(*)                                AS total_customers,
    SUM(aml_alert)                          AS aml_alerts,
    ROUND(AVG(composite_risk_score), 2)     AS avg_risk_score,
    SUM(CASE WHEN risk_tier = 'CRITICAL'
             THEN 1 ELSE 0 END)             AS critical_count,
    SUM(CASE WHEN risk_tier = 'HIGH'
             THEN 1 ELSE 0 END)             AS high_count,
    ROUND(100.0 * SUM(aml_alert)
          / COUNT(*), 2)                    AS alert_rate_pct
FROM fcr_master_risk_table
GROUP BY dominant_state
ORDER BY avg_risk_score DESC;


-- ============================================================
-- FCR QUERY 6 — Monthly AML Alert Trend
-- Are suspicious activities increasing over time?
-- ============================================================
SELECT
    o.order_year,
    o.order_month,
    COUNT(DISTINCT o.order_id)              AS total_orders,
    COUNT(DISTINCT CASE WHEN f.aml_alert = 1
        THEN o.order_id END)                AS flagged_orders,
    ROUND(100.0 *
        COUNT(DISTINCT CASE WHEN f.aml_alert = 1
        THEN o.order_id END) /
        COUNT(DISTINCT o.order_id), 2)      AS alert_rate_pct,
    ROUND(SUM(CASE WHEN f.aml_alert = 1
        THEN p.payment_value ELSE 0 END), 2) AS flagged_value
FROM fact_orders o
JOIN order_payments p        ON o.order_id    = p.order_id
JOIN fcr_master_risk_table f ON o.customer_id = f.customer_id
GROUP BY o.order_year, o.order_month
ORDER BY o.order_year, o.order_month;