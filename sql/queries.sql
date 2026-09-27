-- =========================================================
-- Retail Sales Analysis — Business Query Set
-- Tables: customers, products, orders, order_items
-- Revenue formula: quantity * unit_price * (1 - discount)
-- =========================================================

-- ---------------------------------------------------------
-- 1. Monthly revenue trend (GROUP BY + JOIN + CASE for season flag)
-- ---------------------------------------------------------
SELECT
    strftime('%Y-%m', o.order_date) AS order_month,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS revenue,
    CASE
        WHEN CAST(strftime('%m', o.order_date) AS INTEGER) IN (10, 11, 12) THEN 'Holiday Season'
        ELSE 'Regular Season'
    END AS season_flag
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY order_month
ORDER BY order_month;


-- ---------------------------------------------------------
-- 2. Revenue and profit by category (JOIN + aggregation)
-- ---------------------------------------------------------
SELECT
    p.category,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS revenue,
    ROUND(SUM(oi.quantity * (p.unit_price * (1 - oi.discount) - p.unit_cost)), 2) AS profit,
    ROUND(100.0 * SUM(oi.quantity * (p.unit_price * (1 - oi.discount) - p.unit_cost))
          / SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS profit_margin_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;


-- ---------------------------------------------------------
-- 3. Top 10 customers by lifetime revenue (JOIN + subquery in FROM)
-- ---------------------------------------------------------
SELECT
    c.customer_name,
    c.region,
    c.segment,
    customer_revenue.total_revenue
FROM (
    SELECT
        o.customer_id,
        ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS total_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY o.customer_id
) AS customer_revenue
JOIN customers c ON c.customer_id = customer_revenue.customer_id
ORDER BY customer_revenue.total_revenue DESC
LIMIT 10;


-- ---------------------------------------------------------
-- 4. Running (cumulative) monthly revenue — WINDOW FUNCTION
-- ---------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_date) AS order_month,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS running_total,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY order_month), 2) AS mom_change
FROM monthly_revenue
ORDER BY order_month;


-- ---------------------------------------------------------
-- 5. Rank products within each category by revenue — WINDOW FUNCTION (RANK)
-- ---------------------------------------------------------
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_name,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT
        category,
        product_name,
        ROUND(revenue, 2) AS revenue,
        RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT * FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;
-- Note: written with a CTE + WHERE filter (instead of QUALIFY) so it runs on
-- SQLite directly; on Snowflake/BigQuery/Postgres you could use QUALIFY instead.


-- ---------------------------------------------------------
-- 6. Customer segmentation by spend tier — CASE + subquery
-- ---------------------------------------------------------
WITH customer_totals AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount)) AS total_spent
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY o.customer_id
)
SELECT
    CASE
        WHEN total_spent >= 450000 THEN 'High Value'
        WHEN total_spent >= 275000 THEN 'Mid Value'
        ELSE 'Low Value'
    END AS spend_tier,
    COUNT(*) AS num_customers,
    ROUND(AVG(total_spent), 2) AS avg_spend,
    ROUND(SUM(total_spent), 2) AS tier_revenue
FROM customer_totals
GROUP BY spend_tier
ORDER BY tier_revenue DESC;


-- ---------------------------------------------------------
-- 7. Average order value and order count by region (JOIN + aggregation)
-- ---------------------------------------------------------
SELECT
    c.region,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS revenue,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount))
          / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY c.region
ORDER BY revenue DESC;


-- ---------------------------------------------------------
-- 8. Customers who have NOT ordered in the last 90 days of the dataset
--    (subquery with NOT IN — churn-risk candidates)
-- ---------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_name,
    c.region,
    c.segment
FROM customers c
WHERE c.customer_id NOT IN (
    SELECT DISTINCT o.customer_id
    FROM orders o
    WHERE o.order_date >= (SELECT date(MAX(order_date), '-90 days') FROM orders)
)
ORDER BY c.customer_name;


-- ---------------------------------------------------------
-- 9. Average discount and its effect on order size (GROUP BY + CASE bucket)
-- ---------------------------------------------------------
SELECT
    CASE
        WHEN oi.discount = 0 THEN 'No Discount'
        WHEN oi.discount <= 0.10 THEN 'Low (5-10%)'
        ELSE 'High (15-20%)'
    END AS discount_band,
    COUNT(*) AS line_items,
    ROUND(AVG(oi.quantity), 2) AS avg_quantity,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY discount_band
ORDER BY revenue DESC;


-- ---------------------------------------------------------
-- 10. New vs. returning customer revenue per month — CTE + window function (ROW_NUMBER)
-- ---------------------------------------------------------
WITH order_seq AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS order_rank
    FROM orders o
)
SELECT
    strftime('%Y-%m', os.order_date) AS order_month,
    CASE WHEN os.order_rank = 1 THEN 'New Customer' ELSE 'Returning Customer' END AS customer_type,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount)), 2) AS revenue
FROM order_seq os
JOIN order_items oi ON oi.order_id = os.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY order_month, customer_type
ORDER BY order_month, customer_type;
