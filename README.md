# Data Warehouse and Analytics Project

> A production-style SQL Server data warehouse built on the **Medallion Architecture** (Bronze → Silver → Gold), consolidating sales data from ERP and CRM source systems into a clean, analytical star schema ready for BI reporting and strategic decision-making.

---

## 🏗️ Data Architecture

The project follows the **Medallion Architecture** with three progressive data layers:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DataWarehouse (SQL Server)                      │
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌────────────────────────┐    │
│  │    BRONZE    │    │    SILVER    │    │         GOLD           │    │
│  │              │    │              │    │                        │    │
│  │  Raw ingest  │───►│  Cleansed &  │───►│  Star Schema           │    │
│  │  1-to-1 with │    │  standardised│    │  dim_customers         │    │
│  │  source CSVs │    │  conformed   │    │  dim_products          │    │
│  │              │    │  typed data  │    │  fact_sales            │    │
│  └──────────────┘    └──────────────┘    │                        │    │
│                                          └────────────────────────┘    │
│  Source: ERP (CSV)                                                      │
│  Source: CRM (CSV)                                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

| Layer     | Schema   | Purpose                                                     |
| --------- | -------- | ----------------------------------------------------------- |
| 🥉 Bronze | `bronze` | Raw ingestion — 1-to-1 with source files, no transformation |
| 🥈 Silver | `silver` | Cleansed, deduplicated, type-cast, standardised             |
| 🥇 Gold   | `gold`   | Business-ready star schema consumed by BI tools and reports |

---

## 📖 Project Overview

This project demonstrates an end-to-end enterprise data warehousing solution:

1. **Data Architecture** — Modern medallion design on SQL Server with clearly separated Bronze, Silver, and Gold schemas.
2. **ETL Pipelines** — Stored procedures perform full-refresh loads at each layer: `BULK INSERT` at Bronze, transformation logic at Silver, and join/surrogate-key generation at Gold.
3. **Data Modelling** — Star schema with a central `fact_sales` view and conformed dimensions (`dim_customers`, `dim_products`), optimised for analytical query patterns.
4. **Data Quality** — Explicit cleansing rules, deduplication, referential integrity checks, and a test suite in `tests/`.
5. **Analytics & Reporting** — Gold schema supports customer segmentation, product performance analysis, and time-series sales trend reporting.

> 🎯 This repository is designed as a **portfolio project** showcasing skills in SQL Development, Data Engineering, ETL Pipeline Design, Data Modelling, and Analytics.

---

## 🚀 Project Requirements

### Data Engineering Objective

Build a modern data warehouse using SQL Server to consolidate sales data from two source systems, enabling analytical reporting and informed decision-making.

**Specifications:**

- **Sources:** ERP and CRM data delivered as CSV flat files.
- **Quality:** Cleanse and resolve all data quality issues prior to the analytical layer.
- **Integration:** Combine both sources into a single, conformed data model.
- **Scope:** Full-refresh loads; historisation is out of scope for this version.
- **Documentation:** Full column-level lineage, data catalog, and operational runbook provided.

### Analytics & Reporting Objective

Develop SQL-based analytics to deliver actionable insights across three domains:

| Domain                 | Key Questions Answered                                             |
| ---------------------- | ------------------------------------------------------------------ |
| 📋 Customer Behaviour  | Who are our best customers? How do demographics affect purchasing? |
| 📦 Product Performance | Which products and categories drive the most revenue and margin?   |
| 📈 Sales Trends        | How is revenue trending month-over-month and year-over-year?       |

For full details, see [docs/requirements.md](docs/requirements.md).

---

## 🛠️ Tech Stack

| Component          | Technology                             |
| ------------------ | -------------------------------------- |
| Database Engine    | SQL Server 2019+ (Developer / Express) |
| Query Language     | T-SQL                                  |
| ETL Mechanism      | Stored Procedures + `BULK INSERT`      |
| Client Tooling     | SQL Server Management Studio (SSMS)    |
| Source Data Format | CSV flat files                         |
| Diagramming        | Draw.io                                |
| Version Control    | Git / GitHub                           |

---

## 📂 Repository Structure

```
sql-warehouse-project/
│
├── datasets/                           # Source CSV files (ERP and CRM data)
│   ├── source_erp/                     # Raw ERP exports (3 files)
│   └── source_crm/                     # Raw CRM exports (3 files)
│
├── docs/                               # Project documentation
│   ├── requirements.md                 # Business requirements, KPIs, analytical use cases
│   ├── data_catalog.md                 # Column-level catalog for all three layers
│   ├── naming-conventions.md           # Naming standards for all database objects
│   ├── source_to_target_mapping.md     # Full column lineage: CSV → Bronze → Silver → Gold
│   └── runbook.md                      # Deployment, load, re-run, and troubleshooting guide
│
├── scripts/
│   ├── 00_run_end_to_end.sql          # One-click SQLCMD runner for full build + checks
│   ├── 01_run_incremental_rerun.sql   # One-click SQLCMD runner for non-destructive refresh
│   ├── init_database.sql               # Creates DataWarehouse DB and bronze/silver/gold schemas
│   ├── init_database_safe.sql          # Non-destructive DB/schema bootstrap
│   ├── bronze/
│   │   ├── ddl_bronze.sql              # DDL for all 6 Bronze tables
│   │   └── proc_load_bronze.sql        # Stored procedures: BULK INSERT from CSV
│   ├── silver/
│   │   ├── ddl_silver.sql              # DDL for all 6 Silver tables
│   │   └── proc_load_silver.sql        # Stored procedures: cleanse and load from Bronze
│   ├── gold/
│   │   ├── ddl_gold.sql                # Gold star-schema views
│   │   └── 02_proc_load_gold.sql       # Compatibility procedures for Gold execution
│   └── etl/
│       ├── 01_ddl_etl_log.sql          # ETL audit log table DDL
│       └── 02_proc_run_full_pipeline.sql # Full pipeline orchestrator (Bronze -> Silver)
│
├── tests/                              # Data quality and reconciliation scripts
│   ├── quality_checks_bronze.sql       # Bronze ingestion quality checks
│   ├── quality_checks_silver.sql       # Silver quality checks
│   └── quality_checks_gold.sql         # Gold integrity checks
│
├── README.md
└── LICENSE
```

---

## ⚙️ Getting Started

### Prerequisites

- SQL Server 2019 or later (Developer or Express Edition)
- SQL Server Management Studio (SSMS) 18+
- Git

### Step-by-Step Setup

**1. Clone the repository**

```bash
git clone https://github.com/<your-username>/sql-warehouse-project.git
cd sql-warehouse-project
```

**2. Initialise the database**

Open SSMS, connect to your SQL Server instance, and execute:

```
scripts/init_database.sql
```

> ⚠️ **Warning:** This script drops and recreates the `DataWarehouse` database. Never run it against an environment with data you need to keep. See [docs/runbook.md](docs/runbook.md) for safe procedures.

Safe alternative (non-destructive):

```
scripts/init_database_safe.sql
```

**3. Place source CSV files**

```
datasets/source_erp/   ← CUST_AZ12.csv, LOC_A101.csv, PX_CAT_G1V2.csv
datasets/source_crm/   ← cust_info.csv, prd_info.csv, sales_details.csv
```

**4. Load Bronze → Silver → Gold**

Fastest option (recommended):

```sql
-- In SSMS, open scripts/00_run_end_to_end.sql
-- Enable SQLCMD Mode (Query -> SQLCMD Mode), then run.
```

Non-destructive refresh option:

```sql
-- In SSMS, open scripts/01_run_incremental_rerun.sql
-- Enable SQLCMD Mode (Query -> SQLCMD Mode), then run.
```

Manual option:

```sql
-- Step 1: Create and load Bronze
scripts/bronze/ddl_bronze.sql
scripts/bronze/proc_load_bronze.sql
EXEC bronze.usp_bronze_load_all;

-- Step 2: Create and load Silver
scripts/silver/ddl_silver.sql
scripts/silver/proc_load_silver.sql
EXEC silver.usp_silver_load_all;

-- Step 3: Create Gold objects
scripts/gold/ddl_gold.sql
```

For the complete execution guide, including re-run procedures and troubleshooting, see [docs/runbook.md](docs/runbook.md).

### Operational Monitoring

- Table-level load telemetry is stored in `etl.load_log`.
- Pipeline-level run status is stored in `etl.pipeline_run_log`.
- Latest status views:
  - `etl.vw_latest_load_summary`
  - `etl.vw_latest_pipeline_run`

### Demo Validation Checklist

Use this checklist for portfolio demos and stakeholder walkthroughs.

- Database exists with required schemas: bronze, silver, gold, etl
- Bronze load completes with non-zero row counts in all 6 tables
- Silver load completes with no failed entries in `etl.load_log`
- Gold views return data: `gold.dim_customers`, `gold.dim_products`, `gold.fact_sales`
- Quality scripts run with no critical failures:
  - `tests/quality_checks_bronze.sql`
  - `tests/quality_checks_silver.sql`
  - `tests/quality_checks_gold.sql`
- Pipeline run status appears in `etl.pipeline_run_log` with `Completed`

---

## ✅ Delivery Highlights

- Medallion architecture implemented with clear schema separation
- Full-refresh ETL with structured error handling and audit logging
- One-click SQLCMD runner for full rebuild and non-destructive refresh
- Column-level lineage and catalog documentation aligned to code
- Multi-layer data quality checks for ingestion and analytics integrity
- Phase-based commit history suitable for technical portfolio review

---

## 🚢 v1.0 Release Readiness Checklist

Use this checklist before tagging a release or presenting the project to stakeholders.

- `scripts/00_run_end_to_end.sql` executes successfully in SQLCMD Mode
- `scripts/01_run_incremental_rerun.sql` executes successfully in SQLCMD Mode
- `tests/quality_checks_bronze.sql` returns no critical failures
- `tests/quality_checks_silver.sql` returns no critical failures
- `tests/quality_checks_gold.sql` returns no referential integrity failures
- `etl.vw_latest_pipeline_run` shows latest status as `Completed`
- `etl.vw_latest_load_summary` shows no table with latest status `Failed`
- README, runbook, data catalog, and source-to-target mapping are synchronized
- Commit history includes phase-based checkpoints with clear messages

---

## 📊 Data Model

The Gold layer implements a **star schema** optimised for analytical queries:

```
┌──────────────────┐    ┌────────────────────┐    ┌─────────────────────┐
│  dim_customers   │    │    fact_sales      │    │    dim_products     │
│ customer_key(PK) ├────┤  order_number      ├────┤  product_key (PK)  │
│  customer_id     │    │  customer_key(FK)  │    │  product_id         │
│  customer_number │    │  product_key(FK)   │    │  product_number     │
│  first_name      │    │  order_date        │    │  product_name       │
│  last_name       │    │  shipping_date     │    │  category           │
│  country         │    │  due_date          │    │  subcategory        │
│  marital_status  │    │  sales_amount      │    │  maintenance        │
│  gender          │    │  quantity          │    │  cost               │
│  birthdate       │    │  price             │    │  product_line       │
└──────────────────┘    └────────────────────┘    │  start_date         │
                                                  └─────────────────────┘
```

---

## 📈 Analytical Coverage

The Gold layer is designed to answer the following business questions directly:

**Customer Analytics**

- Segment customers by country, gender, age bracket, and marital status
- Identify high-value customers by total revenue and order frequency
- Compare new vs. returning customer behaviour

**Product Performance**

- Rank products and categories by total revenue and units sold
- Analyse product cost vs. selling price for margin insights
- Compare performance across product lines (Road, Mountain, Touring)

**Sales Trends**

- Monthly and annual revenue trend analysis
- Year-over-year growth percentages
- Average order value (AOV) and order volume by period

---

## 📄 Documentation

| Document                                                             | Description                                                            |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [docs/requirements.md](docs/requirements.md)                         | Business context, KPIs, analytical use cases, technical constraints    |
| [docs/data_catalog.md](docs/data_catalog.md)                         | Column-level definitions for all Bronze, Silver, and Gold objects      |
| [docs/naming-conventions.md](docs/naming-conventions.md)             | Schema, table, column, procedure, and index naming rules with examples |
| [docs/source_to_target_mapping.md](docs/source_to_target_mapping.md) | Full column lineage from source CSV through all three layers           |
| [docs/runbook.md](docs/runbook.md)                                   | Deployment, full load, re-run, troubleshooting, and maintenance guide  |

---

## 🔄 Project Status

| Phase | Description                                   | Status      |
| ----- | --------------------------------------------- | ----------- |
| 1     | Documentation & architecture design           | ✅ Complete |
| 2     | Database initialisation (`init_database.sql`) | ✅ Complete |
| 3     | Bronze layer — DDL + load procedures          | ✅ Complete |
| 4     | Silver layer — cleansing procedures           | ✅ Complete |
| 5     | Gold layer — star-schema scripts              | ✅ Complete |
| 6     | Data quality test scripts                     | ✅ Complete |

---

## 🛡️ License

This project is licensed under the [MIT License](LICENSE). You are free to use, modify, and share it with proper attribution.
