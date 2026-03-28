/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    Creates all six tables in the 'silver' schema, dropping and recreating
    each if it already exists. Silver tables receive cleansed, typed, and
    deduplicated data from the Bronze layer.

    Key differences from Bronze:
    - Proper SQL Server types (DATE instead of INT for dates, etc.)
    - Added cat_id column in crm_prd_info (derived from prd_key prefix)
    - dwh_create_date audit column on every table (DATETIME2, default GETDATE())

Execution Order:
    5 of 8  —  Run after bronze layer scripts.

Dependencies:
    The 'silver' schema must exist (created by scripts/init_database.sql).

Notes:
    Safe to re-run. Drops and recreates each table individually.
===============================================================================
*/

USE DataWarehouse;
GO

-- =============================================================================
-- CRM Tables
-- =============================================================================

IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id             INT,
    cst_key            NVARCHAR(50),
    cst_firstname      NVARCHAR(50),
    cst_lastname       NVARCHAR(50),
    cst_marital_status NVARCHAR(50),   -- 'Single' | 'Married' | 'n/a'
    cst_gndr           NVARCHAR(50),   -- 'Male' | 'Female' | 'n/a'
    cst_create_date    DATE,
    dwh_create_date    DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),  -- Extracted from first 5 chars of prd_key, e.g. 'CO_RF'
    prd_key         NVARCHAR(50),  -- Remainder of prd_key after category prefix
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),  -- 'Mountain' | 'Road' | 'Touring' | 'Other Sales' | 'n/a'
    prd_start_dt    DATE,
    prd_end_dt      DATE,          -- NULL = current/active record
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),
    sls_prd_key     NVARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    DATE,
    sls_ship_dt     DATE,
    sls_due_dt      DATE,
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

-- =============================================================================
-- ERP Tables
-- =============================================================================

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid             NVARCHAR(50),  -- 'NAS' prefix removed; matches crm_cust_info.cst_key
    bdate           DATE,          -- Future dates set to NULL
    gen             NVARCHAR(50),  -- 'Male' | 'Female' | 'n/a'
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid             NVARCHAR(50),  -- Dashes removed; matches crm_cust_info.cst_key
    cntry           NVARCHAR(50),  -- Normalised: 'United States' | 'Germany' | etc.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id              NVARCHAR(50),  -- Category ID; joins to crm_prd_info.cat_id
    cat             NVARCHAR(50),
    subcat          NVARCHAR(50),
    maintenance     NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO
