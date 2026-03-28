# Data Catalog

**Version:** 1.0  
**Status:** Approved  
**Last Updated:** 2026-03-28  
**Database:** `DataWarehouse`

This catalog is the authoritative reference for every table and view in the `DataWarehouse` database. It covers all three medallion layers — Bronze, Silver, and Gold — and includes table purpose, column-level definitions, data types, nullability, business meaning, and applied transformation rules.

**Audience:** Data engineers writing ETL procedures, analysts building reports, and stakeholders validating data definitions.

---

## Table of Contents

- [Layer Summary](#layer-summary)
- [Bronze Layer](#bronze-layer)
  - [bronze.erp_cust_az12](#bronzeerpust_az12)
  - [bronze.erp_loc_a101](#bronzeerp_loc_a101)
  - [bronze.erp_px_cat_g1v2](#bronzeerp_px_cat_g1v2)
  - [bronze.erp_prd_info](#bronzeerp_prd_info)
  - [bronze.erp_sales_details](#bronzeerp_sales_details)
  - [bronze.crm_cust_info](#bronzecrm_cust_info)
  - [bronze.crm_prd_info](#bronzecrm_prd_info)
  - [bronze.crm_sales_details](#bronzecrm_sales_details)
- [Silver Layer](#silver-layer)
  - [silver.erp_cust_az12](#silvererp_cust_az12)
  - [silver.erp_loc_a101](#silvererp_loc_a101)
  - [silver.erp_px_cat_g1v2](#silvererp_px_cat_g1v2)
  - [silver.erp_prd_info](#silvererp_prd_info)
  - [silver.erp_sales_details](#silvererp_sales_details)
  - [silver.crm_cust_info](#silvercrm_cust_info)
  - [silver.crm_prd_info](#silvercrm_prd_info)
  - [silver.crm_sales_details](#silvercrm_sales_details)
- [Gold Layer](#gold-layer)
  - [gold.dim_customers](#golddim_customers)
  - [gold.dim_products](#golddim_products)
  - [gold.dim_date](#golddim_date)
  - [gold.fact_sales](#goldfact_sales)

---

## Layer Summary

| Layer  | Schema   | Object Count   | Type                            | Loaded By                    |
| ------ | -------- | -------------- | ------------------------------- | ---------------------------- |
| Bronze | `bronze` | 6 tables       | Physical tables (raw ingestion) | `usp_bronze_load_all`        |
| Silver | `silver` | 6 tables       | Physical tables (cleansed)      | `usp_silver_load_all`        |
| Gold   | `gold`   | 4 views/tables | Star schema (analytical)        | Views or `usp_gold_load_all` |

---

## Bronze Layer

Bronze tables are loaded directly from source CSV files using `BULK INSERT` with **no transformation**. Column names preserve the original source naming converted to `snake_case`. All columns use permissive types (`NVARCHAR` or broad numeric) to prevent load failures caused by dirty source data. Type casting is deferred to the Silver layer.

> **Design principle:** Bronze is a faithful digital copy of the source. No business logic is applied here.

### `bronze.erp_cust_az12`

**Source file:** `datasets/source_erp/CUST_AZ12.csv`  
**Description:** Customer master data from the ERP system. Contains demographic attributes.

| Column        | Data Type      | Nullable | Description                                                                                                    |
| ------------- | -------------- | -------- | -------------------------------------------------------------------------------------------------------------- |
| `cid`         | `NVARCHAR(50)` | YES      | ERP customer identifier; may include prefix (e.g. `NAS-` prefix is present in raw data and stripped in Silver) |
| `bdate`       | `NVARCHAR(50)` | YES      | Customer birth date as a string in source system format                                                        |
| `gen`         | `NVARCHAR(10)` | YES      | Gender code from ERP; raw values include `M`, `F`, `0`, and blank                                              |
| `etl_load_ts` | `DATETIME`     | NO       | Timestamp when the row was loaded into Bronze; populated by `GETDATE()`                                        |

---

### `bronze.erp_loc_a101`

**Source file:** `datasets/source_erp/LOC_A101.csv`  
**Description:** Customer location/address data from the ERP system.

| Column        | Data Type       | Nullable | Description                                                                                                       |
| ------------- | --------------- | -------- | ----------------------------------------------------------------------------------------------------------------- |
| `cid`         | `NVARCHAR(50)`  | YES      | ERP customer identifier; joins to `bronze.erp_cust_az12.cid` after prefix normalisation                           |
| `cntry`       | `NVARCHAR(100)` | YES      | Country name; raw values may include inconsistent spellings and abbreviations (e.g. `US`, `USA`, `United States`) |
| `etl_load_ts` | `DATETIME`      | NO       | Load timestamp                                                                                                    |

---

### `bronze.erp_px_cat_g1v2`

**Source file:** `datasets/source_erp/PX_CAT_G1V2.csv`  
**Description:** Product category hierarchy from the ERP system.

| Column        | Data Type       | Nullable | Description                                           |
| ------------- | --------------- | -------- | ----------------------------------------------------- |
| `id`          | `NVARCHAR(50)`  | YES      | Product category code; joins to `erp_prd_info.cat_id` |
| `cat`         | `NVARCHAR(100)` | YES      | Top-level product category name                       |
| `subcat`      | `NVARCHAR(100)` | YES      | Product subcategory name                              |
| `maintenance` | `NVARCHAR(50)`  | YES      | Internal maintenance classification flag              |
| `etl_load_ts` | `DATETIME`      | NO       | Load timestamp                                        |

---

### `bronze.erp_prd_info`

**Source file:** `datasets/source_erp/PRD_INFO.csv`  
**Description:** Product master data from the ERP system.

| Column         | Data Type       | Nullable | Description                                                                     |
| -------------- | --------------- | -------- | ------------------------------------------------------------------------------- |
| `prd_id`       | `NVARCHAR(50)`  | YES      | ERP product identifier                                                          |
| `cat_id`       | `NVARCHAR(50)`  | YES      | Category code; references `bronze.erp_px_cat_g1v2.id`                           |
| `prd_nm`       | `NVARCHAR(200)` | YES      | Product name                                                                    |
| `prd_cost`     | `NVARCHAR(50)`  | YES      | Unit cost as a string; may be blank or contain non-numeric characters in source |
| `prd_line`     | `NVARCHAR(50)`  | YES      | Product line code                                                               |
| `prd_start_dt` | `NVARCHAR(50)`  | YES      | Product availability start date in string format                                |
| `prd_end_dt`   | `NVARCHAR(50)`  | YES      | Product availability end date; `NULL` indicates currently active                |
| `etl_load_ts`  | `DATETIME`      | NO       | Load timestamp                                                                  |

---

### `bronze.erp_sales_details`

**Source file:** `datasets/source_erp/SALES_DETAILS.csv`  
**Description:** Sales order line-item data from the ERP system.

| Column          | Data Type      | Nullable | Description                                                         |
| --------------- | -------------- | -------- | ------------------------------------------------------------------- |
| `sls_ord_num`   | `NVARCHAR(50)` | YES      | Sales order number                                                  |
| `sls_prd_key`   | `NVARCHAR(50)` | YES      | ERP product key; references product dimension                       |
| `sls_cust_id`   | `NVARCHAR(50)` | YES      | ERP customer identifier                                             |
| `sls_order_dt`  | `NVARCHAR(50)` | YES      | Order date as string                                                |
| `sls_ship_dt`   | `NVARCHAR(50)` | YES      | Ship date as string                                                 |
| `sls_due_dt`    | `NVARCHAR(50)` | YES      | Due date as string                                                  |
| `sls_sales_amt` | `NVARCHAR(50)` | YES      | Total sales amount; may require recalculation from price × quantity |
| `sls_quantity`  | `NVARCHAR(50)` | YES      | Order line quantity                                                 |
| `sls_price`     | `NVARCHAR(50)` | YES      | Unit price at time of sale                                          |
| `etl_load_ts`   | `DATETIME`     | NO       | Load timestamp                                                      |

---

### `bronze.crm_cust_info`

**Source file:** `datasets/source_crm/CUST_INFO.csv`  
**Description:** Customer master data from the CRM system.

| Column               | Data Type       | Nullable | Description                                                  |
| -------------------- | --------------- | -------- | ------------------------------------------------------------ |
| `cst_id`             | `INT`           | YES      | CRM customer identifier                                      |
| `cst_key`            | `NVARCHAR(50)`  | YES      | Natural key used to cross-reference ERP customer             |
| `cst_firstname`      | `NVARCHAR(100)` | YES      | Customer first name                                          |
| `cst_lastname`       | `NVARCHAR(100)` | YES      | Customer last name                                           |
| `cst_marital_status` | `NVARCHAR(20)`  | YES      | Marital status code; raw values include `M`, `S`, and blank  |
| `cst_gender`         | `NVARCHAR(20)`  | YES      | Gender code from CRM; raw values include `M`, `F`, and blank |
| `cst_create_date`    | `NVARCHAR(50)`  | YES      | Date the customer record was created in CRM                  |
| `etl_load_ts`        | `DATETIME`      | NO       | Load timestamp                                               |

---

### `bronze.crm_prd_info`

**Source file:** `datasets/source_crm/PRD_INFO.csv`  
**Description:** Product data from the CRM system. Partially overlaps with ERP product data.

| Column         | Data Type       | Nullable | Description                                                        |
| -------------- | --------------- | -------- | ------------------------------------------------------------------ |
| `prd_id`       | `NVARCHAR(50)`  | YES      | CRM product identifier                                             |
| `prd_key`      | `NVARCHAR(50)`  | YES      | Key used to cross-reference ERP product; derived from ERP `prd_id` |
| `prd_nm`       | `NVARCHAR(200)` | YES      | Product name from CRM; may differ from ERP name                    |
| `prd_cost`     | `NVARCHAR(50)`  | YES      | Unit cost from CRM                                                 |
| `prd_line`     | `NVARCHAR(50)`  | YES      | Product line (expanded label, versus ERP code)                     |
| `prd_start_dt` | `NVARCHAR(50)`  | YES      | Product availability start date                                    |
| `prd_end_dt`   | `NVARCHAR(50)`  | YES      | Product availability end date                                      |
| `etl_load_ts`  | `DATETIME`      | NO       | Load timestamp                                                     |

---

### `bronze.crm_sales_details`

**Source file:** `datasets/source_crm/SALES_DETAILS.csv`  
**Description:** Sales transaction data from the CRM system.

| Column          | Data Type      | Nullable | Description                                             |
| --------------- | -------------- | -------- | ------------------------------------------------------- |
| `sls_ord_num`   | `NVARCHAR(50)` | YES      | Sales order number; overlaps with ERP order numbers     |
| `sls_prd_key`   | `NVARCHAR(50)` | YES      | CRM product key                                         |
| `sls_cust_id`   | `INT`          | YES      | CRM customer identifier                                 |
| `sls_order_dt`  | `INT`          | YES      | Order date stored as an integer (`YYYYMMDD`) in CRM     |
| `sls_ship_dt`   | `INT`          | YES      | Ship date as integer                                    |
| `sls_due_dt`    | `INT`          | YES      | Due date as integer                                     |
| `sls_sales_amt` | `INT`          | YES      | Sales amount as integer (cents or whole currency units) |
| `sls_quantity`  | `INT`          | YES      | Order line quantity                                     |
| `sls_price`     | `INT`          | YES      | Unit price as integer                                   |
| `etl_load_ts`   | `DATETIME`     | NO       | Load timestamp                                          |

---

## Silver Layer

Silver tables clean and standardise Bronze data. Each Silver table maps 1-to-1 with a Bronze source table. Type casting, whitespace trimming, null handling, deduplication, and value standardisation are applied. Silver tables preserve Bronze-style column names to maintain clear lineage.

All Silver tables include the following audit columns:

| Audit Column     | Data Type  | Description                                                  |
| ---------------- | ---------- | ------------------------------------------------------------ |
| `dwh_created_at` | `DATETIME` | Row first inserted into Silver                               |
| `dwh_updated_at` | `DATETIME` | Row last updated in Silver (same as created for full-reload) |

### `silver.erp_cust_az12`

**Source:** `bronze.erp_cust_az12`  
**Transformation summary:** Strip `NAS-` prefix from `cid`; cast `bdate` to `DATE`; standardise `gen` to `'Male'` / `'Female'` / `'Unknown'`.

| Column           | Data Type      | Nullable | Description                                               |
| ---------------- | -------------- | -------- | --------------------------------------------------------- |
| `cid`            | `NVARCHAR(50)` | NO       | Normalised customer ID (prefix removed)                   |
| `bdate`          | `DATE`         | YES      | Birth date cast to `DATE`                                 |
| `gen`            | `NVARCHAR(10)` | YES      | Standardised gender: `'Male'`, `'Female'`, or `'Unknown'` |
| `dwh_created_at` | `DATETIME`     | NO       | Audit: row insert timestamp                               |
| `dwh_updated_at` | `DATETIME`     | NO       | Audit: row update timestamp                               |

---

### `silver.erp_loc_a101`

**Source:** `bronze.erp_loc_a101`  
**Transformation summary:** Strip prefix from `cid`; standardise `cntry` spelling variants (e.g. `US`, `USA` → `'United States'`; blank → `'Unknown'`).

| Column           | Data Type       | Nullable | Description                 |
| ---------------- | --------------- | -------- | --------------------------- |
| `cid`            | `NVARCHAR(50)`  | NO       | Normalised customer ID      |
| `cntry`          | `NVARCHAR(100)` | YES      | Standardised country name   |
| `dwh_created_at` | `DATETIME`      | NO       | Audit: row insert timestamp |
| `dwh_updated_at` | `DATETIME`      | NO       | Audit: row update timestamp |

---

### `silver.erp_px_cat_g1v2`

**Source:** `bronze.erp_px_cat_g1v2`  
**Transformation summary:** Trim whitespace; replace blank strings with `NULL`.

| Column           | Data Type       | Nullable | Description                 |
| ---------------- | --------------- | -------- | --------------------------- |
| `id`             | `NVARCHAR(50)`  | NO       | Category code               |
| `cat`            | `NVARCHAR(100)` | YES      | Category name               |
| `subcat`         | `NVARCHAR(100)` | YES      | Subcategory name            |
| `maintenance`    | `NVARCHAR(50)`  | YES      | Maintenance classification  |
| `dwh_created_at` | `DATETIME`      | NO       | Audit: row insert timestamp |
| `dwh_updated_at` | `DATETIME`      | NO       | Audit: row update timestamp |

---

### `silver.erp_prd_info`

**Source:** `bronze.erp_prd_info`  
**Transformation summary:** Cast `prd_cost` to `DECIMAL(18,2)`; cast dates to `DATE`; replace blank `prd_end_dt` with `NULL`; derive `cat_id` by extracting category substring from `prd_id`.

| Column           | Data Type       | Nullable | Description                                      |
| ---------------- | --------------- | -------- | ------------------------------------------------ |
| `prd_id`         | `NVARCHAR(50)`  | NO       | ERP product identifier                           |
| `cat_id`         | `NVARCHAR(50)`  | YES      | Derived category code                            |
| `prd_nm`         | `NVARCHAR(200)` | YES      | Product name                                     |
| `prd_cost`       | `DECIMAL(18,2)` | YES      | Unit cost                                        |
| `prd_line`       | `NVARCHAR(50)`  | YES      | Product line code                                |
| `prd_start_dt`   | `DATE`          | YES      | Availability start date                          |
| `prd_end_dt`     | `DATE`          | YES      | Availability end date; `NULL` = currently active |
| `dwh_created_at` | `DATETIME`      | NO       | Audit: row insert timestamp                      |
| `dwh_updated_at` | `DATETIME`      | NO       | Audit: row update timestamp                      |

---

### `silver.erp_sales_details`

**Source:** `bronze.erp_sales_details`  
**Transformation summary:** Cast date strings to `DATE`; cast `sls_quantity`, `sls_price`, `sls_sales_amt` to `INT` / `DECIMAL`; recalculate `sls_sales_amt = sls_quantity * sls_price` where the stored amount is negative, zero, or mismatched.

| Column           | Data Type       | Nullable | Description                           |
| ---------------- | --------------- | -------- | ------------------------------------- |
| `sls_ord_num`    | `NVARCHAR(50)`  | NO       | Sales order number                    |
| `sls_prd_key`    | `NVARCHAR(50)`  | YES      | Product key                           |
| `sls_cust_id`    | `NVARCHAR(50)`  | YES      | Customer identifier                   |
| `sls_order_dt`   | `DATE`          | YES      | Order date                            |
| `sls_ship_dt`    | `DATE`          | YES      | Ship date                             |
| `sls_due_dt`     | `DATE`          | YES      | Due date                              |
| `sls_sales_amt`  | `DECIMAL(18,2)` | YES      | Recalculated or verified sales amount |
| `sls_quantity`   | `INT`           | YES      | Order quantity                        |
| `sls_price`      | `DECIMAL(18,2)` | YES      | Unit price                            |
| `dwh_created_at` | `DATETIME`      | NO       | Audit: row insert timestamp           |
| `dwh_updated_at` | `DATETIME`      | NO       | Audit: row update timestamp           |

---

### `silver.crm_cust_info`

**Source:** `bronze.crm_cust_info`  
**Transformation summary:** Trim whitespace on all string fields; standardise `cst_marital_status` to `'Married'` / `'Single'` / `'Unknown'`; standardise `cst_gender` to `'Male'` / `'Female'` / `'Unknown'`; deduplicate on `cst_id` retaining the row with the latest `cst_create_date`.

| Column               | Data Type       | Nullable | Description                            |
| -------------------- | --------------- | -------- | -------------------------------------- |
| `cst_id`             | `INT`           | NO       | CRM customer identifier (deduplicated) |
| `cst_key`            | `NVARCHAR(50)`  | YES      | Cross-reference key to ERP             |
| `cst_firstname`      | `NVARCHAR(100)` | YES      | Trimmed first name                     |
| `cst_lastname`       | `NVARCHAR(100)` | YES      | Trimmed last name                      |
| `cst_marital_status` | `NVARCHAR(20)`  | YES      | Standardised marital status            |
| `cst_gender`         | `NVARCHAR(20)`  | YES      | Standardised gender                    |
| `cst_create_date`    | `DATE`          | YES      | Customer creation date                 |
| `dwh_created_at`     | `DATETIME`      | NO       | Audit: row insert timestamp            |
| `dwh_updated_at`     | `DATETIME`      | NO       | Audit: row update timestamp            |

---

### `silver.crm_prd_info`

**Source:** `bronze.crm_prd_info`  
**Transformation summary:** Strip category and product key substrings; cast cost and dates; expand product line codes to full labels.

| Column           | Data Type       | Nullable | Description                 |
| ---------------- | --------------- | -------- | --------------------------- |
| `prd_id`         | `NVARCHAR(50)`  | NO       | CRM product identifier      |
| `cat_id`         | `NVARCHAR(50)`  | YES      | Extracted category code     |
| `prd_key`        | `NVARCHAR(50)`  | YES      | Cleaned cross-reference key |
| `prd_nm`         | `NVARCHAR(200)` | YES      | Product name                |
| `prd_cost`       | `DECIMAL(18,2)` | YES      | Unit cost                   |
| `prd_line`       | `NVARCHAR(50)`  | YES      | Expanded product line label |
| `prd_start_dt`   | `DATE`          | YES      | Availability start date     |
| `prd_end_dt`     | `DATE`          | YES      | Availability end date       |
| `dwh_created_at` | `DATETIME`      | NO       | Audit: row insert timestamp |
| `dwh_updated_at` | `DATETIME`      | NO       | Audit: row update timestamp |

---

### `silver.crm_sales_details`

**Source:** `bronze.crm_sales_details`  
**Transformation summary:** Cast integer date fields (`YYYYMMDD`) to `DATE`; validate and recalculate `sls_sales_amt` where mismatched.

| Column           | Data Type       | Nullable | Description                             |
| ---------------- | --------------- | -------- | --------------------------------------- |
| `sls_ord_num`    | `NVARCHAR(50)`  | NO       | Sales order number                      |
| `sls_prd_key`    | `NVARCHAR(50)`  | YES      | Product key                             |
| `sls_cust_id`    | `INT`           | YES      | CRM customer identifier                 |
| `sls_order_dt`   | `DATE`          | YES      | Order date (cast from YYYYMMDD integer) |
| `sls_ship_dt`    | `DATE`          | YES      | Ship date                               |
| `sls_due_dt`     | `DATE`          | YES      | Due date                                |
| `sls_sales_amt`  | `DECIMAL(18,2)` | YES      | Validated sales amount                  |
| `sls_quantity`   | `INT`           | YES      | Quantity                                |
| `sls_price`      | `DECIMAL(18,2)` | YES      | Unit price                              |
| `dwh_created_at` | `DATETIME`      | NO       | Audit: row insert timestamp             |
| `dwh_updated_at` | `DATETIME`      | NO       | Audit: row update timestamp             |

---

## Gold Layer

Gold objects implement the star schema. In the initial delivery these are **views** defined over Silver tables. They may be materialised to physical tables in a later phase.

### `gold.dim_customers`

**Source:** `silver.crm_cust_info` JOIN `silver.erp_cust_az12` JOIN `silver.erp_loc_a101`  
**Description:** Conformed customer dimension. CRM is the master record for name and demographics; ERP provides birth date and location.

| Column            | Data Type       | Nullable | Description                                                       |
| ----------------- | --------------- | -------- | ----------------------------------------------------------------- |
| `customer_key`    | `INT`           | NO       | Surrogate key (sequential, generated by `ROW_NUMBER()`)           |
| `customer_id`     | `INT`           | NO       | CRM natural key (`cst_id`) retained for traceability              |
| `customer_number` | `NVARCHAR(50)`  | YES      | Cross-reference key (`cst_key`)                                   |
| `first_name`      | `NVARCHAR(100)` | YES      | Customer first name                                               |
| `last_name`       | `NVARCHAR(100)` | YES      | Customer last name                                                |
| `country`         | `NVARCHAR(100)` | YES      | Country from ERP location data                                    |
| `marital_status`  | `NVARCHAR(20)`  | YES      | Standardised marital status                                       |
| `gender`          | `NVARCHAR(20)`  | YES      | Gender resolved from CRM; falls back to ERP if CRM is `'Unknown'` |
| `birthdate`       | `DATE`          | YES      | Birth date from ERP                                               |
| `create_date`     | `DATE`          | YES      | Original CRM creation date                                        |

---

### `gold.dim_products`

**Source:** `silver.crm_prd_info` JOIN `silver.erp_px_cat_g1v2`  
**Description:** Conformed product dimension. CRM is the master product record; ERP category hierarchy enriches it.

| Column               | Data Type       | Nullable | Description                    |
| -------------------- | --------------- | -------- | ------------------------------ |
| `product_key`        | `INT`           | NO       | Surrogate key                  |
| `product_id`         | `NVARCHAR(50)`  | NO       | CRM natural product identifier |
| `product_number`     | `NVARCHAR(50)`  | YES      | Cross-reference key to ERP     |
| `product_name`       | `NVARCHAR(200)` | YES      | Product name                   |
| `category`           | `NVARCHAR(100)` | YES      | Top-level category from ERP    |
| `subcategory`        | `NVARCHAR(100)` | YES      | Subcategory from ERP           |
| `product_line`       | `NVARCHAR(50)`  | YES      | Expanded product line label    |
| `product_cost`       | `DECIMAL(18,2)` | YES      | Unit cost                      |
| `product_start_date` | `DATE`          | YES      | Availability start date        |

**Note:** Only currently active products (`prd_end_dt IS NULL`) are included in the dimension.

---

### `gold.dim_date`

**Source:** Procedurally generated; not sourced from Bronze or Silver.  
**Description:** Date dimension spanning 2010-01-01 to 2030-12-31. Provides calendar attributes for time-series analysis.

| Column         | Data Type      | Nullable | Description                                          |
| -------------- | -------------- | -------- | ---------------------------------------------------- |
| `date_key`     | `INT`          | NO       | Surrogate key in `YYYYMMDD` format (e.g. `20240315`) |
| `full_date`    | `DATE`         | NO       | Calendar date                                        |
| `year`         | `INT`          | NO       | Calendar year                                        |
| `quarter`      | `INT`          | NO       | Quarter number (1–4)                                 |
| `month`        | `INT`          | NO       | Month number (1–12)                                  |
| `month_name`   | `NVARCHAR(10)` | NO       | Month name (e.g. `'January'`)                        |
| `week_of_year` | `INT`          | NO       | ISO week number                                      |
| `day_of_week`  | `INT`          | NO       | Day of week (1 = Sunday per SQL Server default)      |
| `day_name`     | `NVARCHAR(10)` | NO       | Day name (e.g. `'Monday'`)                           |
| `is_weekend`   | `BIT`          | NO       | `1` if Saturday or Sunday, `0` otherwise             |

---

### `gold.fact_sales`

**Source:** `silver.crm_sales_details` JOIN `gold.dim_customers` JOIN `gold.dim_products` JOIN `gold.dim_date`  
**Description:** Sales fact table. One row per sales order line item.

| Column           | Data Type       | Nullable | Description                                                                             |
| ---------------- | --------------- | -------- | --------------------------------------------------------------------------------------- |
| `order_number`   | `NVARCHAR(50)`  | NO       | Sales order number (natural key)                                                        |
| `product_key`    | `INT`           | NO       | FK to `gold.dim_products.product_key`                                                   |
| `customer_key`   | `INT`           | NO       | FK to `gold.dim_customers.customer_key`; row is excluded from fact if unresolvable      |
| `order_date_key` | `INT`           | YES      | FK to `gold.dim_date.date_key` in `YYYYMMDD` format                                     |
| `ship_date_key`  | `INT`           | YES      | FK to `gold.dim_date.date_key` in `YYYYMMDD` format                                     |
| `due_date_key`   | `INT`           | YES      | FK to `gold.dim_date.date_key` in `YYYYMMDD` format                                     |
| `sales_amount`   | `DECIMAL(18,2)` | YES      | Total line amount; recalculated from `quantity × unit_price` if stored value is invalid |
| `quantity`       | `INT`           | YES      | Units ordered on this line item                                                         |
| `unit_price`     | `DECIMAL(18,2)` | YES      | Price per unit at the time of sale; derived from amount/quantity if missing             |

---

## Assumptions

1. The CRM system is authoritative for customer master data (name, marital status). Where CRM gender is `'Unknown'`, the ERP gender value is used as a fallback.
2. The CRM system is authoritative for product master data. ERP provides the product category hierarchy via `erp_px_cat_g1v2`.
3. Sales transactions from `crm_sales_details` are the authoritative source for `fact_sales`. ERP sales details exist for cross-validation only.
4. Products with a non-null `prd_end_dt` (discontinued) are excluded from `dim_products` but remain traceable in `fact_sales` via the natural key for historical orders.
5. Source CSV files are comma-delimited and UTF-8 encoded with a header row. File names are stable across load cycles.
6. The `dim_date` table spans 2010-01-01 to 2030-12-31 and is populated procedurally; it is not sourced from Bronze or Silver.

---

## Lineage Overview

```
CSV Source Files
     │  BULK INSERT (no transform)
     ▼
Bronze Tables  ────── etl_load_ts added
     │  Trim · Cast · Standardise · Deduplicate
     ▼
Silver Tables  ────── dwh_created_at / dwh_updated_at added
     │  JOIN across Silver tables · Surrogate key generation
     ▼
Gold Views / Tables  ── dim_customers · dim_products · dim_date · fact_sales
```
