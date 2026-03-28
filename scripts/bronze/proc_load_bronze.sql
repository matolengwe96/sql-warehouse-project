/*
===============================================================================
Stored Procedure: Load Bronze Layer  (Source CSV -> Bronze)
===============================================================================
Script Purpose:
    Loads all six Bronze tables from source CSV files using BULK INSERT.
    Performs a full truncate-and-reload on every execution.

    Enterprise additions vs. baseline:
    - Writes per-table metadata to etl.load_log (batch_id, row count,
      timing, status, error message).
    - Single configurable path variable — update once at the top of the proc.
    - Structured console output: layer, table, row count, duration per table.
    - Propagates exceptions via THROW after marking the failed table in the
      audit log — caller or SQL Agent job receives the original error.

Configuration:
    Update @csv_path_crm and @csv_path_erp (lines ~50-51) to match the
    folder where you copied the source CSVs. The SQL Server service account
    must have read access to those paths.

    Example:
        @csv_path_crm = 'C:\sql\dwh\datasets\source_crm\'
        @csv_path_erp = 'C:\sql\dwh\datasets\source_erp\'

Execution Order:
    4 of 8  —  Run after 03_bronze/01_ddl_bronze_tables.sql.

Parameters:
    None.

Usage:
    EXEC bronze.load_bronze;

Dependencies:
    - etl schema and etl.load_log table (scripts/etl/01_ddl_etl_log.sql)
    - Bronze tables              (scripts/bronze/01_ddl_bronze_tables.sql)
    - CSV files at the configured path
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    SET NOCOUNT ON;

    -- =========================================================================
    -- CONFIGURATION — Update these two paths before first execution
    -- =========================================================================
    DECLARE @csv_path_crm NVARCHAR(500) = 'C:\sql\dwh\datasets\source_crm\';
    DECLARE @csv_path_erp NVARCHAR(500) = 'C:\sql\dwh\datasets\source_erp\';
    -- =========================================================================

    DECLARE @batch_id    UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time  DATETIME;
    DECLARE @end_time    DATETIME;
    DECLARE @batch_start DATETIME         = GETDATE();
    DECLARE @row_count   INT;
    DECLARE @sql         NVARCHAR(MAX);

    BEGIN TRY

        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT 'Batch    : ' + CAST(@batch_id AS NVARCHAR(50));
        PRINT 'Started  : ' + CONVERT(NVARCHAR, @batch_start, 120);
        PRINT '================================================';

        -- -------------------------------------------------------------------
        -- CRM Tables
        -- -------------------------------------------------------------------
        PRINT '';
        PRINT '--- CRM Tables ---';

        -- bronze.crm_cust_info -----------------------------------------------
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Bronze', 'bronze.crm_cust_info', @start_time, 'Running');

        TRUNCATE TABLE bronze.crm_cust_info;
        SET @sql = N'BULK INSERT bronze.crm_cust_info FROM '
                 + CHAR(39) + @csv_path_crm + N'cust_info.csv'     + CHAR(39)
                 + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '
                 + CHAR(39) + N',' + CHAR(39) + N', TABLOCK)';
        EXEC sp_executesql @sql;
        SELECT @row_count = COUNT(1) FROM bronze.crm_cust_info;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'bronze.crm_cust_info';
        PRINT '  bronze.crm_cust_info     | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- bronze.crm_prd_info ------------------------------------------------
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Bronze', 'bronze.crm_prd_info', @start_time, 'Running');

        TRUNCATE TABLE bronze.crm_prd_info;
        SET @sql = N'BULK INSERT bronze.crm_prd_info FROM '
                 + CHAR(39) + @csv_path_crm + N'prd_info.csv'      + CHAR(39)
                 + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '
                 + CHAR(39) + N',' + CHAR(39) + N', TABLOCK)';
        EXEC sp_executesql @sql;
        SELECT @row_count = COUNT(1) FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'bronze.crm_prd_info';
        PRINT '  bronze.crm_prd_info      | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- bronze.crm_sales_details -------------------------------------------
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Bronze', 'bronze.crm_sales_details', @start_time, 'Running');

        TRUNCATE TABLE bronze.crm_sales_details;
        SET @sql = N'BULK INSERT bronze.crm_sales_details FROM '
                 + CHAR(39) + @csv_path_crm + N'sales_details.csv' + CHAR(39)
                 + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '
                 + CHAR(39) + N',' + CHAR(39) + N', TABLOCK)';
        EXEC sp_executesql @sql;
        SELECT @row_count = COUNT(1) FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'bronze.crm_sales_details';
        PRINT '  bronze.crm_sales_details | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- -------------------------------------------------------------------
        -- ERP Tables
        -- -------------------------------------------------------------------
        PRINT '';
        PRINT '--- ERP Tables ---';

        -- bronze.erp_cust_az12 -----------------------------------------------
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Bronze', 'bronze.erp_cust_az12', @start_time, 'Running');

        TRUNCATE TABLE bronze.erp_cust_az12;
        SET @sql = N'BULK INSERT bronze.erp_cust_az12 FROM '
                 + CHAR(39) + @csv_path_erp + N'CUST_AZ12.csv'     + CHAR(39)
                 + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '
                 + CHAR(39) + N',' + CHAR(39) + N', TABLOCK)';
        EXEC sp_executesql @sql;
        SELECT @row_count = COUNT(1) FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'bronze.erp_cust_az12';
        PRINT '  bronze.erp_cust_az12     | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- bronze.erp_loc_a101 ------------------------------------------------
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Bronze', 'bronze.erp_loc_a101', @start_time, 'Running');

        TRUNCATE TABLE bronze.erp_loc_a101;
        SET @sql = N'BULK INSERT bronze.erp_loc_a101 FROM '
                 + CHAR(39) + @csv_path_erp + N'LOC_A101.csv'      + CHAR(39)
                 + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '
                 + CHAR(39) + N',' + CHAR(39) + N', TABLOCK)';
        EXEC sp_executesql @sql;
        SELECT @row_count = COUNT(1) FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'bronze.erp_loc_a101';
        PRINT '  bronze.erp_loc_a101      | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- bronze.erp_px_cat_g1v2 ---------------------------------------------
        SET @start_time = GETDATE();
        INSERT INTO etl.load_log (batch_id, layer, table_name, start_time, status)
        VALUES (@batch_id, 'Bronze', 'bronze.erp_px_cat_g1v2', @start_time, 'Running');

        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        SET @sql = N'BULK INSERT bronze.erp_px_cat_g1v2 FROM '
                 + CHAR(39) + @csv_path_erp + N'PX_CAT_G1V2.csv'  + CHAR(39)
                 + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '
                 + CHAR(39) + N',' + CHAR(39) + N', TABLOCK)';
        EXEC sp_executesql @sql;
        SELECT @row_count = COUNT(1) FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();
        UPDATE etl.load_log
        SET    end_time          = @end_time,
               duration_seconds  = DATEDIFF(SECOND, @start_time, @end_time),
               row_count         = @row_count,
               status            = 'Completed'
        WHERE  batch_id   = @batch_id
        AND    table_name = 'bronze.erp_px_cat_g1v2';
        PRINT '  bronze.erp_px_cat_g1v2   | '
            + CAST(@row_count AS NVARCHAR) + ' rows | '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + 's';

        -- -------------------------------------------------------------------
        -- Batch summary
        -- -------------------------------------------------------------------
        PRINT '';
        PRINT '================================================';
        PRINT 'Bronze Load Completed';
        PRINT 'Total Duration : '
            + CAST(DATEDIFF(SECOND, @batch_start, GETDATE()) AS NVARCHAR) + 's';
        PRINT 'Audit Query    : SELECT * FROM etl.load_log WHERE batch_id = '''
            + CAST(@batch_id AS NVARCHAR(50)) + '''';
        PRINT '================================================';

    END TRY
    BEGIN CATCH

        -- Mark any table that was mid-flight as Failed
        UPDATE etl.load_log
        SET    end_time          = GETDATE(),
               duration_seconds  = DATEDIFF(SECOND, start_time, GETDATE()),
               status            = 'Failed',
               error_message     = ERROR_MESSAGE()
        WHERE  batch_id = @batch_id
        AND    status   = 'Running';

        PRINT '================================================';
        PRINT 'BRONZE LOAD FAILED';
        PRINT 'Error  : ' + ERROR_MESSAGE();
        PRINT 'Audit  : SELECT * FROM etl.load_log WHERE batch_id = '''
            + CAST(@batch_id AS NVARCHAR(50)) + '''';
        PRINT '================================================';

        THROW;

    END CATCH;
END;
GO

-- Compatibility wrapper used by runbook/documentation
CREATE OR ALTER PROCEDURE bronze.usp_bronze_load_all AS
BEGIN
    SET NOCOUNT ON;
    EXEC bronze.load_bronze;
END;
GO
