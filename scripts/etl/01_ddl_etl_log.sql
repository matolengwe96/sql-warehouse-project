/*
===============================================================================
DDL Script: ETL Audit Log
===============================================================================
Script Purpose:
    Creates the 'etl.load_log' table, which records execution metadata for
    every table loaded across the Bronze and Silver layers. Each procedure
    call generates a unique batch_id and writes one row per table — capturing
    start time, end time, row count, status (Running / Completed / Failed),
    and any error message.

    Also creates:
    - ix_load_log_batch_id  : Index for fast batch-level lookups.
    - etl.vw_latest_load_summary : View showing the most recent load result
      per table across all layers.

Execution Order:
    2 of 8  —  Run after init_database.sql, before any layer scripts.

Dependencies:
    The 'etl' schema must exist (created by scripts/init_database.sql).

Notes:
    Safe to re-run. Drops and recreates the table and view if they exist.
    WARNING: Re-running will delete all historical load log data.
===============================================================================
*/

USE DataWarehouse;
GO

-- Drop monitoring view first (depends on the table)
IF OBJECT_ID('etl.vw_latest_load_summary', 'V') IS NOT NULL
    DROP VIEW etl.vw_latest_load_summary;
GO

IF OBJECT_ID('etl.vw_latest_pipeline_run', 'V') IS NOT NULL
    DROP VIEW etl.vw_latest_pipeline_run;
GO

IF OBJECT_ID('etl.pipeline_run_log', 'U') IS NOT NULL
    DROP TABLE etl.pipeline_run_log;
GO

IF OBJECT_ID('etl.load_log', 'U') IS NOT NULL
    DROP TABLE etl.load_log;
GO

CREATE TABLE etl.load_log (
    log_id           INT               IDENTITY(1,1) NOT NULL
                                           CONSTRAINT pk_load_log PRIMARY KEY CLUSTERED,
    batch_id         UNIQUEIDENTIFIER  NOT NULL,
    layer            NVARCHAR(20)      NOT NULL,       -- 'Bronze' | 'Silver'
    table_name       NVARCHAR(100)     NOT NULL,
    row_count        INT               NULL,
    start_time       DATETIME          NOT NULL,
    end_time         DATETIME          NULL,
    duration_seconds INT               NULL,
    status           NVARCHAR(20)      NOT NULL,       -- 'Running' | 'Completed' | 'Failed'
    error_message    NVARCHAR(MAX)     NULL,
    created_at       DATETIME          NOT NULL
                                           CONSTRAINT df_load_log_created_at DEFAULT GETDATE()
);
GO

-- Index: fast lookup by batch_id; covers the most common audit query pattern
CREATE NONCLUSTERED INDEX ix_load_log_batch_id
    ON etl.load_log (batch_id)
    INCLUDE (layer, table_name, status, row_count, duration_seconds);
GO

CREATE TABLE etl.pipeline_run_log (
    pipeline_run_id    INT               IDENTITY(1,1) NOT NULL
                                            CONSTRAINT pk_pipeline_run_log PRIMARY KEY CLUSTERED,
    pipeline_batch_id  UNIQUEIDENTIFIER  NOT NULL,
    run_type           NVARCHAR(30)      NOT NULL,  -- Full | Incremental | Manual
    started_at         DATETIME          NOT NULL,
    ended_at           DATETIME          NULL,
    status             NVARCHAR(20)      NOT NULL,  -- Running | Completed | Failed
    error_message      NVARCHAR(MAX)     NULL,
    created_at         DATETIME          NOT NULL
                                            CONSTRAINT df_pipeline_run_log_created_at DEFAULT GETDATE()
);
GO

CREATE NONCLUSTERED INDEX ix_pipeline_run_log_batch
    ON etl.pipeline_run_log (pipeline_batch_id)
    INCLUDE (run_type, status, started_at, ended_at);
GO

-- View: most recent load result per table (quick health-check)
CREATE VIEW etl.vw_latest_load_summary AS
SELECT
    el.layer,
    el.table_name,
    el.row_count,
    el.status,
    el.duration_seconds,
    el.error_message,
    el.start_time,
    el.end_time
FROM etl.load_log el
WHERE el.log_id = (
    SELECT MAX(log_id)
    FROM   etl.load_log
    WHERE  table_name = el.table_name
);
GO

CREATE VIEW etl.vw_latest_pipeline_run AS
SELECT TOP (1)
    pipeline_run_id,
    pipeline_batch_id,
    run_type,
    started_at,
    ended_at,
    status,
    error_message
FROM etl.pipeline_run_log
ORDER BY pipeline_run_id DESC;
GO
