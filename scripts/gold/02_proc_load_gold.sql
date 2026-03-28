/*
===============================================================================
Stored Procedure: Gold Compatibility Loader
===============================================================================
Script Purpose:
    Provides compatibility procedures for runbooks that expect executable
    Gold load procedures. In this implementation, Gold objects are views,
    so no physical load is required.

Usage:
    EXEC gold.usp_gold_load_fact_sales;
    EXEC gold.usp_gold_load_all;
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.usp_gold_load_fact_sales AS
BEGIN
    SET NOCOUNT ON;

    -- Gold is view-based in this project; querying confirms objects are available.
    SELECT TOP (1) *
    FROM gold.fact_sales;
END;
GO

CREATE OR ALTER PROCEDURE gold.usp_gold_load_all AS
BEGIN
    SET NOCOUNT ON;
    EXEC gold.usp_gold_load_fact_sales;
END;
GO
