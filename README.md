# 🗄️ E-Commerce SQL Analytics — Query Library & Schema Design
THIS PROJECT IS THE ANALYTICS PART OF MY ![E-COMMERCE PIPELINE PROJECT](https://github.com/ANKITA-GARG01/ecommerce-analytics-pipeline.git) ALL DATA IS LOADED INTO TABLE USING PYTHON


<div align="center">

![SQL Server](https://img.shields.io/badge/SQL_Server-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-Advanced-CC2927?style=for-the-badge&logo=microsoft&logoColor=white)
![Status](https://img.shields.io/badge/Status-Complete-2ea44f?style=for-the-badge)

**3 SQL files. 11 tables. 16 queries. One complete analytical system.**

[Schema Design](#-schema-design) • [E-Commerce Queries](#-e-commerce-analysis-10-queries) • [FCR/AML Queries](#-financial-crime-risk-6-queries) • [How to Run](#-how-to-run)

</div>

---

## 📂 Files in This Folder

| File | Purpose | Contains |
|------|---------|---------|
| `Creating_Tables.sql` | Schema DDL | Creates all 11 tables — 7 e-commerce + 4 FCR/AML |
| `E-commerce_Analysis.sql` | Business Analytics | 10 queries answering real business questions |
| `Risk_Analysis.sql` | FCR/AML Engine | 6 queries for financial crime investigation |

---

## 🏗️ Schema Design

### `Creating_Tables.sql`

This file sets up the complete analytical database in two sections.

---

#### Section 1 — E-Commerce Star Schema (7 Tables)

```
                    ┌──────────────────────┐
                    │     fact_orders      │  ← 99,441 rows
                    │   (center of star)   │      Primary Key: order_id
                    └──────────┬───────────┘      FK → dim_customers
                               │
          ┌────────────────────┼─────────────────────┐
          ▼                    ▼                     ▼
  ┌───────────────┐   ┌────────────────┐   ┌───────────────┐
  │ dim_customers │   │  dim_products  │   │  dim_sellers  │
  │  96,096 rows  │   │  32,951 rows   │   │  3,095 rows   │
  │  PK:customer_id│  │  PK:product_id │   │  PK:seller_id │
  └───────────────┘   └────────────────┘   └───────────────┘
                               ▲                     ▲
                               │                     │
                    ┌──────────┴───────────┐
                    │   fact_order_items   │  ← 112,650 rows
                    │   (revenue table)    │      Composite PK:
                    │                      │      (order_id, order_item_id)
                    └──────────────────────┘      FK → dim_products
                                                  FK → dim_sellers

  + order_payments   (103,877 rows)  — payment method & value per order
  + order_reviews    (98,673 rows)   — review score + sentiment label
```

**Key Design Decisions:**

```sql
-- Composite Primary Key on fact_order_items
-- WHY: one order can contain multiple items
-- order_id alone would not be unique — we need both columns together
CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id)

-- Foreign Key enforcement
-- WHY: SQL Server rejects any order referencing a customer that doesn't exist
-- This catches data quality issues at load time, not query time
CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id)
```

**Safe Re-Run Pattern:**
```sql
-- Drop in REVERSE dependency order (child → parent)
-- If you drop dim_customers before fact_orders,
-- SQL Server throws an error because FK still references it
IF OBJECT_ID('fact_order_items', 'U') IS NOT NULL DROP TABLE fact_order_items;
IF OBJECT_ID('fact_orders',      'U') IS NOT NULL DROP TABLE fact_orders;
-- ... then dimensions
IF OBJECT_ID('dim_customers',    'U') IS NOT NULL DROP TABLE dim_customers;
```

---

#### Section 2 — FCR / AML Risk Tables (4 Tables)

```
  fcr_velocity_features       — transaction speed & high-value flags per customer
  fcr_structuring_features    — round numbers, below-threshold patterns per customer
  fcr_behavioral_features     — late-night orders, suspicious reviews per customer
        │         │         │
        └────┬────┘         │
             ▼              │
  fcr_master_risk_table  ←──┘
  (composite risk score + risk tier + AML alert per customer)
```

**Row counts verified with:**
```sql
SELECT t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;
```

---

## 📊 E-Commerce Analysis (10 Queries)

### `E-commerce_Analysis.sql`

Each query answers a specific business question. SQL concepts used are documented below.

---

### Query 1 — Revenue Breakdown Per Order
```
Business Question: What is the revenue contribution of each item and order?
SQL Concepts: Basic SELECT, GROUP BY, SUM aggregation
```
Two-level analysis: item-level (price, freight, revenue per row) then
order-level (total revenue rolled up by order_id).

---

### Query 2 — Revenue by Month
```
Business Question: Which months had the highest sales? Is there seasonality?
SQL Concepts: FORMAT() for date grouping, JOIN, GROUP BY, ORDER BY
Key Function: FORMAT(timestamp, 'yyyy-MM') → groups dates into year-month buckets
```
Joins `fact_order_items` to `fact_orders` to get purchase timestamps,
then aggregates revenue and order count per month.

---

### Query 3 — Running Total Revenue ⭐ Window Function
```
Business Question: How is our cumulative revenue growing over time?
SQL Concepts: Window function — SUM() OVER (ORDER BY ...)
```
```sql
SUM(SUM(f.revenue)) OVER (
    ORDER BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
)
```
The inner `SUM` aggregates monthly. The outer `SUM OVER` accumulates
across months in date order — producing a running total without a self-join.

---

### Query 4 — Top 10 Product Categories by Revenue
```
Business Question: Where does most revenue come from?
SQL Concepts: TOP N, JOIN, GROUP BY, AVG, ORDER BY DESC
```
Joins items to products to get category names,
ranks by total revenue and shows avg price per category.

---

### Query 5 — Late Delivery Rate by Seller State
```
Business Question: Which seller locations cause the most delays?
SQL Concepts: CASE WHEN inside SUM, percentage calculation, IS NOT NULL filter
```
```sql
SUM(CASE WHEN order_delivered_customer_date
              > order_estimated_delivery_date THEN 1 ELSE 0 END)
```
Conditional aggregation counts late deliveries per state.
Only includes rows where delivery actually happened (`IS NOT NULL`).

---

### Query 6 — Customer Review Score by Category
```
Business Question: Which product categories make customers happiest?
SQL Concepts: AVG with CAST, multi-table JOIN, GROUP BY, ORDER BY
```
Three-table join: items → products → reviews.
`CAST(review_score AS FLOAT)` prevents integer division from rounding averages.

---

### Query 7 — Payment Method Analysis
```
Business Question: How do customers prefer to pay? Do installments affect order value?
SQL Concepts: COUNT DISTINCT, SUM, AVG, GROUP BY on categorical column
```
Breaks down transactions by payment type showing total value,
average payment, and average installment count per method.

---

### Query 8 — Customer Geography — Top States
```
Business Question: Where are our highest-value customers located?
SQL Concepts: TOP N, 3-table JOIN, GROUP BY on geography, ORDER BY
```
Chains items → orders → customers to roll revenue up to state level.
Reveals geographic concentration of purchasing power.

---

### Query 9 — Seller Performance Scorecard
```
Business Question: Who are our best and worst performing sellers?
SQL Concepts: 4-table JOIN, CASE WHEN, percentage calculation, GROUP BY
```
Combines revenue, review score, and late delivery rate per seller
into a single performance view. Uses same conditional aggregation
pattern as Query 5 for the late delivery rate.

---

### Query 10 — Day of Week Analysis
```
Business Question: Which days do customers shop most?
SQL Concepts: DATENAME(), DATEPART(), GROUP BY multiple columns, ORDER BY numeric sort
```
`DATENAME(WEEKDAY, ...)` returns readable day name (Monday, Tuesday...).
`DATEPART(WEEKDAY, ...)` returns sort number (1–7) to order days correctly
instead of alphabetically.

---

## 🏦 Financial Crime Risk (6 Queries)

### `Risk_Analysis.sql`

Investigation-grade queries operating on the FCR scoring tables
populated by `fcr_transform.py`. Each query mirrors a real compliance workflow.

---

### FCR Query 1 — Risk Tier Summary Dashboard
```
Compliance Question: How is our customer base distributed across risk levels?
SQL Concepts: GROUP BY, AVG, SUM, Window function for % share
```
```sql
ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
```
`SUM(COUNT(*)) OVER ()` calculates the grand total of all customers
across all tiers — no subquery needed. Each tier's count is divided
by this grand total for percentage share.

---

### FCR Query 2 — Top 20 Highest Risk Customers
```
Compliance Question: Which specific customers need immediate investigation?
SQL Concepts: TOP N, WHERE IN, ORDER BY composite score DESC
```
Filters to CRITICAL and HIGH tiers only.
Shows all individual flags (velocity, structuring, behavioral, AML alert)
side by side for each customer — a compliance officer's investigation view.

---

### FCR Query 3 — AML Alert Investigation
```
Compliance Question: What are flagged customers actually buying?
SQL Concepts: 5-table JOIN, WHERE on flag column, GROUP BY multiple columns
```
Connects the risk table back to the original transaction data.
Answers: "Yes this customer is flagged — but what did they spend money on?"
Critical for determining whether suspicious patterns are domain-specific
(e.g., only flagged customers buying electronics at 3am).

---

### FCR Query 4 — Structuring Pattern Deep-Dive
```
Compliance Question: Who is deliberately breaking up transactions to avoid detection?
SQL Concepts: JOIN between risk tables, WHERE on flag, ORDER BY risk score
```
Joins master risk table to the structuring-specific feature table.
Shows exact counts of round-number transactions, below-threshold transactions,
and unusual installment patterns per flagged customer.

---

### FCR Query 5 — Geographic Risk Heatmap
```
Compliance Question: Which states have the highest concentration of suspicious activity?
SQL Concepts: GROUP BY state, CASE WHEN for tier breakdown, percentage calculation
```
Aggregates AML alerts and risk scores up to state level.
Breaks down CRITICAL and HIGH tier counts separately.
Produces data for a geographic heat map in Power BI.

---

### FCR Query 6 — Monthly AML Alert Trend
```
Compliance Question: Is suspicious activity increasing or decreasing over time?
SQL Concepts: COUNT DISTINCT with CASE WHEN, percentage over time, SUM with CASE
```
```sql
COUNT(DISTINCT CASE WHEN f.aml_alert = 1 THEN o.order_id END) AS flagged_orders
```
Counts only flagged order IDs using conditional COUNT DISTINCT.
Also calculates total flagged transaction value per month —
showing both volume and monetary exposure of suspicious activity over time.

---

## 📋 SQL Concepts Reference

| Concept | Queries Used In | What It Does |
|---------|----------------|-------------|
| `SUM() OVER (ORDER BY ...)` | Q3 | Running total without self-join |
| `SUM(COUNT()) OVER ()` | Q1, Q7, FCR-1 | Grand total for percentage share |
| `COUNT(DISTINCT CASE WHEN...)` | FCR-6 | Conditional distinct count |
| `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` | Q5, Q9, FCR-5 | Conditional aggregation |
| `FORMAT(date, 'yyyy-MM')` | Q2, Q3 | Group timestamps by month |
| `DATENAME / DATEPART` | Q10 | Extract readable & sortable date parts |
| `CAST(col AS FLOAT)` | Q6, FCR-2 | Prevent integer division rounding |
| `TOP N` | Q4, Q8, FCR-2 | Limit result set to N rows |
| `IS NOT NULL` filter | Q5 | Exclude incomplete/expected null rows |
| Composite FK constraint | Schema | Enforce referential integrity |
| Safe DROP with `OBJECT_ID` | Schema | Idempotent schema re-creation |

---

## ⚙️ How to Run

### Prerequisites
```
MS SQL Server Express (any recent version)
SSMS (SQL Server Management Studio)
ecommerce_db database created
Data loaded via pipeline.py + fcr_transform.py
```

### Step 1 — Create all tables
```
Open SSMS → Connect to localhost\SQLEXPRESS
Open Creating_Tables.sql → Execute (F5)
Expected: 11 tables created, row count query shows 0s
```

### Step 2 — Load data
```
Run Python pipeline:
  python scripts/pipeline.py        ← loads 7 e-commerce tables
  python scripts/fcr_transform.py   ← loads 4 FCR tables
```

### Step 3 — Run analytics
```
Open E-commerce_Analysis.sql in SSMS
Run each query individually (highlight → F5)
Review results and note business insights

Open Risk_Analysis.sql in SSMS
Run each FCR query individually
Review risk tier distribution and flagged customers
```

### Step 4 — Verify all data loaded
```sql
-- Quick count check (included at bottom of Creating_Tables.sql)
SELECT t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;
```

**Expected counts:**

| Table | Expected Rows |
|-------|--------------|
| dim_customers | 96,096 |
| dim_products | 32,951 |
| dim_sellers | 3,095 |
| fact_orders | 99,441 |
| fact_order_items | 112,650 |
| order_payments | 103,877 |
| order_reviews | 98,673 |
| fcr_master_risk_table | 96,096 |
| fcr_velocity_features | 96,096 |
| fcr_structuring_features | 96,096 |
| fcr_behavioral_features | 96,096 |

---

## 🔗 Related Files

| Component | Location |
|-----------|---------|
| Python ETL Pipeline | `scripts/pipeline.py` |
| FCR Scoring Engine | `scripts/fcr_transform.py` |
| Power BI Dashboard | `dashboard/` |
| Full Project README | `README.md` |

---

## 👩‍💻 Author

**Ankita Garg** — Data Analyst · Data Engineer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=for-the-badge&logo=linkedin)](https://linkedin.com/in/ankita-garg-a80817212)
[![GitHub](https://img.shields.io/badge/GitHub-ANKITA--GARG01-181717?style=for-the-badge&logo=github)](https://github.com/ANKITA-GARG01)
