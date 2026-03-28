# Naming Conventions

**Version:** 1.0  
**Status:** Approved  
**Last Updated:** 2026-03-28  
**Applies To:** `DataWarehouse` — all schemas, tables, columns, procedures, indexes, and files.

This document defines the naming standards for all database objects, files, and scripts in the `DataWarehouse` project. All contributors must follow these conventions to ensure consistency, readability, and maintainability across Bronze, Silver, and Gold layers.

---

## Quick Reference

| Object Type         | Pattern                            | Example                         |
| ------------------- | ---------------------------------- | ------------------------------- |
| Schema              | fixed name                         | `bronze`, `silver`, `gold`      |
| Bronze table        | `bronze.<source>_<file>`           | `bronze.erp_cust_az12`          |
| Silver table        | `silver.<source>_<entity>`         | `silver.crm_cust_info`          |
| Gold dimension      | `gold.dim_<entity_plural>`         | `gold.dim_customers`            |
| Gold fact           | `gold.fact_<process>`              | `gold.fact_sales`               |
| Surrogate key       | `<entity_singular>_key`            | `customer_key`, `product_key`   |
| Natural/source key  | `<entity_singular>_id`             | `customer_id`, `product_id`     |
| Stored procedure    | `usp_<layer>_load_<target>`        | `usp_silver_load_crm_cust_info` |
| Bronze audit column | `etl_load_ts`                      | `DATETIME NOT NULL`             |
| Silver audit column | `dwh_created_at`, `dwh_updated_at` | `DATETIME NOT NULL`             |
| SQL script file     | `<nn>_<type>_<description>.sql`    | `02_proc_load_bronze.sql`       |

---

## 1. General Principles

- **snake_case** for all identifiers — lowercase letters, words separated by underscores. No camelCase, PascalCase, or hyphen-separated names in SQL objects.
- **Descriptive over abbreviated** — prefer `order_date` over `ord_dt`, except for well-established domain abbreviations listed in [Section 7](#7-approved-abbreviations).
- **Singular nouns for tables** — `dim_customer` not `dim_customers` for dimension tables. Exception: Gold fact and dimension tables use the plural form for the entity portion to align with common BI tool conventions (`dim_customers`, `dim_products`, `fact_sales`).
- **No reserved words** — do not use SQL Server reserved words as object names. If a reserved word is unavoidable, bracket it (`[date]`), but prefer a different name.
- **Consistent prefix/suffix patterns** — prefixes identify the object type and layer; suffixes identify the role within that type.

---

## 2. Schemas

| Schema   | Purpose                         | Convention                                 |
| -------- | ------------------------------- | ------------------------------------------ |
| `bronze` | Raw ingestion layer             | Fixed name; maps 1-to-1 with source system |
| `silver` | Cleansed and standardised layer | Fixed name                                 |
| `gold`   | Business-ready analytical layer | Fixed name                                 |

No additional schemas should be created without a documented architectural decision.

---

## 3. Tables

### 3.1 Bronze Tables

Pattern: `bronze.<source_system>_<source_file_name>`

- `<source_system>` is `erp` or `crm` (lowercase, abbreviated to match the source system identifier).
- `<source_file_name>` is the source file name, lowercased and normalised to snake_case.

**Examples:**

| Source File               | Bronze Table               |
| ------------------------- | -------------------------- |
| `CUST_AZ12.csv` (ERP)     | `bronze.erp_cust_az12`     |
| `LOC_A101.csv` (ERP)      | `bronze.erp_loc_a101`      |
| `PRD_INFO.csv` (CRM)      | `bronze.crm_prd_info`      |
| `SALES_DETAILS.csv` (CRM) | `bronze.crm_sales_details` |

### 3.2 Silver Tables

Pattern: `silver.<source_system>_<entity>`

- Same base name as the corresponding Bronze table.
- Silver tables are named identically to their Bronze counterparts; the schema prefix distinguishes the layer.

**Examples:** `silver.erp_cust_az12`, `silver.crm_cust_info`

### 3.3 Gold Dimension Tables

Pattern: `gold.dim_<entity_plural>`

| Entity   | Table                |
| -------- | -------------------- |
| Customer | `gold.dim_customers` |
| Product  | `gold.dim_products`  |
| Date     | `gold.dim_date`      |

### 3.4 Gold Fact Tables

Pattern: `gold.fact_<business_process>`

| Business Process   | Table             |
| ------------------ | ----------------- |
| Sales transactions | `gold.fact_sales` |

---

## 4. Columns

### 4.1 General Column Rules

- snake_case, lowercase.
- Must be descriptive: `order_date` not `dt`, `customer_id` not `cid` (Silver and Gold layers; Bronze preserves source names).
- Boolean columns: prefixed with `is_` or `has_`. Values are `BIT` type (`1` / `0`).
- Date-only columns: suffix `_date` (type `DATE`). Datetime columns: suffix `_ts` (type `DATETIME`).

### 4.2 Key Columns

| Key Type                  | Naming Pattern                     | Data Type           | Notes                                                     |
| ------------------------- | ---------------------------------- | ------------------- | --------------------------------------------------------- |
| Surrogate key (Gold dims) | `<entity_singular>_key`            | `INT`               | Generated by `ROW_NUMBER()` or `IDENTITY`                 |
| Natural / source key      | `<entity_singular>_id`             | Matches source type | Retained in Silver and Gold for traceability              |
| Foreign key column        | `<referenced_entity_singular>_key` | `INT`               | Must match the name of the PK in the referenced dimension |
| Date dimension FK         | `<role>_date_key`                  | `INT`               | E.g. `order_date_key`, `ship_date_key`                    |

**Examples:**

| Column           | Explanation                                   |
| ---------------- | --------------------------------------------- |
| `customer_key`   | Surrogate key in `dim_customers`              |
| `customer_id`    | Natural key retained from CRM source          |
| `product_key`    | Surrogate key in `dim_products`               |
| `order_date_key` | FK to `dim_date.date_key` for order date role |

### 4.3 Audit Columns

All Silver and Gold physical tables include the following audit columns. They must always be the last columns in the table definition.

| Column           | Data Type  | Layer  | Description                                       |
| ---------------- | ---------- | ------ | ------------------------------------------------- |
| `etl_load_ts`    | `DATETIME` | Bronze | Timestamp when row was loaded from source         |
| `dwh_created_at` | `DATETIME` | Silver | Timestamp when row was first inserted into Silver |
| `dwh_updated_at` | `DATETIME` | Silver | Timestamp when row was last updated in Silver     |

---

## 5. Stored Procedures

Pattern: `usp_<layer>_load_<target_table>`

- `usp_` prefix denotes a user-defined stored procedure.
- `<layer>` is `bronze`, `silver`, or `gold`.
- `<target_table>` is the unqualified table name without schema prefix.

**Examples:**

| Procedure                       | Purpose                                             |
| ------------------------------- | --------------------------------------------------- |
| `usp_bronze_load_erp_cust_az12` | Loads `bronze.erp_cust_az12` from CSV               |
| `usp_silver_load_erp_cust_az12` | Cleanse and load `silver.erp_cust_az12` from Bronze |
| `usp_gold_load_fact_sales`      | Populate `gold.fact_sales` from Silver              |

Master orchestration procedures follow the pattern: `usp_<layer>_load_all`

**Examples:** `usp_bronze_load_all`, `usp_silver_load_all`, `usp_gold_load_all`

---

## 6. Indexes

Pattern: `IX_<table_name>_<column_name(s)>`

- `IX_` prefix for non-clustered indexes.
- `PK_` prefix for primary key constraints (applied by SQL Server automatically when defined as `PRIMARY KEY`).
- `FK_` prefix for foreign key constraints.
- `UQ_` prefix for unique constraints.

**Examples:**

| Index                            | Table                  | Column(s)                                   |
| -------------------------------- | ---------------------- | ------------------------------------------- |
| `PK_dim_customers`               | `gold.dim_customers`   | `customer_key`                              |
| `IX_fact_sales_customer_key`     | `gold.fact_sales`      | `customer_key`                              |
| `IX_fact_sales_order_date_key`   | `gold.fact_sales`      | `order_date_key`                            |
| `FK_fact_sales_dim_customers`    | `gold.fact_sales`      | `customer_key → dim_customers.customer_key` |
| `UQ_silver_crm_cust_info_cst_id` | `silver.crm_cust_info` | `cst_id`                                    |

---

## 7. Views

Pattern: `vw_<descriptive_name>`

- Used for reusable query logic in Gold when objects are not materialised as tables.
- Gold analytical objects use the `dim_` / `fact_` prefix rather than `vw_` to preserve the star-schema naming regardless of physical implementation.

---

## 8. Files and Scripts

### SQL Scripts

Pattern: `<order>_<object_type>_<description>.sql`

- `<order>` is a two-digit execution sequence number.
- `<object_type>` is `ddl` (schema/table creation), `proc` (stored procedure), or `load` (data load execution).

**Examples:**

```
scripts/bronze/01_ddl_bronze_tables.sql
scripts/bronze/02_proc_load_erp_cust_az12.sql
scripts/bronze/03_proc_load_all.sql
scripts/silver/01_ddl_silver_tables.sql
scripts/silver/02_proc_load_erp_cust_az12.sql
scripts/gold/01_ddl_gold_views.sql
scripts/gold/02_proc_load_fact_sales.sql
```

### Dataset Files

Pattern: `<SOURCE_SYSTEM>_<ENTITY_NAME>.csv` — uppercase, matching the original source system convention.

**Examples:** `ERP_CUST_AZ12.csv`, `CRM_SALES_DETAILS.csv`

---

## 9. Approved Abbreviations

The following abbreviations are permitted across all layers. All others should be spelled out in full.

| Abbreviation | Full Term                                        |
| ------------ | ------------------------------------------------ |
| `id`         | identifier                                       |
| `key`        | surrogate or natural key                         |
| `ts`         | timestamp                                        |
| `dt`         | date (Bronze layer only, when matching source)   |
| `amt`        | amount (Bronze layer only, when matching source) |
| `num`        | number                                           |
| `qty`        | quantity (Bronze layer only)                     |
| `prd`        | product (Bronze layer only)                      |
| `cst`        | customer (Bronze layer only)                     |
| `sls`        | sales (Bronze layer only)                        |
| `erp`        | Enterprise Resource Planning system              |
| `crm`        | Customer Relationship Management system          |
| `dwh`        | Data Warehouse                                   |
| `etl`        | Extract, Transform, Load                         |
| `usp`        | User Stored Procedure                            |

**Rule:** Abbreviations from this list may be used in Bronze table column names (to preserve source fidelity) and in procedure names. Silver and Gold column names should use the full term.

---

## 10. Prohibited Patterns

The following patterns are explicitly disallowed:

| Pattern                                                             | Reason                                                                     |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `tbl_` prefix on tables                                             | Adds no meaning — the `FROM` clause already identifies objects as tables   |
| Spaces in object names                                              | Require bracket-quoting in every reference                                 |
| Mixed case object names                                             | SQL Server is case-insensitive for identifiers but consistency is required |
| Generic names (`data`, `info`, `temp`, `stuff`) without a qualifier | Non-descriptive                                                            |
| `_new`, `_v2`, `_final`, `_backup` suffixes                         | Use Git branches and schema versioning instead                             |
| `SELECT *` in stored procedures                                     | Must select explicit columns to avoid silent schema breakage               |
