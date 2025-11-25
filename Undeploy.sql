-- =============================================
-- SQL Server CLR Undeployment Script for RestClr
-- =============================================
-- This script removes the RestClr assembly and functions
-- =============================================

-- Switch to your target database
-- IMPORTANT: Change this to your target database name
USE [YourDatabaseName];
GO

-- Drop functions
IF OBJECT_ID('dbo.HttpGet', 'FS') IS NOT NULL
    DROP FUNCTION dbo.HttpGet;
GO

IF OBJECT_ID('dbo.HttpPost', 'FS') IS NOT NULL
    DROP FUNCTION dbo.HttpPost;
GO

IF OBJECT_ID('dbo.HttpPut', 'FS') IS NOT NULL
    DROP FUNCTION dbo.HttpPut;
GO

IF OBJECT_ID('dbo.HttpDelete', 'FS') IS NOT NULL
    DROP FUNCTION dbo.HttpDelete;
GO

IF OBJECT_ID('dbo.HttpPatch', 'FS') IS NOT NULL
    DROP FUNCTION dbo.HttpPatch;
GO

IF OBJECT_ID('dbo.HttpRequestWithHeaders', 'FS') IS NOT NULL
    DROP FUNCTION dbo.HttpRequestWithHeaders;
GO

IF OBJECT_ID('dbo.ListCertificates', 'FS') IS NOT NULL
    DROP FUNCTION dbo.ListCertificates;
GO

-- Drop assemblies
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'RestClr')
    DROP ASSEMBLY RestClr;
GO

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'RestSharp')
    DROP ASSEMBLY RestSharp;
GO

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'System.Memory')
    DROP ASSEMBLY [System.Memory];
GO

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'System.Buffers')
    DROP ASSEMBLY [System.Buffers];
GO

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'System.Runtime.CompilerServices.Unsafe')
    DROP ASSEMBLY [System.Runtime.CompilerServices.Unsafe];
GO

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'System.Numerics.Vectors')
    DROP ASSEMBLY [System.Numerics.Vectors];
GO

PRINT 'RestClr assembly and functions removed successfully!';
GO
