/*
===============================================================================
Stored Procedure: Execute Full Pipeline
===============================================================================
Script Purpose:
    Creates an orchestration procedure that runs the full pipeline in order:
    Bronze -> Silver. Gold objects are views and refresh automatically on query.

Usage:
    EXEC etl.usp_run_full_pipeline;
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE etl.usp_run_full_pipeline AS
BEGIN
    SET NOCOUNT ON;

    EXEC bronze.usp_bronze_load_all;
    EXEC silver.usp_silver_load_all;

    SELECT TOP (100)
        log_id,
        batch_id,
        layer,
        table_name,
        row_count,
        status,
        duration_seconds,
        start_time,
        end_time
    FROM etl.load_log
    ORDER BY log_id DESC;
END;
GO
