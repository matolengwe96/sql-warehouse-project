# Runbook

**Version:** 1.0  
**Status:** Approved  
**Last Updated:** 2026-03-28  
**Database:** `DataWarehouse` on SQL Server 2019+

This runbook covers every operational procedure for the `DataWarehouse` SQL Server project: initial environment setup, full data loads, re-loads, layer-by-layer procedures, troubleshooting, and maintenance tasks.

**Audience:** Data engineers, DBAs, and analysts responsible for running or maintaining the warehouse pipeline.

---

## ⚡ Quick Execution Reference

For experienced operators who know the environment is already configured:

```sql
-- Full load from scratch (run in order):
-- 1. scripts/init_database.sql            ← ONE-TIME ONLY — destroys existing DB
-- 2. scripts/etl/01_ddl_etl_log.sql
-- 3. scripts/bronze/ddl_bronze.sql
-- 4. scripts/bronze/proc_load_bronze.sql
EXEC bronze.usp_bronze_load_all;
-- 5. scripts/silver/ddl_silver.sql
-- 6. scripts/silver/proc_load_silver.sql
EXEC silver.usp_silver_load_all;
-- 7. scripts/gold/ddl_gold.sql
-- Done. Query gold.dim_customers, gold.dim_products, gold.fact_sales.

-- Re-run existing load (no DDL changes):
EXEC bronze.usp_bronze_load_all;
EXEC silver.usp_silver_load_all;
-- Gold views refresh automatically on query.

-- Or run one-click non-destructive refresh:
-- scripts/01_run_incremental_rerun.sql (SQLCMD Mode)
```

> ⚠️ **Never re-run `init_database.sql` as part of a normal reload.** It is a destructive rebuild script.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Initial Environment Setup](#2-initial-environment-setup)
3. [One-Click End-to-End Run](#3-one-click-end-to-end-run)
4. [Repository Layout and Execution Order](#4-repository-layout-and-execution-order)
5. [Initial Full Load](#5-initial-full-load)
6. [Re-running a Full Load](#6-re-running-a-full-load)
7. [Layer-by-Layer Procedures](#7-layer-by-layer-procedures)
8. [Data Quality Checks](#8-data-quality-checks)
9. [Troubleshooting](#9-troubleshooting)
10. [Maintenance Tasks](#10-maintenance-tasks)
11. [Environment-specific Notes](#11-environment-specific-notes)
12. [Failure and Recovery Decision Tree](#12-failure-and-recovery-decision-tree)
13. [Related Documents](#13-related-documents)

---

## 1. Prerequisites

### Software

| Requirement | Version            | Notes                                   |
| ----------- | ------------------ | --------------------------------------- |
| SQL Server  | 2019 or later      | Developer, Standard, or Express edition |
| SSMS        | 18 or later        | Used to run all scripts                 |
| Git         | Any recent version | For repository management               |

### SQL Server Configuration

Before running any scripts, confirm the following on the target SQL Server instance:

1. **TCP/IP is enabled** (SQL Server Configuration Manager → SQL Server Network Configuration → Protocols).
2. **SQL Server Agent** is running (required only if scheduling jobs in a later phase; not needed for manual runs).
3. **`sa` or a sysadmin account** is available for initial database creation. After setup, a least-privilege service account should be used (see [Section 11](#11-environment-specific-notes)).
4. **File system access**: The SQL Server service account must have `READ` permission on the folder where CSV files are stored (for `BULK INSERT`). See [Section 2.3](#23-grant-bulk-insert-file-access).

---

## 2. Initial Environment Setup

### 2.1 Clone the Repository

```bash
git clone https://github.com/<your-org>/sql-warehouse-project.git
cd sql-warehouse-project
```

### 2.2 Create the Database and Schemas

> **DESTRUCTIVE WARNING:** `scripts/init_database.sql` drops the `DataWarehouse` database if it exists and recreates it from scratch. **All existing data will be permanently lost.** Only run this script on a fresh installation or when a complete rebuild is explicitly required.

For non-destructive bootstrap (recommended outside local rebuild scenarios), run `scripts/init_database_safe.sql` instead.

1. Open SSMS and connect to your SQL Server instance.
2. Open `scripts/init_database.sql`.
3. Review the script. Read the WARNING comment block in the file.
4. Execute the script (`F5`).

Expected output:

```
Command(s) completed successfully.
```

After execution, the following should exist:

```sql
-- Verify
USE DataWarehouse;
SELECT name FROM sys.schemas WHERE name IN ('bronze', 'silver', 'gold', 'etl');
-- Expected: 4 rows
```

### 2.3 Grant BULK INSERT File Access

`BULK INSERT` requires the SQL Server service account to have read access to the CSV file directory.

**Option A — Local development (simplest):** Place CSV files under a path the SQL Server service account can read. The default service account (`NT SERVICE\MSSQLSERVER`) typically has read access to paths under `C:\`.

**Option B — Use a UNC path:** If files are on a network share, grant the service account `READ` on the share and use the full UNC path in the `BULK INSERT` statement.

To check the SQL Server service account:

```sql
-- Run on the SQL Server instance
EXEC xp_instance_regread
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Services\MSSQLSERVER',
    N'ObjectName';
```

### 2.4 Place Source CSV Files

Copy source files into the repository `datasets/` directory before running the Bronze load:

```
datasets/
├── source_erp/
│   ├── CUST_AZ12.csv
│   ├── LOC_A101.csv
│   └── PX_CAT_G1V2.csv
└── source_crm/
  ├── cust_info.csv
  ├── prd_info.csv
  └── sales_details.csv
```

File format requirements:

- Delimiter: comma (`,`)
- Encoding: UTF-8
- First row: header row (column names)
- Date format: `YYYY-MM-DD` for ERP sales; `YYYYMMDD` integer for CRM sales
- No enclosing quotes required for non-string fields

---

## 3. One-Click End-to-End Run

For local development, you can run the entire pipeline from a single script.

1. Open `scripts/00_run_end_to_end.sql` in SSMS.
2. Enable SQLCMD Mode: `Query -> SQLCMD Mode`.
3. Execute the script (`F5`).

This runner executes setup, Bronze/Silver/Gold object creation, data loads, and quality checks in order.

For non-destructive refreshes after source file updates, use `scripts/01_run_incremental_rerun.sql` (also in SQLCMD Mode).

---

## 4. Repository Layout and Execution Order

Scripts must be run in this order within each layer. Never run a higher layer without completing the layer below it.

```
scripts/
├── init_database.sql             ← Step 0: Run once to create DB and schemas
├── etl/
│   └── 01_ddl_etl_log.sql        ← Step 1: Create ETL logging table
│
├── bronze/
│   ├── ddl_bronze.sql            ← Step 2: Create Bronze tables
│   └── proc_load_bronze.sql      ← Step 3: Create Bronze load procedures
│
├── silver/
│   ├── ddl_silver.sql            ← Step 4: Create Silver tables
│   └── proc_load_silver.sql      ← Step 5: Create Silver load procedures
│
└── gold/
  ├── ddl_gold.sql              ← Step 6: Create Gold views
  └── 02_proc_load_gold.sql     ← Step 7: Gold compatibility procedures
```

---

## 5. Initial Full Load

Run all steps in sequence. Each step should complete with no errors before proceeding to the next.

### Step 0 — Initialise Database

```sql
-- In SSMS: open and execute
scripts/init_database.sql
```

### Step 1 — Create Bronze Tables

```sql
scripts/etl/01_ddl_etl_log.sql
scripts/bronze/ddl_bronze.sql
```

### Step 2 — Create and Execute Bronze Load

```sql
scripts/bronze/proc_load_bronze.sql

-- After creating the procedures, execute the master load:
USE DataWarehouse;
EXEC bronze.usp_bronze_load_all;
```

Expected: Row counts appear in the output for each Bronze table. Verify with:

```sql
SELECT 'bronze.erp_cust_az12'   AS tbl, COUNT(*) AS rows FROM bronze.erp_cust_az12
UNION ALL SELECT 'bronze.erp_loc_a101',       COUNT(*) FROM bronze.erp_loc_a101
UNION ALL SELECT 'bronze.erp_px_cat_g1v2',    COUNT(*) FROM bronze.erp_px_cat_g1v2
UNION ALL SELECT 'bronze.crm_cust_info',      COUNT(*) FROM bronze.crm_cust_info
UNION ALL SELECT 'bronze.crm_prd_info',       COUNT(*) FROM bronze.crm_prd_info
UNION ALL SELECT 'bronze.crm_sales_details',  COUNT(*) FROM bronze.crm_sales_details;
```

All row counts must be > 0.

### Step 3 — Create Silver Tables

```sql
scripts/silver/ddl_silver.sql
```

### Step 4 — Create and Execute Silver Load

```sql
scripts/silver/proc_load_silver.sql

EXEC silver.usp_silver_load_all;
```

### Step 5 — Create Gold Objects

```sql
scripts/gold/ddl_gold.sql
```

### Step 6 — Verify Gold Layer

```sql
-- Smoke test
SELECT TOP 10 * FROM gold.dim_customers;
SELECT TOP 10 * FROM gold.dim_products;
SELECT TOP 10 * FROM gold.fact_sales;

-- Referential integrity check
SELECT COUNT(*) AS orphan_product_keys
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
WHERE p.product_key IS NULL;
-- Expected: 0

SELECT COUNT(*) AS orphan_customer_keys
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
-- Expected: 0
```

---

## 6. Re-running a Full Load

When new source CSV files are received and a full reload is required:

1. Replace the CSV files in `datasets/source_erp/` and `datasets/source_crm/` with the new versions.
2. Execute the Bronze load procedure — it truncates and reloads all Bronze tables:
   ```sql
   EXEC bronze.usp_bronze_load_all;
   ```
3. Execute the Silver load procedure:
   ```sql
   EXEC silver.usp_silver_load_all;
   ```
4. Gold views do not require re-execution — they read from Silver on query. If Gold is implemented as physical tables, execute:
   ```sql
   EXEC gold.usp_gold_load_fact_sales;
   ```
5. Run the data quality checks in [Section 8](#8-data-quality-checks).

> **Note:** The `init_database.sql` script should **NOT** be re-run as part of a normal reload. It is a destructive rebuild script. For reloads, run only the layer load procedures.

---

## 7. Layer-by-Layer Procedures

### Bronze Layer

| Procedure                         | Action                             |
| --------------------------------- | ---------------------------------- |
| `EXEC bronze.load_bronze`         | Main Bronze load procedure         |
| `EXEC bronze.usp_bronze_load_all` | Wrapper alias used by docs/runbook |

### Silver Layer

| Procedure                         | Action                             |
| --------------------------------- | ---------------------------------- |
| `EXEC silver.load_silver`         | Main Silver load procedure         |
| `EXEC silver.usp_silver_load_all` | Wrapper alias used by docs/runbook |

### Gold Layer

| Procedure                            | Action                                               |
| ------------------------------------ | ---------------------------------------------------- |
| `EXEC gold.usp_gold_load_fact_sales` | Compatibility proc; validates Gold view availability |
| `EXEC gold.usp_gold_load_all`        | Wrapper alias for full Gold compatibility run        |

---

## 8. Data Quality Checks

Run these queries after every load to confirm data integrity. Queries are also available in `tests/`:

- `tests/quality_checks_bronze.sql`
- `tests/quality_checks_silver.sql`
- `tests/quality_checks_gold.sql`

### 7.1 Bronze Null Check

```sql
-- Check for unexpected NULLs in critical Bronze columns
SELECT 'erp_cust_az12' AS tbl, COUNT(*) AS null_cid
FROM bronze.erp_cust_az12 WHERE cid IS NULL OR TRIM(cid) = ''
UNION ALL
SELECT 'crm_cust_info', COUNT(*)
FROM bronze.crm_cust_info WHERE cst_id IS NULL;
-- Expected: 0 for all rows
```

### 7.2 Silver Duplicate Check

```sql
-- Silver customer deduplication: no duplicate cst_id
SELECT cst_id, COUNT(*) AS cnt
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

### 7.3 Silver Date Validity

```sql
-- No future birth dates
SELECT COUNT(*) AS future_bdates
FROM silver.erp_cust_az12
WHERE bdate > CAST(GETDATE() AS DATE);
-- Expected: 0

-- No order dates before year 2000
SELECT COUNT(*) AS invalid_dates
FROM silver.crm_sales_details
WHERE sls_order_dt < '2000-01-01';
-- Expected: 0
```

### 7.4 Silver Amount Consistency

```sql
-- Sales amount should equal quantity * price
SELECT COUNT(*) AS mismatched_amounts
FROM silver.crm_sales_details
WHERE sls_sales_amt <> sls_quantity * sls_price
  AND sls_quantity IS NOT NULL
  AND sls_price IS NOT NULL;
-- Expected: 0
```

### 7.5 Gold Referential Integrity

```sql
-- No orphan FK keys in fact_sales
SELECT 'orphan_products' AS check_name, COUNT(*) AS cnt
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
WHERE p.product_key IS NULL
UNION ALL
SELECT 'orphan_customers', COUNT(*)
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
-- Expected: 0 for both rows
```

### 7.6 Row Count Reconciliation

```sql
-- Compare Bronze to Silver row counts
SELECT
    'erp_cust_az12' AS entity,
    (SELECT COUNT(*) FROM bronze.erp_cust_az12) AS bronze_rows,
    (SELECT COUNT(*) FROM silver.erp_cust_az12) AS silver_rows;
-- Note: Silver rows may be <= Bronze rows due to deduplication. Silver rows > Bronze rows indicates a problem.
```

---

## 9. Troubleshooting

### BULK INSERT Fails with "Cannot bulk load because the file could not be opened"

**Cause:** The SQL Server service account does not have read access to the CSV file path.

**Resolution:**

1. Confirm the file path is accessible from the SQL Server host machine (not just the client).
2. Grant `READ` permission on the directory to the SQL Server service account.
3. If using a UNC path, ensure the service account has network access to the share.
4. Check that the file exists at the exact path specified in the stored procedure.

---

### BULK INSERT Fails with "Bulk load data conversion error"

**Cause:** A row in the CSV file has a value that cannot be cast to the target column data type.

**Resolution:**

1. Since Bronze tables use `NVARCHAR` for most columns, this error is uncommon but can occur if a numeric column (e.g. `cst_id INT`) contains non-numeric data.
2. Open the CSV file and look for malformed rows (extra commas, embedded line breaks, incorrect encoding).
3. If a specific row can be identified, it can be excluded or corrected in the source file.

---

### Silver Load Returns Unexpected NULL `gender` Values

**Cause:** The source CRM file contains a new gender code that is not mapped in the `CASE` expression.

**Resolution:**

1. Query `SELECT DISTINCT cst_gender FROM bronze.crm_cust_info` to identify the unmapped values.
2. Update the `CASE` expression in `usp_silver_load_crm_cust_info` to handle the new code.
3. Re-run `EXEC silver.usp_silver_load_crm_cust_info`.

---

### Gold Query Returns Orphan Fact Rows

**Cause:** A product or customer key in `fact_sales` does not resolve in the corresponding dimension.

**Common causes:**

- The cross-reference natural key (`sls_prd_key` / `sls_cust_id`) does not match any Silver dimension record.
- The dimension was not reloaded after the Silver load.

**Resolution:**

1. Identify the unresolved keys:
   ```sql
   SELECT DISTINCT sls_prd_key
   FROM silver.crm_sales_details
   WHERE sls_prd_key NOT IN (SELECT product_number FROM gold.dim_products);
   ```
2. Investigate whether these products exist in `silver.crm_prd_info`. If not, they may be discontinued products filtered out by the `prd_end_dt IS NULL` clause.
3. If legitimate, verify that the key extraction logic in `usp_silver_load_crm_prd_info` correctly strips the category prefix.

---

### `init_database.sql` was accidentally run on the wrong server

**Cause:** Human error — the script was run against a production or shared server.

**Resolution:**

1. Immediately notify the team.
2. Restore from backup if the environment had data that wasn't in the source CSVs.
3. If this is a development environment with no external data, re-run the full initial load sequence from [Section 5](#5-initial-full-load).
4. To prevent recurrence: add a guard variable to `init_database.sql` that requires a explicit confirmation string before proceeding.

---

## 10. Maintenance Tasks

### Update CSV Source Files

1. Obtain new CSV exports from source systems.
2. Validate file format: delimiter, encoding, column count, and header row must match the expected format.
3. Replace files in `datasets/source_erp/` and `datasets/source_crm/`.
4. Run the reload procedure documented in [Section 5](#5-re-running-a-full-load).

### Add a New Source Column

1. Add the column to the Bronze DDL in `scripts/bronze/01_ddl_bronze_tables.sql`.
2. Update the `BULK INSERT` format file or column list in the corresponding Bronze load procedure.
3. Add the column to the Silver DDL in `scripts/silver/01_ddl_silver_tables.sql`.
4. Add the transformation logic in the Silver load procedure.
5. If the column surfaces in Gold, update the relevant Gold view or procedure.
6. Update [docs/data_catalog.md](data_catalog.md) and [docs/source_to_target_mapping.md](source_to_target_mapping.md).

### Add a New Source Table

1. Create the Bronze table in `scripts/bronze/01_ddl_bronze_tables.sql`, following the naming convention in [docs/naming-conventions.md](naming-conventions.md).
2. Create a Bronze load stored procedure: `usp_bronze_load_<table_name>`.
3. Add the call to `usp_bronze_load_all`.
4. Repeat for Silver.
5. Extend the Gold layer if the new table contributes to existing or new dimensions/facts.
6. Document all new objects in the data catalog and STT mapping.

### Truncate and Rebuild a Single Layer

```sql
-- Rebuild Silver only (Bronze must already be loaded)
EXEC silver.usp_silver_load_all;

-- Rebuild Gold only (Silver must already be loaded)
-- For views: no action needed — views are always current
-- For materialised tables:
EXEC gold.usp_gold_load_fact_sales;
```

---

## 11. Environment-specific Notes

### Development (Local Machine)

- Use **SQL Server Developer Edition** (free, full feature set).
- Run `init_database.sql` freely — this is a local-only environment.
- CSV file paths in Bronze load procedures should use the local absolute path (e.g. `C:\Users\<user>\...\datasets\source_erp\CUST_AZ12.csv`).
- Consider creating a local `.env.sql` file or SQLCMD variable to hold the file path prefix.

### Staging / CI

- Use a dedicated SQL Server instance with a separate `DataWarehouse` database.
- CSV file paths should use a configurable parameter or environment variable.
- `init_database.sql` may be run as part of the pipeline to ensure a clean state.

### Production

- **Do not run `init_database.sql` in production.** Maintain a separate upgrade script that applies only schema changes.
- Use a dedicated service account with minimum required permissions:
  - `db_datareader` and `db_datawriter` on `DataWarehouse`
  - `EXECUTE` on stored procedures in `bronze`, `silver`, and `gold` schemas
  - `ADMINISTER BULK OPERATIONS` or `ADMINISTER DATABASE BULK OPERATIONS` for BULK INSERT
- Ensure backups are scheduled before each load cycle.
- Monitor procedure execution times using `sys.dm_exec_procedure_stats` to detect degradation.

---

## 12. Failure and Recovery Decision Tree

```
ETL Run Fails
     │
     ├── Bronze load fails?
     │       ├── BULK INSERT file error  → See §8: file access / encoding issues
     │       └── Data conversion error  → See §8: check CSV for malformed rows
     │
     ├── Silver load fails?
     │       ├── NULL constraint error   → Check Bronze source for unexpected NULLs
     │       ├── Unexpected NULL gender  → New source code; update CASE expression
     │       └── Row count mismatch      → Run §7.6 reconciliation query
     │
     └── Gold query returns bad data?
             ├── Orphan fact rows        → See §8: Gold orphan troubleshooting
             ├── Dimension not updated   → Re-run silver.usp_silver_load_all then Gold
             └── Wrong surrogate keys    → Rebuild Gold; ROW_NUMBER() is deterministic
                                           only if Silver order is stable
```

**Recovery for any layer — safe re-run steps:**

1. Identify the first failing layer (Bronze, Silver, or Gold).
2. Fix the underlying cause (file, code, or data issue).
3. Re-run from the failing layer downward — you do **not** need to reload layers above the failure.
4. Always run data quality checks from [Section 8](#8-data-quality-checks) after recovery.
5. Log the incident in your team's change log with: timestamp, root cause, rows affected, and resolution.

---

## 13. Related Documents

| Document                                                        | Purpose                                           |
| --------------------------------------------------------------- | ------------------------------------------------- |
| [docs/requirements.md](requirements.md)                         | Business requirements, KPIs, analytical scope     |
| [docs/data_catalog.md](data_catalog.md)                         | Column-level definitions for all layers           |
| [docs/naming-conventions.md](naming-conventions.md)             | Object naming standards                           |
| [docs/source_to_target_mapping.md](source_to_target_mapping.md) | Column-level ETL lineage and transformation rules |
