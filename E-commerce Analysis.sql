-- QUERY 1 — How Much Revenue Did We Make? (Basic Sanity Check)
SELECT
    order_id,
    order_item_id,
    price,
    freight_value,
    revenue
FROM fact_order_items;

SELECT
    order_id,
    SUM(revenue) AS [Total revenue per order]
FROM fact_order_items
GROUP BY order_id;


-- QUERY 2 — Revenue by Month (Trend Analysis)
SELECT
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS order_month,
    SUM(f.revenue)                                 AS total_revenue,
    COUNT(DISTINCT f.order_id)                     AS total_orders
FROM fact_order_items f
JOIN dim_orders o ON f.order_id = o.order_id
GROUP BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY order_month;


-- QUERY 3 — Running Total Revenue (Window Function)
SELECT
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM')           AS order_month,
    SUM(f.revenue)                                           AS monthly_revenue,
    SUM(SUM(f.revenue)) OVER (
        ORDER BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
    )                                                        AS running_total_revenue
FROM fact_order_items f
JOIN dim_orders o ON f.order_id = o.order_id
GROUP BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY order_month;


-- QUERY 4 — Top 10 Product Categories by Revenue
SELECT TOP 10
    p.product_category_name_english  AS category,
    SUM(f.revenue)                   AS total_revenue,
    COUNT(DISTINCT f.order_id)       AS total_orders,
    ROUND(AVG(f.price), 2)           AS avg_price
FROM fact_order_items f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.product_category_name_english
ORDER BY total_revenue DESC;


-- QUERY 5 — Late Delivery Rate by Seller State
SELECT
    s.seller_state,
    COUNT(*)                                                        AS total_deliveries,
    SUM(CASE WHEN o.order_delivered_customer_date
                   > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_deliveries,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date
                              > o.order_estimated_delivery_date THEN 1 ELSE 0 END)
              / COUNT(*), 2
    )                                                               AS late_delivery_rate_pct
FROM fact_order_items f
JOIN dim_sellers  s ON f.seller_id  = s.seller_id
JOIN dim_orders   o ON f.order_id   = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_state
ORDER BY late_delivery_rate_pct DESC;


-- QUERY 6 — Customer Review Score by Category
SELECT
    p.product_category_name_english  AS category,
    ROUND(AVG(CAST(r.review_score AS FLOAT)), 2) AS avg_review_score,
    COUNT(r.review_id)               AS total_reviews
FROM fact_order_items f
JOIN dim_products  p ON f.product_id  = p.product_id
JOIN dim_reviews   r ON f.order_id    = r.order_id
GROUP BY p.product_category_name_english
ORDER BY avg_review_score DESC;


-- QUERY 7 — Payment Method Analysis
SELECT
    pay.payment_type,
    COUNT(DISTINCT pay.order_id)        AS total_orders,
    SUM(pay.payment_value)              AS total_payment_value,
    ROUND(AVG(pay.payment_value), 2)    AS avg_payment_value,
    ROUND(AVG(pay.payment_installments), 2) AS avg_installments
FROM dim_payments pay
GROUP BY pay.payment_type
ORDER BY total_orders DESC;


-- QUERY 8 — Customer Geography (Top States)
SELECT TOP 10
    c.customer_state,
    COUNT(DISTINCT o.order_id)   AS total_orders,
    SUM(f.revenue)               AS total_revenue,
    ROUND(AVG(f.revenue), 2)     AS avg_order_revenue
FROM fact_order_items f
JOIN dim_orders    o ON f.order_id    = o.order_id
JOIN dim_customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_orders DESC;


-- QUERY 9 — Seller Performance Scorecard
SELECT
    f.seller_id,
    s.seller_state,
    COUNT(DISTINCT f.order_id)                                          AS total_orders,
    SUM(f.revenue)                                                      AS total_revenue,
    ROUND(AVG(CAST(r.review_score AS FLOAT)), 2)                        AS avg_review_score,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date
                              > o.order_estimated_delivery_date THEN 1 ELSE 0 END)
              / COUNT(*), 2
    )                                                                   AS late_delivery_rate_pct
FROM fact_order_items f
JOIN dim_sellers  s ON f.seller_id  = s.seller_id
JOIN dim_orders   o ON f.order_id   = o.order_id
JOIN dim_reviews  r ON f.order_id   = r.order_id
GROUP BY f.seller_id, s.seller_state
ORDER BY total_revenue DESC;


-- QUERY 10 — Day of Week Analysis
SELECT
    DATENAME(WEEKDAY, o.order_purchase_timestamp)   AS day_of_week,
    DATEPART(WEEKDAY, o.order_purchase_timestamp)   AS day_number,
    COUNT(DISTINCT f.order_id)                       AS total_orders,
    SUM(f.revenue)                                   AS total_revenue,
    ROUND(AVG(f.revenue), 2)                         AS avg_order_revenue
FROM fact_order_items f
JOIN dim_orders o ON f.order_id = o.order_id
GROUP BY
    DATENAME(WEEKDAY, o.order_purchase_timestamp),
    DATEPART(WEEKDAY, o.order_purchase_timestamp)
ORDER BY day_number;