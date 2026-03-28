# Requirements

This document defines the business requirements, technical requirements, and analytical use cases for the SQL Server Medallion Data Warehouse project.

**Version:** 1.0  
**Status:** Approved  
**Last Updated:** 2026-03-28

---

## Executive Summary

This project consolidates sales, customer, and product data from two independently operated source systems — an ERP platform and a CRM platform — into a single SQL Server data warehouse. The warehouse follows a three-layer medallion architecture (Bronze → Silver → Gold) to progressively improve data quality and deliver a star-schema analytical layer optimised for BI reporting. The primary business driver is to eliminate manual reconciliation of cross-system reports and provide stakeholders with a single authoritative view of customer behaviour and sales performance.

---

## 1. Business Context

The organisation operates two independent source systems: an ERP platform and a CRM platform. Both systems capture overlapping but non-identical views of customers, products, and sales activity. The goal of this warehouse is to:

- Unify data from both systems into a single, trusted analytical layer.
- Provide a consistent, cleansed view of customers and products.
- Enable time-series analysis of sales performance.
- Support self-service BI queries against a well-documented star schema.

---

## 2. Key Performance Indicators (KPIs)

The Gold layer is designed to directly support calculation of the following business KPIs:

| KPI                         | Definition                                                               | Primary Use Case        |
| --------------------------- | ------------------------------------------------------------------------ | ----------------------- |
| Total Revenue               | `SUM(sales_amount)` across all order lines                               | Executive reporting     |
| Monthly Revenue             | `SUM(sales_amount)` grouped by calendar month and year                   | Sales trend analysis    |
| Year-over-Year Growth (%)   | `(Current Year Revenue - Prior Year Revenue) / Prior Year Revenue × 100` | Strategic planning      |
| Average Order Value (AOV)   | `SUM(sales_amount) / COUNT(DISTINCT order_number)`                       | Revenue optimisation    |
| Total Orders                | `COUNT(DISTINCT order_number)`                                           | Volume tracking         |
| Units Sold                  | `SUM(quantity)`                                                          | Inventory & demand      |
| Gross Margin                | `SUM(sales_amount - (quantity * product_cost))`                          | Profitability analysis  |
| Revenue per Customer        | `SUM(sales_amount) / COUNT(DISTINCT customer_key)`                       | Customer value analysis |
| Top Products by Revenue     | `SUM(sales_amount)` per `product_key`, ranked descending                 | Product performance     |
| Customer Segmentation Count | `COUNT(customer_key)` grouped by country, gender, or marital status      | Customer analytics      |

---

## 3. Layer Scope Summary

| Layer  | Schema   | Objects               | Responsibility                                              |
| ------ | -------- | --------------------- | ----------------------------------------------------------- |
| Bronze | `bronze` | 8 raw tables          | Ingest source CSVs without transformation; audit timestamps |
| Silver | `silver` | 8 cleansed tables     | Trim, cast, standardise, deduplicate; add DWH audit columns |
| Gold   | `gold`   | 3 dimensions + 1 fact | Join Silver sources; generate surrogate keys; star schema   |

---

## 4. Analytical Use Cases

The following use cases drive the scope of the Gold layer.

### 4.1 Customer Analytics

| Use Case                    | Description                                                        |
| --------------------------- | ------------------------------------------------------------------ |
| Customer segmentation       | Group customers by country, age bracket, gender, or marital status |
| Purchase frequency          | Count of orders per customer within a time window                  |
| Revenue by customer         | Total and average sales amount aggregated per customer             |
| New vs. returning customers | First-order date compared to subsequent orders                     |

### 4.2 Product Performance

| Use Case                 | Description                                                    |
| ------------------------ | -------------------------------------------------------------- |
| Revenue by category      | Total sales amount grouped by product category and subcategory |
| Top SKUs                 | Ranked list of products by total revenue or units sold         |
| Product cost vs. revenue | Margin analysis using unit cost and unit price                 |
| Product line performance | Revenue comparison across product lines                        |

### 4.3 Sales Trends

| Use Case                  | Description                                          |
| ------------------------- | ---------------------------------------------------- |
| Monthly revenue trend     | Total sales amount by calendar month                 |
| Year-over-year growth     | Percentage change in revenue vs. prior year          |
| Average order value (AOV) | Total revenue divided by number of orders per period |
| Order volume trend        | Count of orders by week, month, or quarter           |

---

## 5. Data Engineering Requirements

### 5.1 Source Systems

| System | Format | Delivery Method                     | Load Frequency              |
| ------ | ------ | ----------------------------------- | --------------------------- |
| ERP    | CSV    | File drop to `datasets/source_erp/` | Full refresh per load cycle |
| CRM    | CSV    | File drop to `datasets/source_crm/` | Full refresh per load cycle |

**Assumption:** Source files are encoded in UTF-8. File names are stable across load cycles (same name, new content).

### 5.2 Bronze Layer

- All source tables are loaded as-is with no transformation.
- Column names in Bronze tables use the same names as the source CSV header row, preserved in snake_case.
- Data types are permissive (`NVARCHAR`) where source type is uncertain; type-casting is deferred to Silver.
- Each Bronze table includes an `etl_load_ts` audit column populated with `GETDATE()` at load time.
- Load mechanism: `BULK INSERT` called from a stored procedure per source table.
- Full truncate-and-reload on each execution (no incremental delta in Bronze).

### 5.3 Silver Layer

- Reads exclusively from Bronze tables; never touches source files directly.
- Applies the following cleansing rules per table (detailed in [source_to_target_mapping.md](source_to_target_mapping.md)):
  - Trim leading/trailing whitespace from string columns.
  - Replace empty strings with `NULL`.
  - Standardise boolean-like flags to `'Y'` / `'N'`.
  - Standardise gender values to `'Male'` / `'Female'` / `'Unknown'`.
  - Cast date strings to `DATE` type with explicit format handling.
  - Remove duplicate rows based on defined business key columns.
- Silver tables are full-truncate-and-reload; no SCD logic is required at this stage.
- Each Silver table includes `dwh_created_at` and `dwh_updated_at` audit columns.

### 5.4 Gold Layer

- Reads exclusively from Silver tables.
- Implements a star schema with a single fact table (`fact_sales`) and dimension tables.
- Dimensions use integer surrogate keys (`_key` suffix). Source system natural keys are retained as `_id` columns for traceability.
- Date dimension (`dim_date`) is pre-populated to span 2010–2030 and is not sourced from Silver.
- Gold objects are implemented as views over Silver in the initial delivery; may be materialised to tables in a later phase.
- `fact_sales` must not contain `NULL` foreign keys. Rows that cannot resolve a dimension key are rejected and logged in an audit table (to be implemented in Phase 5).

### 5.5 Historization

- **Out of scope for this version.** The warehouse captures only the most recent state of all entities.
- SCD Type 1 update semantics: existing rows are overwritten on reload.
- SCD Type 2 / bi-temporal tracking is identified as a future enhancement.

---

## 6. Data Quality Requirements

| Rule                      | Applies To                 | Description                                                             |
| ------------------------- | -------------------------- | ----------------------------------------------------------------------- |
| No orphan fact rows       | `fact_sales`               | Every sales row must resolve to a valid customer, product, and date     |
| No duplicate natural keys | Silver dimensions          | `customer_id` and `product_id` must be unique within the cleansed layer |
| Date range validity       | All date columns           | Order dates must fall between 2000-01-01 and the current load date      |
| Non-negative amounts      | `sales_amount`, `quantity` | Negative values are flagged for investigation, not silently dropped     |
| Referential integrity     | Gold FK columns            | Verified by test scripts in `tests/`                                    |

---

## 7. Technical Constraints

| Constraint               | Detail                                                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Database engine          | SQL Server 2019 or later                                                                                                                               |
| Edition                  | Developer or Standard edition minimum (Express is acceptable for development)                                                                          |
| Collation                | Default server collation; string comparisons are case-insensitive                                                                                      |
| Compatibility level      | 150 (SQL Server 2019)                                                                                                                                  |
| Schema isolation         | Bronze, Silver, and Gold each occupy a separate SQL Server schema                                                                                      |
| No external dependencies | No SSIS, ADF, or linked servers; all ETL is T-SQL stored procedures                                                                                    |
| Security                 | ETL procedures run under a dedicated service account with `db_datawriter` and `db_datareader` permissions; no direct table grants to application users |

---

## 8. Out of Scope

- Real-time or near-real-time data ingestion
- Row-level security
- Reporting layer (Power BI, SSRS) — downstream consumers query the Gold schema directly
- Data masking or PII anonymisation (assumed to be handled upstream)
- Partitioning or columnstore indexes (future performance phase)
