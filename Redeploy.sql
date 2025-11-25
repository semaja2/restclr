USE RestClrTest;
GO

-- Drop all functions first
DROP FUNCTION IF EXISTS dbo.HttpGet;
DROP FUNCTION IF EXISTS dbo.HttpPost;
DROP FUNCTION IF EXISTS dbo.HttpPut;
DROP FUNCTION IF EXISTS dbo.HttpDelete;
DROP FUNCTION IF EXISTS dbo.HttpPatch;
DROP FUNCTION IF EXISTS dbo.HttpRequestWithHeaders;
DROP FUNCTION IF EXISTS dbo.ListCertificates;
GO

-- Drop and recreate RestClr assembly
DROP ASSEMBLY RestClr;
GO

CREATE ASSEMBLY RestClr
FROM 'C:\Users\Administrator\Documents\restclr\bin\Release\net48\RestClr.dll'
WITH PERMISSION_SET = UNSAFE;
GO

-- Recreate functions
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

PRINT 'Assembly redeployed successfully with secure certificate validation!';
GO
