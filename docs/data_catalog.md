# Data Catalog

Version: 1.1  
Status: Approved  
Last Updated: 2026-03-28  
Database: DataWarehouse

This catalog documents the implemented warehouse objects across Bronze, Silver, and Gold layers.

---

## Layer Summary

| Layer  | Schema | Object Count | Physical Type     | Load Mechanism            |
| ------ | ------ | ------------ | ----------------- | ------------------------- |
| Bronze | bronze | 6 tables     | Base tables       | `EXEC bronze.load_bronze` |
| Silver | silver | 6 tables     | Base tables       | `EXEC silver.load_silver` |
| Gold   | gold   | 3 views      | Star-schema views | Query-time (view-based)   |

---

## Bronze Layer

Bronze stores raw source data from CSV files with no cleansing logic.

### bronze.crm_cust_info

Source file: datasets/source_crm/cust_info.csv

| Column             | Data Type    | Description                    |
| ------------------ | ------------ | ------------------------------ |
| cst_id             | INT          | CRM customer identifier        |
| cst_key            | NVARCHAR(50) | Cross-system customer key      |
| cst_firstname      | NVARCHAR(50) | Customer first name            |
| cst_lastname       | NVARCHAR(50) | Customer last name             |
| cst_marital_status | NVARCHAR(50) | Raw marital status code        |
| cst_gndr           | NVARCHAR(50) | Raw gender code                |
| cst_create_date    | DATE         | Record create date from source |

### bronze.crm_prd_info

Source file: datasets/source_crm/prd_info.csv

| Column       | Data Type    | Description                            |
| ------------ | ------------ | -------------------------------------- |
| prd_id       | INT          | CRM product identifier                 |
| prd_key      | NVARCHAR(50) | Product code including category prefix |
| prd_nm       | NVARCHAR(50) | Product name                           |
| prd_cost     | INT          | Product cost                           |
| prd_line     | NVARCHAR(50) | Product line code                      |
| prd_start_dt | DATETIME     | Product effective start timestamp      |
| prd_end_dt   | DATETIME     | Product effective end timestamp        |

### bronze.crm_sales_details

Source file: datasets/source_crm/sales_details.csv

| Column       | Data Type    | Description                           |
| ------------ | ------------ | ------------------------------------- |
| sls_ord_num  | NVARCHAR(50) | Sales order number                    |
| sls_prd_key  | NVARCHAR(50) | Product key                           |
| sls_cust_id  | INT          | Customer identifier                   |
| sls_order_dt | INT          | Order date in YYYYMMDD numeric format |
| sls_ship_dt  | INT          | Ship date in YYYYMMDD numeric format  |
| sls_due_dt   | INT          | Due date in YYYYMMDD numeric format   |
| sls_sales    | INT          | Sales amount                          |
| sls_quantity | INT          | Quantity sold                         |
| sls_price    | INT          | Unit price                            |

### bronze.erp_cust_az12

Source file: datasets/source_erp/CUST_AZ12.csv

| Column | Data Type    | Description             |
| ------ | ------------ | ----------------------- |
| cid    | NVARCHAR(50) | ERP customer identifier |
| bdate  | DATE         | Birth date              |
| gen    | NVARCHAR(50) | Raw gender code         |

### bronze.erp_loc_a101

Source file: datasets/source_erp/LOC_A101.csv

| Column | Data Type    | Description             |
| ------ | ------------ | ----------------------- |
| cid    | NVARCHAR(50) | ERP customer identifier |
| cntry  | NVARCHAR(50) | Raw country value       |

### bronze.erp_px_cat_g1v2

Source file: datasets/source_erp/PX_CAT_G1V2.csv

| Column      | Data Type    | Description         |
| ----------- | ------------ | ------------------- |
| id          | NVARCHAR(50) | Category identifier |
| cat         | NVARCHAR(50) | Category            |
| subcat      | NVARCHAR(50) | Subcategory         |
| maintenance | NVARCHAR(50) | Maintenance flag    |

---

## Silver Layer

Silver applies cleansing, deduplication, standardization, and type alignment. Every Silver table has `dwh_create_date DATETIME2 DEFAULT GETDATE()`.

### silver.crm_cust_info

| Column             | Data Type    | Description                             |
| ------------------ | ------------ | --------------------------------------- |
| cst_id             | INT          | Deduplicated customer identifier        |
| cst_key            | NVARCHAR(50) | Cross-system customer key               |
| cst_firstname      | NVARCHAR(50) | Trimmed first name                      |
| cst_lastname       | NVARCHAR(50) | Trimmed last name                       |
| cst_marital_status | NVARCHAR(50) | Standardized to Single, Married, or n/a |
| cst_gndr           | NVARCHAR(50) | Standardized to Male, Female, or n/a    |
| cst_create_date    | DATE         | Source create date                      |
| dwh_create_date    | DATETIME2    | Warehouse load timestamp                |

### silver.crm_prd_info

| Column          | Data Type    | Description                               |
| --------------- | ------------ | ----------------------------------------- |
| prd_id          | INT          | Product identifier                        |
| cat_id          | NVARCHAR(50) | Derived category code from prd_key prefix |
| prd_key         | NVARCHAR(50) | Product key with category prefix removed  |
| prd_nm          | NVARCHAR(50) | Trimmed product name                      |
| prd_cost        | INT          | Product cost with null handling           |
| prd_line        | NVARCHAR(50) | Standardized line label                   |
| prd_start_dt    | DATE         | Product start date                        |
| prd_end_dt      | DATE         | Derived end date using LEAD window logic  |
| dwh_create_date | DATETIME2    | Warehouse load timestamp                  |

### silver.crm_sales_details

| Column          | Data Type    | Description                  |
| --------------- | ------------ | ---------------------------- |
| sls_ord_num     | NVARCHAR(50) | Sales order number           |
| sls_prd_key     | NVARCHAR(50) | Product key                  |
| sls_cust_id     | INT          | Customer identifier          |
| sls_order_dt    | DATE         | Converted from YYYYMMDD      |
| sls_ship_dt     | DATE         | Converted from YYYYMMDD      |
| sls_due_dt      | DATE         | Converted from YYYYMMDD      |
| sls_sales       | INT          | Recalculated if inconsistent |
| sls_quantity    | INT          | Quantity                     |
| sls_price       | INT          | Corrected price if invalid   |
| dwh_create_date | DATETIME2    | Warehouse load timestamp     |

### silver.erp_cust_az12

| Column          | Data Type    | Description                            |
| --------------- | ------------ | -------------------------------------- |
| cid             | NVARCHAR(50) | Customer id with NAS prefix removed    |
| bdate           | DATE         | Birth date with future dates nullified |
| gen             | NVARCHAR(50) | Standardized gender                    |
| dwh_create_date | DATETIME2    | Warehouse load timestamp               |

### silver.erp_loc_a101

| Column          | Data Type    | Description                     |
| --------------- | ------------ | ------------------------------- |
| cid             | NVARCHAR(50) | Customer id with dashes removed |
| cntry           | NVARCHAR(50) | Standardized country name       |
| dwh_create_date | DATETIME2    | Warehouse load timestamp        |

### silver.erp_px_cat_g1v2

| Column          | Data Type    | Description              |
| --------------- | ------------ | ------------------------ |
| id              | NVARCHAR(50) | Category identifier      |
| cat             | NVARCHAR(50) | Category                 |
| subcat          | NVARCHAR(50) | Subcategory              |
| maintenance     | NVARCHAR(50) | Maintenance attribute    |
| dwh_create_date | DATETIME2    | Warehouse load timestamp |

---

## Gold Layer

Gold is implemented as views in a star-schema style model.

### gold.dim_customers (view)

Source: silver.crm_cust_info + silver.erp_cust_az12 + silver.erp_loc_a101

| Column          | Data Type    | Description                           |
| --------------- | ------------ | ------------------------------------- |
| customer_key    | BIGINT       | Surrogate key generated by ROW_NUMBER |
| customer_id     | INT          | Natural customer key                  |
| customer_number | NVARCHAR(50) | Cross-system customer number          |
| first_name      | NVARCHAR(50) | Customer first name                   |
| last_name       | NVARCHAR(50) | Customer last name                    |
| country         | NVARCHAR(50) | Standardized country                  |
| marital_status  | NVARCHAR(50) | Standardized marital status           |
| gender          | NVARCHAR(50) | CRM-first, ERP-fallback gender        |
| birthdate       | DATE         | Birth date                            |
| create_date     | DATE         | CRM create date                       |

### gold.dim_products (view)

Source: silver.crm_prd_info + silver.erp_px_cat_g1v2

| Column         | Data Type    | Description                           |
| -------------- | ------------ | ------------------------------------- |
| product_key    | BIGINT       | Surrogate key generated by ROW_NUMBER |
| product_id     | INT          | Natural product key                   |
| product_number | NVARCHAR(50) | Product number                        |
| product_name   | NVARCHAR(50) | Product name                          |
| category_id    | NVARCHAR(50) | Category key                          |
| category       | NVARCHAR(50) | Category label                        |
| subcategory    | NVARCHAR(50) | Subcategory label                     |
| maintenance    | NVARCHAR(50) | Maintenance attribute                 |
| cost           | INT          | Product cost                          |
| product_line   | NVARCHAR(50) | Product line                          |
| start_date     | DATE         | Product start date                    |

### gold.fact_sales (view)

Source: silver.crm_sales_details + gold.dim_products + gold.dim_customers

| Column        | Data Type    | Description            |
| ------------- | ------------ | ---------------------- |
| order_number  | NVARCHAR(50) | Sales order number     |
| product_key   | BIGINT       | Product surrogate key  |
| customer_key  | BIGINT       | Customer surrogate key |
| order_date    | DATE         | Order date             |
| shipping_date | DATE         | Shipping date          |
| due_date      | DATE         | Due date               |
| sales_amount  | INT          | Line sales amount      |
| quantity      | INT          | Quantity sold          |
| price         | INT          | Unit price             |

---

## Notes

- Gold is currently view-based; no physical Gold fact/dimension table load is required.
- `gold.dim_date` is not part of the current implementation.
- ETL execution details and row counts are captured in `etl.load_log`.
