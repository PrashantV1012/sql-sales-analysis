# Retail Sales SQL Analysis

A SQL-based business analysis of a two-year retail sales dataset (2024–2025), covering revenue trends, product and category performance, customer segmentation, and churn-risk identification.


## Schema

```
customers(customer_id, customer_name, region, segment, signup_date)
products(product_id, product_name, category, unit_price, unit_cost)
orders(order_id, customer_id, order_date, ship_date)
order_items(order_item_id, order_id, product_id, quantity, discount)
```
Revenue for a line item = `quantity * unit_price * (1 - discount)`.

## Files

| File | Purpose |
|---|---|
| `sql/schema.sql` | Table definitions and indexes |
| `sql/queries.sql` | 10 business queries: joins, CTEs, window functions, subqueries, CASE, aggregations |
| `data/*.csv` | Source data for each table |
| `generate_data.py` | Script that generated the synthetic dataset (for transparency/reproducibility) |
| `sales.db` | SQLite database loaded from the CSVs |

## Key Findings

- **Furniture and Electronics drive the business.** Furniture generated the highest revenue, with Electronics close behind (see table below); together they account for the large majority of total revenue, while Office Supplies is the smallest category.
- **Profit margins are consistent across categories (30–32%)**, so category mix has limited effect on overall margin — the bigger profit lever is category revenue, not category margin.
- **Revenue is seasonal:** October–December ("Holiday Season" in the query) consistently outperforms the rest of the year, matching the seasonal weighting built into the dataset.
- **Customer value is concentrated but not extreme:** the top 10 customers each generated roughly 6–8 lakh in lifetime revenue (currency unit synthetic), and a "High Value" tier (47 of 150 customers, ≥450,000 spent) accounts for roughly 45% of total revenue — a useful group to prioritize for retention.
- **8 customers have not ordered in the trailing 90 days** of the dataset — a churn-risk list a retention team could act on directly.
- **Discounting doesn't clearly grow basket size:** average quantity per line item is nearly flat (3.49 vs 3.50 vs 3.62 units) across no/low/high discount bands, suggesting discounts here are not driving materially larger orders.

### Query results (actual output)

**Revenue & profit by category**
| Category | Units Sold | Revenue | Profit | Margin |
|---|---|---|---|---|
| Furniture | 2,966 | 26,857,024 | 8,206,347 | 30.56% |
| Electronics | 3,012 | 24,139,431 | 7,649,233 | 31.69% |
| Home & Kitchen | 2,774 | 5,373,166 | 1,702,868 | 31.69% |
| Office Supplies | 2,815 | 2,032,769 | 650,958 | 32.02% |

**Customer spend tiers**
| Tier | Customers | Avg Spend | Tier Revenue |
|---|---|---|---|
| High Value (≥450,000) | 47 | 552,654 | 25,974,722 |
| Mid Value (275,000–449,999) | 66 | 367,593 | 24,261,158 |
| Low Value (<275,000) | 37 | 220,716 | 8,166,510 |

**Revenue by region**
| Region | Orders | Revenue | Avg Order Value |
|---|---|---|---|
| Central | 493 | 13,998,238 | 28,394 |
| North | 529 | 13,651,905 | 25,807 |
| South | 476 | 12,487,778 | 26,235 |
| West | 392 | 10,331,555 | 26,356 |
| East | 310 | 7,932,915 | 25,590 |

*(Currency unit is illustrative/synthetic — replace with ₹, $, etc. to match your narrative, or restate as an index if you'd rather not quote absolute revenue from synthetic data.)*

## How to reproduce

```bash
python3 generate_data.py                 # regenerates data/*.csv
python3 -c "
import sqlite3, pandas as pd
conn = sqlite3.connect('sales.db')
conn.executescript(open('sql/schema.sql').read())
for t in ['customers','products','orders','order_items']:
    pd.read_csv(f'data/{t}.csv').to_sql(t, conn, if_exists='append', index=False)
conn.commit()
"
# then run any query in sql/queries.sql against sales.db
```

## Skills demonstrated
JOINs (inner joins across 4 tables) · CTEs (`WITH`) · window functions (`RANK`, `ROW_NUMBER`, `LAG`, running totals with `SUM() OVER`) · correlated and non-correlated subqueries · `CASE` bucketing · `GROUP BY`/aggregation · KPI calculation (revenue, profit margin, AOV, churn-risk).
