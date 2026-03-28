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

    DECLARE @pipeline_batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @started_at        DATETIME         = GETDATE();

    INSERT INTO etl.pipeline_run_log (
        pipeline_batch_id,
        run_type,
        started_at,
        status
    )
    VALUES (
        @pipeline_batch_id,
        'Full',
        @started_at,
        'Running'
    );

    BEGIN TRY

        EXEC bronze.usp_bronze_load_all;
        EXEC silver.usp_silver_load_all;

        UPDATE etl.pipeline_run_log
        SET ended_at = GETDATE(),
            status = 'Completed'
        WHERE pipeline_batch_id = @pipeline_batch_id;

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

        SELECT
            pipeline_run_id,
            pipeline_batch_id,
            run_type,
            started_at,
            ended_at,
            status,
            error_message
        FROM etl.pipeline_run_log
        WHERE pipeline_batch_id = @pipeline_batch_id;

    END TRY
    BEGIN CATCH

        UPDATE etl.pipeline_run_log
        SET ended_at = GETDATE(),
            status = 'Failed',
            error_message = ERROR_MESSAGE()
        WHERE pipeline_batch_id = @pipeline_batch_id;

        THROW;

    END CATCH;
END;
GO
