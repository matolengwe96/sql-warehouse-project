/*
===============================================================================
One-Click Runner: End-to-End Warehouse Build and Validation
===============================================================================
Purpose:
    Executes the full project workflow in order:
    1) Initialize database and schemas
    2) Create ETL log objects
    3) Create Bronze/Silver/Gold objects
    4) Run Bronze and Silver loads
    5) Run Silver and Gold quality checks

How to run in SSMS:
    1) Open this file.
    2) Enable SQLCMD Mode: Query > SQLCMD Mode.
    3) Execute (F5).

Notes:
    - init_database.sql is destructive and recreates DataWarehouse.
    - Bronze loader paths are preconfigured for this local workspace.
===============================================================================
*/

-- 1) Initialize database and schemas (destructive)
:r .\init_database.sql

-- 2) ETL metadata objects
:r .\etl\01_ddl_etl_log.sql

-- 3) Bronze layer objects and load procedures
:r .\bronze\ddl_bronze.sql
:r .\bronze\proc_load_bronze.sql

-- 4) Silver layer objects and load procedures
:r .\silver\ddl_silver.sql
:r .\silver\proc_load_silver.sql

-- 5) Gold views and compatibility procedures
:r .\gold\ddl_gold.sql
:r .\gold\02_proc_load_gold.sql

-- 6) Execute data loads
USE DataWarehouse;
GO
EXEC bronze.usp_bronze_load_all;
GO
EXEC silver.usp_silver_load_all;
GO

-- 7) Execute data quality checks
:r ..\tests\quality_checks_silver.sql
:r ..\tests\quality_checks_gold.sql

PRINT 'End-to-end run completed.';
GO
