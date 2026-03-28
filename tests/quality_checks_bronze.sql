/*
===============================================================================
Quality Checks - Bronze Layer
===============================================================================
Script Purpose:
    Validates source ingestion completeness and basic structural quality in
    Bronze tables after BULK INSERT.

Usage Notes:
    - Run after EXEC bronze.usp_bronze_load_all.
    - Investigate any non-empty result sets.
===============================================================================
*/

-- ====================================================================
-- Row Count Snapshot (all core Bronze tables should be > 0)
-- ====================================================================
SELECT 'bronze.crm_cust_info' AS table_name, COUNT(*) AS row_count FROM bronze.crm_cust_info
UNION ALL SELECT 'bronze.crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
UNION ALL SELECT 'bronze.crm_sales_details', COUNT(*) FROM bronze.crm_sales_details
UNION ALL SELECT 'bronze.erp_cust_az12', COUNT(*) FROM bronze.erp_cust_az12
UNION ALL SELECT 'bronze.erp_loc_a101', COUNT(*) FROM bronze.erp_loc_a101
UNION ALL SELECT 'bronze.erp_px_cat_g1v2', COUNT(*) FROM bronze.erp_px_cat_g1v2;

-- ====================================================================
-- Primary Identifier Null Checks
-- Expectation: 0 rows returned per query
-- ====================================================================
SELECT *
FROM bronze.crm_cust_info
WHERE cst_id IS NULL;

SELECT *
FROM bronze.crm_prd_info
WHERE prd_id IS NULL;

SELECT *
FROM bronze.erp_cust_az12
WHERE cid IS NULL OR TRIM(cid) = '';

SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE id IS NULL OR TRIM(id) = '';

-- ====================================================================
-- CRM Sales Date Shape Check (YYYYMMDD as INT)
-- Expectation: 0 rows
-- ====================================================================
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt IS NULL
   OR LEN(CAST(sls_order_dt AS VARCHAR(20))) <> 8
   OR sls_order_dt < 19000101
   OR sls_order_dt > 20500101;

-- ====================================================================
-- Basic Numeric Non-Negative Checks
-- Expectation: 0 rows
-- ====================================================================
SELECT *
FROM bronze.crm_sales_details
WHERE sls_sales < 0
   OR sls_quantity < 0
   OR sls_price < 0;
