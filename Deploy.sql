-- =============================================
-- SQL Server CLR Deployment Script for RestClr
-- =============================================
-- This script deploys the RestClr assembly and creates SQL functions
-- for making REST API calls with mTLS client authentication
--
-- PREREQUISITES:
-- 1. Build the project: dotnet build --configuration Release
-- 2. Update database name below (replace 'YourDatabaseName')
-- 3. Update file paths to match your build output directory
-- 4. Ensure SQL Server service account has read access to DLL files
-- =============================================

USE [master];
GO

-- Enable CLR integration at server level
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO

-- Switch to your target database
-- IMPORTANT: Change 'YourDatabaseName' to your actual database name
USE [YourDatabaseName];
GO

-- Drop existing functions if they exist
IF OBJECT_ID('dbo.HttpGet', 'FS') IS NOT NULL DROP FUNCTION dbo.HttpGet;
IF OBJECT_ID('dbo.HttpPost', 'FS') IS NOT NULL DROP FUNCTION dbo.HttpPost;
IF OBJECT_ID('dbo.HttpPut', 'FS') IS NOT NULL DROP FUNCTION dbo.HttpPut;
IF OBJECT_ID('dbo.HttpDelete', 'FS') IS NOT NULL DROP FUNCTION dbo.HttpDelete;
IF OBJECT_ID('dbo.HttpPatch', 'FS') IS NOT NULL DROP FUNCTION dbo.HttpPatch;
IF OBJECT_ID('dbo.HttpRequestWithHeaders', 'FS') IS NOT NULL DROP FUNCTION dbo.HttpRequestWithHeaders;
IF OBJECT_ID('dbo.ListCertificates', 'FS') IS NOT NULL DROP FUNCTION dbo.ListCertificates;
GO

-- Drop assemblies if they exist (in reverse dependency order)
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'RestClr') DROP ASSEMBLY RestClr;
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'RestSharp') DROP ASSEMBLY RestSharp;
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'System.Web') DROP ASSEMBLY [System.Web];
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'System.Runtime.Serialization') DROP ASSEMBLY [System.Runtime.Serialization];
GO

-- Set database trustworthy (required for UNSAFE permission set)
-- WARNING: Review security implications before using in production
-- See: https://docs.microsoft.com/en-us/sql/relational-databases/security/trustworthy-database-property
ALTER DATABASE [YourDatabaseName] SET TRUSTWORTHY ON;
GO

-- Create .NET Framework assemblies from GAC (in dependency order)
PRINT 'Creating System.Runtime.Serialization assembly from GAC...';
CREATE ASSEMBLY [System.Runtime.Serialization]
FROM 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.Serialization.dll'
WITH PERMISSION_SET = UNSAFE;
GO

PRINT 'Creating System.Web assembly from GAC...';
CREATE ASSEMBLY [System.Web]
FROM 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Web.dll'
WITH PERMISSION_SET = UNSAFE;
GO

-- Create RestSharp assembly
-- IMPORTANT: Update this path to match your build output directory
PRINT 'Creating RestSharp assembly...';
CREATE ASSEMBLY RestSharp
FROM 'C:\path\to\your\project\bin\Release\net48\RestSharp.dll'
WITH PERMISSION_SET = UNSAFE;
GO

-- Create the main RestClr assembly
-- IMPORTANT: Update this path to match your build output directory
PRINT 'Creating RestClr assembly...';
CREATE ASSEMBLY RestClr
FROM 'C:\path\to\your\project\bin\Release\net48\RestClr.dll'
WITH PERMISSION_SET = UNSAFE;
GO

-- Create SQL Functions
PRINT 'Creating SQL functions...';

CREATE FUNCTION dbo.HttpGet(@url NVARCHAR(MAX), @certificateThumbprint NVARCHAR(100))
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].HttpGet;
GO

CREATE FUNCTION dbo.HttpPost(@url NVARCHAR(MAX), @certificateThumbprint NVARCHAR(100), @body NVARCHAR(MAX), @contentType NVARCHAR(100))
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].HttpPost;
GO

CREATE FUNCTION dbo.HttpPut(@url NVARCHAR(MAX), @certificateThumbprint NVARCHAR(100), @body NVARCHAR(MAX), @contentType NVARCHAR(100))
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].HttpPut;
GO

CREATE FUNCTION dbo.HttpDelete(@url NVARCHAR(MAX), @certificateThumbprint NVARCHAR(100))
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].HttpDelete;
GO

CREATE FUNCTION dbo.HttpPatch(@url NVARCHAR(MAX), @certificateThumbprint NVARCHAR(100), @body NVARCHAR(MAX), @contentType NVARCHAR(100))
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].HttpPatch;
GO

CREATE FUNCTION dbo.HttpRequestWithHeaders(@url NVARCHAR(MAX), @certificateThumbprint NVARCHAR(100), @method NVARCHAR(10), @body NVARCHAR(MAX), @contentType NVARCHAR(100), @headers NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].HttpRequestWithHeaders;
GO

CREATE FUNCTION dbo.ListCertificates()
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME RestClr.[RestClr].ListCertificates;
GO

PRINT '';
PRINT '===========================================';
PRINT 'RestClr deployment completed successfully!';
PRINT '===========================================';
PRINT '';
GO

-- Verify deployment
PRINT 'Deployed assemblies:';
SELECT name, permission_set_desc, create_date
FROM sys.assemblies
WHERE name IN ('RestSharp', 'RestClr', 'System.Runtime.Serialization', 'System.Web')
ORDER BY create_date;
GO

PRINT '';
PRINT 'Created functions:';
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME LIKE 'Http%' OR ROUTINE_NAME = 'ListCertificates'
ORDER BY ROUTINE_NAME;
GO
