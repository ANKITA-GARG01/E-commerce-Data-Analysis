-- create_tables.sql
-- Run this ONCE in SSMS before running load.py
-- This defines the structure (schema) of every table

USE ecommerce_db;

-- ── DROP existing tables (safe re-run) ──────────────────────
-- We drop in reverse order because of foreign key dependencies
-- Child tables must be dropped before parent tables
IF OBJECT_ID('fact_order_items', 'U') IS NOT NULL DROP TABLE fact_order_items;
IF OBJECT_ID('fact_orders',      'U') IS NOT NULL DROP TABLE fact_orders;
IF OBJECT_ID('order_payments',   'U') IS NOT NULL DROP TABLE order_payments;
IF OBJECT_ID('order_reviews',    'U') IS NOT NULL DROP TABLE order_reviews;
IF OBJECT_ID('dim_customers',    'U') IS NOT NULL DROP TABLE dim_customers;
IF OBJECT_ID('dim_products',     'U') IS NOT NULL DROP TABLE dim_products;
IF OBJECT_ID('dim_sellers',      'U') IS NOT NULL DROP TABLE dim_sellers;

-- ── DIMENSION TABLE: Customers ───────────────────────────────
-- WHO placed the orders?
CREATE TABLE dim_customers (
    customer_id         VARCHAR(255) PRIMARY KEY,
    customer_unique_id  VARCHAR(255),
    customer_city       VARCHAR(255),
    customer_state      VARCHAR(10),
    customer_zip_code_prefix VARCHAR(20)
);

-- ── DIMENSION TABLE: Products ────────────────────────────────
-- WHAT was ordered?
CREATE TABLE dim_products (
    product_id              VARCHAR(255) PRIMARY KEY,
    product_category_name   VARCHAR(255),
    product_weight_g        FLOAT,
    product_length_cm       FLOAT,
    product_height_cm       FLOAT,
    product_width_cm        FLOAT
);

-- ── DIMENSION TABLE: Sellers ─────────────────────────────────
-- WHO sold the products?
CREATE TABLE dim_sellers (
    seller_id               VARCHAR(255) PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR(20),
    seller_city             VARCHAR(255),
    seller_state            VARCHAR(10)
);

-- ── FACT TABLE: Orders ───────────────────────────────────────
-- The center of our Star Schema — every order ever placed
CREATE TABLE fact_orders (
    order_id                        VARCHAR(255) PRIMARY KEY,
    customer_id                     VARCHAR(255),
    order_status                    VARCHAR(50),
    order_purchase_timestamp        DATETIME,
    order_delivered_customer_date   DATETIME,
    order_estimated_delivery_date   DATETIME,
    order_year                      INT,
    order_month                     INT,
    order_quarter                   INT,
    order_day_of_week               VARCHAR(20),
    delivery_days                   FLOAT,
    is_late_delivery                INT,

    -- Foreign key: each order must belong to a known customer
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customers(customer_id)
);

-- ── FACT TABLE: Order Items ──────────────────────────────────
-- Revenue lives here — one row per item per order
CREATE TABLE fact_order_items (
    order_id            VARCHAR(255),
    order_item_id       INT,
    product_id          VARCHAR(255),
    seller_id           VARCHAR(255),
    shipping_limit_date DATETIME,
    price               FLOAT,
    freight_value       FLOAT,
    revenue             FLOAT,

    -- Composite primary key: one order can have multiple items
    -- so order_id alone is not unique — we need both columns
    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id)
        REFERENCES dim_products(product_id),

    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES dim_sellers(seller_id)
);

-- ── SUPPORTING TABLE: Payments ───────────────────────────────
CREATE TABLE order_payments (
    order_id                VARCHAR(255),
    payment_sequential      INT,
    payment_type            VARCHAR(50),
    payment_installments    INT,
    payment_value           FLOAT
);

-- ── SUPPORTING TABLE: Reviews ────────────────────────────────
CREATE TABLE order_reviews (
    order_id        VARCHAR(255),
    review_score    INT,
    sentiment       VARCHAR(20)
);




USE ecommerce_db;

-- Drop if exists
DROP TABLE IF EXISTS fcr_master_risk_table;
DROP TABLE IF EXISTS fcr_velocity_features;
DROP TABLE IF EXISTS fcr_structuring_features;
DROP TABLE IF EXISTS fcr_behavioral_features;

-- Velocity features
CREATE TABLE fcr_velocity_features (
    customer_id              VARCHAR(255) PRIMARY KEY,
    total_orders             INT,
    avg_days_between_orders  FLOAT,
    total_spend              FLOAT,
    high_velocity_flag       INT,
    high_value_flag          INT,
    velocity_risk_score      FLOAT
);

-- Structuring features
CREATE TABLE fcr_structuring_features (
    customer_id              VARCHAR(255) PRIMARY KEY,
    total_transactions       INT,
    total_spend              FLOAT,
    avg_transaction_value    FLOAT,
    round_number_txns        INT,
    below_threshold_txns     INT,
    unusual_installment_txns INT,
    structuring_risk_score   FLOAT,
    structuring_flag         INT
);

-- Behavioral features
CREATE TABLE fcr_behavioral_features (
    customer_id              VARCHAR(255) PRIMARY KEY,
    total_orders             INT,
    late_night_orders        INT,
    weekend_high_value       INT,
    suspicious_reviews       INT,
    avg_payment_value        FLOAT,
    dominant_state           VARCHAR(10),
    behavioral_risk_score    FLOAT,
    behavioral_flag          INT
);

-- Master risk table
CREATE TABLE fcr_master_risk_table (
    customer_id              VARCHAR(255) PRIMARY KEY,
    total_orders             INT,
    total_spend              FLOAT,
    high_velocity_flag       INT,
    high_value_flag          INT,
    velocity_risk_score      FLOAT,
    structuring_flag         INT,
    structuring_risk_score   FLOAT,
    round_number_txns        INT,
    below_threshold_txns     INT,
    behavioral_flag          INT,
    behavioral_risk_score    FLOAT,
    late_night_orders        INT,
    suspicious_reviews       INT,
    dominant_state           VARCHAR(10),
    composite_risk_score     FLOAT,
    risk_tier                VARCHAR(20),
    total_flags_fired        INT,
    aml_alert                INT
);


--ALL TABLES AND NO. OF ROWS LOADED----------------------------------
SELECT 
    t.name AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.partitions p 
    ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)  -- heap or clustered index
GROUP BY t.name
ORDER BY t.name;