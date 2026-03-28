/*
===============================================================================
One-Click Runner: Incremental Re-Run (Non-Destructive)
===============================================================================
Purpose:
    Refreshes data and validations without dropping or recreating the database.

What it does:
    1) Re-deploys load procedures (idempotent CREATE OR ALTER)
    2) Re-runs Bronze and Silver loads
    3) Re-runs Gold compatibility procedure
    4) Executes Silver and Gold quality checks

How to run in SSMS:
    1) Open this file.
    2) Enable SQLCMD Mode: Query > SQLCMD Mode.
    3) Execute (F5).

Notes:
    - Safe for iterative development/testing.
    - Does NOT execute init_database.sql.
===============================================================================
*/

-- 1) Re-deploy procedures/views (safe to re-run)
:r .\bronze\proc_load_bronze.sql
:r .\silver\proc_load_silver.sql
:r .\gold\ddl_gold.sql
:r .\gold\02_proc_load_gold.sql

-- 2) Execute data refresh
USE DataWarehouse;
GO
EXEC bronze.usp_bronze_load_all;
GO
EXEC silver.usp_silver_load_all;
GO
EXEC gold.usp_gold_load_all;
GO

-- 3) Execute quality checks
:r ..\tests\quality_checks_silver.sql
:r ..\tests\quality_checks_gold.sql

PRINT 'Incremental rerun completed.';
GO
