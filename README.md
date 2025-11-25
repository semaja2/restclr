# RestClr - SQL Server CLR for REST API Calls with mTLS

A SQL Server 2022 CLR assembly that enables making HTTPS REST API calls with mutual TLS (mTLS) client authentication directly from T-SQL. Uses RestSharp for reliable HTTP communication and retrieves certificates from the Windows certificate store.

## Features

- **mTLS Authentication**: Client certificate authentication using certificates from Windows certificate store
- **Certificate Management**: Find certificates by thumbprint from CurrentUser\My store
- **HTTP Methods**: Support for GET, POST, PUT, DELETE, PATCH, HEAD, and OPTIONS
- **Custom Headers**: Add custom HTTP headers to requests
- **Flexible Content**: Support for JSON, XML, and other content types
- **.NET Framework 4.8**: Built for compatibility with SQL Server 2022
- **Minimal Dependencies**: Only uses RestSharp as external dependency

## Prerequisites

- SQL Server 2022 (or 2019/2017 with .NET Framework 4.8 support)
- .NET Framework 4.8 SDK
- Visual Studio 2019 or later (or MSBuild)
- SQL Server with CLR integration enabled
- Client certificate with private key in Windows certificate store

## Building the Assembly

1. Open a command prompt in the project directory
2. Restore NuGet packages and build:

```cmd
msbuild RestClr.csproj /t:Restore
msbuild RestClr.csproj /p:Configuration=Release
```

3. The compiled assembly will be in `bin\Release\RestClr.dll`
4. Required dependencies will also be in the same folder

## Deployment

1. **Edit Deploy.sql**: Update the database name and file paths
   ```sql
   USE [YourDatabaseName];
   ```

   Update the assembly paths to match your build output:
   ```sql
   FROM 'C:\Users\Administrator\Documents\restclr\bin\Release\RestClr.dll'
   ```

2. **Run Deploy.sql** in SQL Server Management Studio or via sqlcmd:
   ```cmd
   sqlcmd -S localhost -E -i Deploy.sql
   ```

3. **Verify deployment**:
   ```sql
   SELECT * FROM sys.assemblies WHERE name LIKE '%Rest%';
   ```

## Certificate Setup

### Finding Your Certificate Thumbprint

Run the provided SQL function to list all certificates:

```sql
SELECT dbo.ListCertificates();
```

Or use PowerShell:

```powershell
Get-ChildItem Cert:\CurrentUser\My | Format-List Subject, Thumbprint, HasPrivateKey
```

Or use Windows Certificate Manager:
1. Press `Win + R`, type `certmgr.msc`
2. Navigate to Personal > Certificates
3. Double-click your certificate
4. Go to Details tab
5. Scroll down to Thumbprint field
6. Copy the thumbprint value

### Certificate Requirements

- Certificate must be in **CurrentUser\My** store
- Certificate **must have a private key**
- Certificate must be valid for client authentication
- SQL Server service account must have access to the certificate

### Installing a Certificate

If you need to import a certificate:

```powershell
# Import PFX with private key
$pwd = ConvertTo-SecureString -String "your-password" -Force -AsPlainText
Import-PfxCertificate -FilePath "C:\path\to\certificate.pfx" -CertStoreLocation Cert:\CurrentUser\My -Password $pwd
```

## Usage Examples

### Basic GET Request

```sql
DECLARE @thumbprint NVARCHAR(100) = 'ABC123DEF456...';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/data';

SELECT dbo.HttpGet(@url, @thumbprint) AS Response;
```

### POST Request with JSON

```sql
DECLARE @thumbprint NVARCHAR(100) = 'ABC123DEF456...';
DECLARE @url NVARCHAR(MAX) = 'https://api.example.com/users';
DECLARE @body NVARCHAR(MAX) = '{"name": "John Doe", "email": "john@example.com"}';

SELECT dbo.HttpPost(@url, @thumbprint, @body, 'application/json') AS Response;
```

### Request with Custom Headers

```sql
DECLARE @thumbprint NVARCHAR(100) = 'ABC123DEF456...';
DECLARE @headers NVARCHAR(MAX) = 'Authorization:Bearer token123;X-API-Key:key456';

SELECT dbo.HttpRequestWithHeaders(
    'https://api.example.com/data',
    @thumbprint,
    'GET',
    NULL,
    NULL,
    @headers
) AS Response;
```

See `Examples.sql` for more usage examples.

## Available Functions

### dbo.HttpGet
```sql
dbo.HttpGet(@url, @certificateThumbprint)
```
Executes an HTTP GET request.

### dbo.HttpPost
```sql
dbo.HttpPost(@url, @certificateThumbprint, @body, @contentType)
```
Executes an HTTP POST request with body.

### dbo.HttpPut
```sql
dbo.HttpPut(@url, @certificateThumbprint, @body, @contentType)
```
Executes an HTTP PUT request with body.

### dbo.HttpDelete
```sql
dbo.HttpDelete(@url, @certificateThumbprint)
```
Executes an HTTP DELETE request.

### dbo.HttpPatch
```sql
dbo.HttpPatch(@url, @certificateThumbprint, @body, @contentType)
```
Executes an HTTP PATCH request with body.

### dbo.HttpRequestWithHeaders
```sql
dbo.HttpRequestWithHeaders(@url, @certificateThumbprint, @method, @body, @contentType, @headers)
```
Executes an HTTP request with custom headers. Headers format: `"Header1:Value1;Header2:Value2"`

### dbo.ListCertificates
```sql
dbo.ListCertificates()
```
Lists all certificates in CurrentUser\My store with details.

## Error Handling

All functions return errors as strings prefixed with "ERROR:". Always check for errors:

```sql
DECLARE @response NVARCHAR(MAX);
SET @response = dbo.HttpGet(@url, @thumbprint);

IF LEFT(@response, 6) = 'ERROR:'
BEGIN
    PRINT 'Error occurred: ' + @response;
END
```

Common errors:
- `ERROR: Certificate with thumbprint '...' not found` - Certificate not in store
- `ERROR: Certificate with thumbprint '...' does not have a private key` - Certificate missing private key
- `ERROR: HTTP 401 - Unauthorized` - Authentication failed
- `ERROR: HTTP 403 - Forbidden` - Authorization failed
- `ERROR: HTTP 404 - Not Found` - URL not found

## Security Considerations

1. **UNSAFE Permission Set**: This assembly requires `UNSAFE` permission set because it:
   - Accesses the file system (certificate store)
   - Makes external network calls
   - Uses unmanaged code for HTTPS/TLS

2. **TRUSTWORTHY Database**: The deployment script sets the database to `TRUSTWORTHY ON`. Review the security implications for your environment.

3. **Certificate Security**: The certificate's private key must be accessible to the SQL Server service account. Ensure proper ACLs on the certificate.

4. **Certificate Validation**: The assembly currently accepts all server certificates (`RemoteCertificateValidationCallback = true`). For production, consider implementing proper certificate validation.

5. **SQL Injection**: When building URLs with user input, always use proper parameterization.

## Troubleshooting

### CLR Not Enabled
```sql
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
```

### Assembly Load Errors
Check that all dependencies are deployed:
```sql
SELECT name, permission_set_desc FROM sys.assemblies;
```

### Certificate Access Issues
Ensure SQL Server service account has access to certificate:
```powershell
# Grant service account access to certificate private key
$cert = Get-ChildItem Cert:\CurrentUser\My\THUMBPRINT
$keyPath = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
# Use icacls to grant permissions
```

### Network Connectivity
Verify SQL Server can reach the API endpoint:
```sql
-- Test basic connectivity
EXEC xp_cmdshell 'ping api.example.com';
```

## Uninstallation

Run `Undeploy.sql` to remove all functions and assemblies:

```cmd
sqlcmd -S localhost -E -i Undeploy.sql
```

## License

This code is provided as-is without warranty. Use at your own risk.

## Version History

- **1.0.0** - Initial release
  - Support for HTTP GET, POST, PUT, DELETE, PATCH
  - mTLS client authentication
  - Certificate retrieval by thumbprint
  - Custom headers support
  - .NET Framework 4.8 compatibility
