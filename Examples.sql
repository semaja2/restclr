-- =============================================
-- RestClr Usage Examples
-- =============================================

-- Example 1: List all available certificates in the CurrentUser\My store
SELECT dbo.ListCertificates();
GO

-- Example 2: Simple GET request with mTLS
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/data';

SELECT dbo.HttpGet(@url, @thumbprint) AS Response;
GO

-- Example 3: POST request with JSON body
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/users';
DECLARE @body NVARCHAR(MAX) = '{"name": "John Doe", "email": "john@example.com"}';
DECLARE @contentType NVARCHAR(100) = 'application/json';

SELECT dbo.HttpPost(@url, @thumbprint, @body, @contentType) AS Response;
GO

-- Example 4: PUT request with JSON body
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/users/123';
DECLARE @body NVARCHAR(MAX) = '{"name": "Jane Doe", "email": "jane@example.com"}';
DECLARE @contentType NVARCHAR(100) = 'application/json';

SELECT dbo.HttpPut(@url, @thumbprint, @body, @contentType) AS Response;
GO

-- Example 5: DELETE request
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/users/123';

SELECT dbo.HttpDelete(@url, @thumbprint) AS Response;
GO

-- Example 6: PATCH request
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/users/123';
DECLARE @body NVARCHAR(MAX) = '{"email": "newemail@example.com"}';
DECLARE @contentType NVARCHAR(100) = 'application/json';

SELECT dbo.HttpPatch(@url, @thumbprint, @body, @contentType) AS Response;
GO

-- Example 7: Request with custom headers
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/data';
DECLARE @method NVARCHAR(10) = 'GET';
DECLARE @body NVARCHAR(MAX) = NULL;
DECLARE @contentType NVARCHAR(100) = NULL;
-- Headers format: "Header1:Value1;Header2:Value2"
DECLARE @headers NVARCHAR(MAX) = 'X-API-Key:your-api-key;X-Custom-Header:custom-value';

SELECT dbo.HttpRequestWithHeaders(@url, @thumbprint, @method, @body, @contentType, @headers) AS Response;
GO

-- Example 8: POST with custom headers and JSON body
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/submit';
DECLARE @method NVARCHAR(10) = 'POST';
DECLARE @body NVARCHAR(MAX) = '{"data": "test"}';
DECLARE @contentType NVARCHAR(100) = 'application/json';
DECLARE @headers NVARCHAR(MAX) = 'Authorization:Bearer token123;X-Request-ID:12345';

SELECT dbo.HttpRequestWithHeaders(@url, @thumbprint, @method, @body, @contentType, @headers) AS Response;
GO

-- Example 9: Parse JSON response
-- If you have SQL Server 2016+ with JSON support
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/users';
DECLARE @response NVARCHAR(MAX);

SET @response = dbo.HttpGet(@url, @thumbprint);

-- Check if response is an error
IF LEFT(@response, 6) = 'ERROR:'
BEGIN
    PRINT 'Error occurred: ' + @response;
END
ELSE
BEGIN
    -- Parse JSON response
    SELECT *
    FROM OPENJSON(@response)
    WITH (
        id INT '$.id',
        name NVARCHAR(100) '$.name',
        email NVARCHAR(100) '$.email'
    );
END
GO

-- Example 10: Using in stored procedure
CREATE OR ALTER PROCEDURE dbo.CallExternalAPI
    @thumbprint NVARCHAR(100),
    @userId INT
AS
BEGIN
    DECLARE @url NVARCHAR(MAX);
    DECLARE @response NVARCHAR(MAX);

    -- Build URL with parameter
    SET @url = 'https://api.example.com/users/' + CAST(@userId AS NVARCHAR(10));

    -- Make API call
    SET @response = dbo.HttpGet(@url, @thumbprint);

    -- Check for errors
    IF LEFT(@response, 6) = 'ERROR:'
    BEGIN
        RAISERROR('API call failed: %s', 16, 1, @response);
        RETURN;
    END

    -- Return response
    SELECT @response AS ApiResponse;
END
GO

-- Example 11: Bulk API calls using cursor
DECLARE @thumbprint NVARCHAR(100) = 'YOUR_CERTIFICATE_THUMBPRINT_HERE';
DECLARE @userId INT;
DECLARE @url NVARCHAR(MAX);
DECLARE @response NVARCHAR(MAX);

DECLARE user_cursor CURSOR FOR
SELECT user_id FROM dbo.UsersToSync;

OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO @userId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @url = 'https://api.example.com/users/' + CAST(@userId AS NVARCHAR(10));
    SET @response = dbo.HttpGet(@url, @thumbprint);

    IF LEFT(@response, 6) != 'ERROR:'
    BEGIN
        PRINT 'Successfully synced user ' + CAST(@userId AS NVARCHAR(10));
        -- Process response here
    END
    ELSE
    BEGIN
        PRINT 'Failed to sync user ' + CAST(@userId AS NVARCHAR(10)) + ': ' + @response;
    END

    FETCH NEXT FROM user_cursor INTO @userId;
END

CLOSE user_cursor;
DEALLOCATE user_cursor;
GO
