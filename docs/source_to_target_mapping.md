# Source-to-Target Mapping

Version: 1.1  
Status: Approved  
Last Updated: 2026-03-28

This document defines column-level lineage from source CSV files to Bronze, Silver, and Gold objects implemented in this repository.

---

## Mapping Scope

| Part | Flow                 | Implementation                      |
| ---- | -------------------- | ----------------------------------- |
| 1    | Source CSV -> Bronze | BULK INSERT in `bronze.load_bronze` |
| 2    | Bronze -> Silver     | Cleansing in `silver.load_silver`   |
| 3    | Silver -> Gold       | View logic in `gold.ddl_gold`       |

---

## Part 1: Source CSV -> Bronze

Bronze is a raw copy of source files mapped by file structure and column order. No derived audit column is added in Bronze tables.

### ERP: CUST_AZ12.csv -> bronze.erp_cust_az12

| Source Column | Bronze Column | Transformation |
| ------------- | ------------- | -------------- |
| CID           | cid           | Direct copy    |
| BDATE         | bdate         | Direct copy    |
| GEN           | gen           | Direct copy    |

### ERP: LOC_A101.csv -> bronze.erp_loc_a101

| Source Column | Bronze Column | Transformation |
| ------------- | ------------- | -------------- |
| CID           | cid           | Direct copy    |
| CNTRY         | cntry         | Direct copy    |

### ERP: PX_CAT_G1V2.csv -> bronze.erp_px_cat_g1v2

| Source Column | Bronze Column | Transformation |
| ------------- | ------------- | -------------- |
| ID            | id            | Direct copy    |
| CAT           | cat           | Direct copy    |
| SUBCAT        | subcat        | Direct copy    |
| MAINTENANCE   | maintenance   | Direct copy    |

### CRM: cust_info.csv -> bronze.crm_cust_info

| Source Column      | Bronze Column      | Transformation |
| ------------------ | ------------------ | -------------- |
| cst_id             | cst_id             | Direct copy    |
| cst_key            | cst_key            | Direct copy    |
| cst_firstname      | cst_firstname      | Direct copy    |
| cst_lastname       | cst_lastname       | Direct copy    |
| cst_marital_status | cst_marital_status | Direct copy    |
| cst_gndr           | cst_gndr           | Direct copy    |
| cst_create_date    | cst_create_date    | Direct copy    |

### CRM: prd_info.csv -> bronze.crm_prd_info

| Source Column | Bronze Column | Transformation |
| ------------- | ------------- | -------------- |
| prd_id        | prd_id        | Direct copy    |
| prd_key       | prd_key       | Direct copy    |
| prd_nm        | prd_nm        | Direct copy    |
| prd_cost      | prd_cost      | Direct copy    |
| prd_line      | prd_line      | Direct copy    |
| prd_start_dt  | prd_start_dt  | Direct copy    |
| prd_end_dt    | prd_end_dt    | Direct copy    |

### CRM: sales_details.csv -> bronze.crm_sales_details

| Source Column | Bronze Column | Transformation |
| ------------- | ------------- | -------------- |
| sls_ord_num   | sls_ord_num   | Direct copy    |
| sls_prd_key   | sls_prd_key   | Direct copy    |
| sls_cust_id   | sls_cust_id   | Direct copy    |
| sls_order_dt  | sls_order_dt  | Direct copy    |
| sls_ship_dt   | sls_ship_dt   | Direct copy    |
| sls_due_dt    | sls_due_dt    | Direct copy    |
| sls_sales     | sls_sales     | Direct copy    |
| sls_quantity  | sls_quantity  | Direct copy    |
| sls_price     | sls_price     | Direct copy    |

---

## Part 2: Bronze -> Silver

### bronze.crm_cust_info -> silver.crm_cust_info

| Bronze Column      | Silver Column      | Transformation Rule                                                               |
| ------------------ | ------------------ | --------------------------------------------------------------------------------- |
| cst_id             | cst_id             | Keep latest row per `cst_id` via `ROW_NUMBER()` ordered by `cst_create_date DESC` |
| cst_key            | cst_key            | Pass-through                                                                      |
| cst_firstname      | cst_firstname      | `TRIM(cst_firstname)`                                                             |
| cst_lastname       | cst_lastname       | `TRIM(cst_lastname)`                                                              |
| cst_marital_status | cst_marital_status | `S -> Single`, `M -> Married`, else `n/a`                                         |
| cst_gndr           | cst_gndr           | `F -> Female`, `M -> Male`, else `n/a`                                            |
| cst_create_date    | cst_create_date    | Pass-through                                                                      |
| generated          | dwh_create_date    | Default `GETDATE()`                                                               |

### bronze.crm_prd_info -> silver.crm_prd_info

| Bronze Column | Silver Column   | Transformation Rule                                        |
| ------------- | --------------- | ---------------------------------------------------------- |
| prd_id        | prd_id          | Pass-through                                               |
| prd_key       | cat_id          | `REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')`              |
| prd_key       | prd_key         | `SUBSTRING(prd_key, 7, LEN(prd_key))`                      |
| prd_nm        | prd_nm          | `TRIM(prd_nm)`                                             |
| prd_cost      | prd_cost        | `ISNULL(prd_cost, 0)`                                      |
| prd_line      | prd_line        | `M/R/S/T -> Mountain/Road/Other Sales/Touring`, else `n/a` |
| prd_start_dt  | prd_start_dt    | `CAST(prd_start_dt AS DATE)`                               |
| prd_start_dt  | prd_end_dt      | `LEAD(prd_start_dt)-1 day` per `prd_key`                   |
| generated     | dwh_create_date | Default `GETDATE()`                                        |

### bronze.crm_sales_details -> silver.crm_sales_details

| Bronze Column | Silver Column   | Transformation Rule                                                       |
| ------------- | --------------- | ------------------------------------------------------------------------- |
| sls_ord_num   | sls_ord_num     | Pass-through                                                              |
| sls_prd_key   | sls_prd_key     | Pass-through                                                              |
| sls_cust_id   | sls_cust_id     | Pass-through                                                              |
| sls_order_dt  | sls_order_dt    | If valid 8-digit integer and not 0, cast to DATE; else NULL               |
| sls_ship_dt   | sls_ship_dt     | If valid 8-digit integer and not 0, cast to DATE; else NULL               |
| sls_due_dt    | sls_due_dt      | If valid 8-digit integer and not 0, cast to DATE; else NULL               |
| sls_sales     | sls_sales       | Recalculate to `sls_quantity * ABS(sls_price)` if invalid or inconsistent |
| sls_quantity  | sls_quantity    | Pass-through                                                              |
| sls_price     | sls_price       | If invalid, derive `sls_sales / NULLIF(sls_quantity,0)`                   |
| generated     | dwh_create_date | Default `GETDATE()`                                                       |

### bronze.erp_cust_az12 -> silver.erp_cust_az12

| Bronze Column | Silver Column   | Transformation Rule            |
| ------------- | --------------- | ------------------------------ |
| cid           | cid             | Remove NAS prefix when present |
| bdate         | bdate           | Set to NULL if future date     |
| gen           | gen             | Standardize to Male/Female/n/a |
| generated     | dwh_create_date | Default `GETDATE()`            |

### bronze.erp_loc_a101 -> silver.erp_loc_a101

| Bronze Column | Silver Column   | Transformation Rule                                             |
| ------------- | --------------- | --------------------------------------------------------------- |
| cid           | cid             | `REPLACE(cid, '-', '')`                                         |
| cntry         | cntry           | `DE -> Germany`, `US/USA -> United States`, blank/null -> `n/a` |
| generated     | dwh_create_date | Default `GETDATE()`                                             |

### bronze.erp_px_cat_g1v2 -> silver.erp_px_cat_g1v2

| Bronze Column | Silver Column   | Transformation Rule |
| ------------- | --------------- | ------------------- |
| id            | id              | Pass-through        |
| cat           | cat             | Pass-through        |
| subcat        | subcat          | Pass-through        |
| maintenance   | maintenance     | Pass-through        |
| generated     | dwh_create_date | Default `GETDATE()` |

---

## Part 3: Silver -> Gold

Gold objects are views.

### silver.\* -> gold.dim_customers

| Silver Source                               | Silver Column      | Gold Column     | Rule                                      |
| ------------------------------------------- | ------------------ | --------------- | ----------------------------------------- |
| silver.crm_cust_info                        | row_number         | customer_key    | `ROW_NUMBER() OVER (ORDER BY cst_id)`     |
| silver.crm_cust_info                        | cst_id             | customer_id     | Pass-through                              |
| silver.crm_cust_info                        | cst_key            | customer_number | Pass-through                              |
| silver.crm_cust_info                        | cst_firstname      | first_name      | Pass-through                              |
| silver.crm_cust_info                        | cst_lastname       | last_name       | Pass-through                              |
| silver.erp_loc_a101                         | cntry              | country         | Join on `ci.cst_key = la.cid`             |
| silver.crm_cust_info                        | cst_marital_status | marital_status  | Pass-through                              |
| silver.crm_cust_info + silver.erp_cust_az12 | cst_gndr + gen     | gender          | Use CRM when not `n/a`; else ERP fallback |
| silver.erp_cust_az12                        | bdate              | birthdate       | Join on `ci.cst_key = ca.cid`             |
| silver.crm_cust_info                        | cst_create_date    | create_date     | Pass-through                              |

### silver.\* -> gold.dim_products

| Silver Source          | Silver Column | Gold Column    | Rule                                                 |
| ---------------------- | ------------- | -------------- | ---------------------------------------------------- |
| silver.crm_prd_info    | row_number    | product_key    | `ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key)` |
| silver.crm_prd_info    | prd_id        | product_id     | Pass-through                                         |
| silver.crm_prd_info    | prd_key       | product_number | Pass-through                                         |
| silver.crm_prd_info    | prd_nm        | product_name   | Pass-through                                         |
| silver.crm_prd_info    | cat_id        | category_id    | Pass-through                                         |
| silver.erp_px_cat_g1v2 | cat           | category       | Join on `pn.cat_id = pc.id`                          |
| silver.erp_px_cat_g1v2 | subcat        | subcategory    | Pass-through                                         |
| silver.erp_px_cat_g1v2 | maintenance   | maintenance    | Pass-through                                         |
| silver.crm_prd_info    | prd_cost      | cost           | Pass-through                                         |
| silver.crm_prd_info    | prd_line      | product_line   | Pass-through                                         |
| silver.crm_prd_info    | prd_start_dt  | start_date     | Pass-through                                         |

Filter: include only rows where `pn.prd_end_dt IS NULL`.

### silver.crm_sales_details -> gold.fact_sales

| Source                   | Source Column | Gold Column   | Rule                                      |
| ------------------------ | ------------- | ------------- | ----------------------------------------- |
| silver.crm_sales_details | sls_ord_num   | order_number  | Pass-through                              |
| gold.dim_products        | product_key   | product_key   | Join `sd.sls_prd_key = pr.product_number` |
| gold.dim_customers       | customer_key  | customer_key  | Join `sd.sls_cust_id = cu.customer_id`    |
| silver.crm_sales_details | sls_order_dt  | order_date    | Pass-through                              |
| silver.crm_sales_details | sls_ship_dt   | shipping_date | Pass-through                              |
| silver.crm_sales_details | sls_due_dt    | due_date      | Pass-through                              |
| silver.crm_sales_details | sls_sales     | sales_amount  | Pass-through                              |
| silver.crm_sales_details | sls_quantity  | quantity      | Pass-through                              |
| silver.crm_sales_details | sls_price     | price         | Pass-through                              |

---

## Lineage Summary

Source CSV files  
-> Bronze raw tables (6)  
-> Silver cleansed tables (6)  
-> Gold analytics views (dim_customers, dim_products, fact_sales)
