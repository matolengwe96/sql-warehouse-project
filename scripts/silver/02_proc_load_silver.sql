/*
===============================================================================
Stored Procedure: Load Silver Layer  (Bronze -> Silver)
===============================================================================
Script Purpose:
    Transforms and loads all six Silver tables from their Bronze counterparts.
    Performs a full truncate-and-reload on every execution.

    Transformations applied per table:
    ┌──────────────────────────┬───────────────────────────────────────────────┐
    │ Table                    │ Key transformations                           │
    ├──────────────────────────┼───────────────────────────────────────────────┤
    │ crm_cust_info            │ Dedup by cst_id (keep latest create_date);    │
    │                          │ Normalise gender (M/F → Male/Female);         │
    │                          │ Normalise marital status (S/M → Single/Married│
    ├──────────────────────────┼───────────────────────────────────────────────┤
    │ crm_prd_info             │ Extract cat_id from prd_key prefix;           │
    │                          │ Strip cat prefix from prd_key;                │
    │                          │ Normalise product line codes;                 │
    │                          │ LEAD() to derive prd_end_dt (SCD Type 2);     │
    │                          │ ISNULL(prd_cost, 0)                           │
    ├──────────────────────────┼───────────────────────────────────────────────┤
    │ crm_sales_details        │ Cast YYYYMMDD INT dates → DATE;               │
    │                          │ Recalculate sls_sales where inconsistent;     │
    │                          │ Derive sls_price from sales/qty when invalid  │
    ├──────────────────────────┼───────────────────────────────────────────────┤
    │ erp_cust_az12            │ Remove 'NAS' prefix from cid;                 │
    │                          │ Set future birthdates to NULL;                │
    │                          │ Normalise gender abbreviations                │
    ├──────────────────────────┼───────────────────────────────────────────────┤
    │ erp_loc_a101             │ Remove dashes from cid;                       │
    │                          │ Normalise country codes (DE → Germany, etc.)  │
    ├──────────────────────────┼───────────────────────────────────────────────┤
    │ erp_px_cat_g1v2          │ Loaded as-is (already clean in Bronze)        │
    └──────────────────────────┴───────────────────────────────────────────────┘

    Enterprise additions vs. baseline:
    - Writes per-table metadata to etl.load_log.
    - Structured console output with row count and duration per table.
    - Propagates exceptions via THROW after logging failure status.

Execution Order:
    6 of 8  —  Run after silver/01_ddl_silver_tables.sql.

Parameters:
    None.

Usage:
    EXEC silver.load_silver;

Dependencies:
    - etl.load_log          (scripts/etl/01_ddl_etl_log.sql)
    - Silver tables         (scripts/silver/01_ddl_silver_tables.sql)
    - Bronze tables loaded  (EXEC bronze.load_bronze)
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @batch_id    UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time  DATETIME;
    DECLARE @end_time    DATETIME;
    DECLARE @batch_start DATETIME         = GETDATE();
    DECLARE @row_count   INT;

    BEGIN TRY

        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT 'Batch    : ' + CAST(@batch_id AS NVARCHAR(50));
        PRINT 'Started  : ' + CONVERT(NVARCHAR, @batch_start, 120);
        PRINT '================================================';

        -- -------------------------------------------------------------------
        -- CRM Tables
        -- -------------------------------------------------------------------
        PRINT '';
        PRINT '--- CRM Tables ---';

        -- silver.crm_cust_info -----------------------------------------------
        -- Deduplicates on cst_id, keeping the most recently created record.
        -- Normalises gender and marital_status to full readable values.
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Silver', 'silver.crm_cust_info', @start_time, 'Running');

        TRUNCATE TABLE silver.crm_cust_info;
        INSERT INTO silver.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE flag_last = 1;
        SET @row_count = @@ROWCOUNT;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'silver.crm_cust_info';
        PRINT '  silver.crm_cust_info      | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- silver.crm_prd_info ------------------------------------------------
        -- Extracts cat_id from prd_key prefix (e.g. 'CO-RF' -> 'CO_RF').
        -- Strips the category prefix from prd_key, leaving the product SKU.
        -- Derives prd_end_dt via LEAD() — NULL on the current/active record.
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Silver', 'silver.crm_prd_info', @start_time, 'Running');

        TRUNCATE TABLE silver.crm_prd_info;
        INSERT INTO silver.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost,
            prd_line, prd_start_dt, prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')          AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key))                   AS prd_key,
            TRIM(prd_nm)                                           AS prd_nm,
            ISNULL(prd_cost, 0)                                    AS prd_cost,
            CASE
                WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                ELSE 'n/a'
            END                                                    AS prd_line,
            CAST(prd_start_dt AS DATE)                             AS prd_start_dt,
            CAST(
                DATEADD(DAY, -1,
                    LEAD(prd_start_dt) OVER (
                        PARTITION BY prd_key ORDER BY prd_start_dt
                    )
                ) AS DATE
            )                                                      AS prd_end_dt
        FROM bronze.crm_prd_info;
        SET @row_count = @@ROWCOUNT;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'silver.crm_prd_info';
        PRINT '  silver.crm_prd_info       | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- silver.crm_sales_details -------------------------------------------
        -- Casts YYYYMMDD integer dates to DATE; invalid/zero values become NULL.
        -- Recalculates sls_sales = qty * |price| if the original is inconsistent.
        -- Derives sls_price from sales/qty when original price is invalid.
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Silver', 'silver.crm_sales_details', @start_time, 'Running');

        TRUNCATE TABLE silver.crm_sales_details;
        INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id,
            sls_order_dt, sls_ship_dt, sls_due_dt,
            sls_sales, sls_quantity, sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            CASE
                WHEN sls_sales IS NULL OR sls_sales <= 0
                  OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE
                WHEN sls_price IS NULL OR sls_price <= 0
                    THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;
        SET @row_count = @@ROWCOUNT;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'silver.crm_sales_details';
        PRINT '  silver.crm_sales_details  | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- -------------------------------------------------------------------
        -- ERP Tables
        -- -------------------------------------------------------------------
        PRINT '';
        PRINT '--- ERP Tables ---';

        -- silver.erp_cust_az12 -----------------------------------------------
        -- Removes 'NAS' prefix so cid matches crm_cust_info.cst_key.
        -- Nullifies future birthdates (data quality issue in source).
        -- Normalises gender abbreviations to full words.
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Silver', 'silver.erp_cust_az12', @start_time, 'Running');

        TRUNCATE TABLE silver.erp_cust_az12;
        INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
        SELECT
            CASE
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,
            CASE
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;
        SET @row_count = @@ROWCOUNT;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'silver.erp_cust_az12';
        PRINT '  silver.erp_cust_az12      | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- silver.erp_loc_a101 ------------------------------------------------
        -- Removes dashes from cid so it matches crm_cust_info.cst_key.
        -- Normalises country values (abbreviations and alternate spellings).
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Silver', 'silver.erp_loc_a101', @start_time, 'Running');

        TRUNCATE TABLE silver.erp_loc_a101;
        INSERT INTO silver.erp_loc_a101 (cid, cntry)
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE
                WHEN TRIM(cntry) = 'DE'           THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) = ''
                  OR cntry IS NULL               THEN 'n/a'
                ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;
        SET @row_count = @@ROWCOUNT;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'silver.erp_loc_a101';
        PRINT '  silver.erp_loc_a101       | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- silver.erp_px_cat_g1v2 ---------------------------------------------
        -- Clean in source; loaded as-is. dwh_create_date populated by default.
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Silver', 'silver.erp_px_cat_g1v2', @start_time, 'Running');

        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
        SELECT id, cat, subcat, maintenance
        FROM   bronze.erp_px_cat_g1v2;
        SET @row_count = @@ROWCOUNT;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'silver.erp_px_cat_g1v2';
        PRINT '  silver.erp_px_cat_g1v2    | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- -------------------------------------------------------------------
        -- Batch summary
        -- -------------------------------------------------------------------
        PRINT '';
        PRINT '================================================';
        PRINT 'Silver Load Completed';
        PRINT 'Total Duration : '
            + CAST(DATEDIFF(SECOND, @batch_start, GETDATE()) AS NVARCHAR) + 's';
        PRINT 'Audit Query    : SELECT * FROM etl.load_log WHERE batch_id = '''
            + CAST(@batch_id AS NVARCHAR(50)) + '''';
        PRINT '================================================';

    END TRY
    BEGIN CATCH

        UPDATE etl.load_log
        SET    end_time          = GETDATE(),
               duration_seconds  = DATEDIFF(SECOND, start_time, GETDATE()),
               status            = 'Failed',
               error_message     = ERROR_MESSAGE()
        WHERE  batch_id = @batch_id
        AND    status   = 'Running';

        PRINT '================================================';
        PRINT 'SILVER LOAD FAILED';
        PRINT 'Error  : ' + ERROR_MESSAGE();
        PRINT 'Audit  : SELECT * FROM etl.load_log WHERE batch_id = '''
            + CAST(@batch_id AS NVARCHAR(50)) + '''';
        PRINT '================================================';

        THROW;

    END CATCH;
END;
GO
