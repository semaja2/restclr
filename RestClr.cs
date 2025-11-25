using System;
using System.Data.SqlTypes;
using System.Net;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using RestSharp;

/// <summary>
/// SQL Server CLR assembly for making REST API calls with mTLS client authentication
/// </summary>
public class RestClr
{
    #region Certificate Management

    /// <summary>
    /// Finds a certificate by thumbprint from CurrentUser and LocalMachine certificate stores
    /// </summary>
    /// <param name="thumbprint">Certificate thumbprint (case-insensitive)</param>
    /// <returns>X509Certificate2 if found, null otherwise</returns>
    private static X509Certificate2 FindCertificateByThumbprint(string thumbprint)
    {
        // Normalize thumbprint: remove whitespace and special characters, convert to uppercase
        thumbprint = thumbprint.Replace(" ", "").Replace("\u200e", "").ToUpper();

        // Try CurrentUser store first (more secure for service accounts)
        var cert = FindCertificateInStore(thumbprint, StoreLocation.CurrentUser);
        if (cert != null)
        {
            return cert;
        }

        // Fallback to LocalMachine store
        return FindCertificateInStore(thumbprint, StoreLocation.LocalMachine);
    }

    /// <summary>
    /// Helper method to find certificate in a specific store location
    /// </summary>
    /// <param name="thumbprint">Normalized certificate thumbprint</param>
    /// <param name="storeLocation">Certificate store location</param>
    /// <returns>X509Certificate2 if found, null otherwise</returns>
    private static X509Certificate2 FindCertificateInStore(string thumbprint, StoreLocation storeLocation)
    {
        X509Store store = new X509Store(StoreName.My, storeLocation);
        try
        {
            store.Open(OpenFlags.ReadOnly);
            X509Certificate2Collection certCollection = store.Certificates.Find(
                X509FindType.FindByThumbprint,
                thumbprint,
                false); // validOnly = false: don't validate certificate chain

            return certCollection.Count > 0 ? certCollection[0] : null;
        }
        finally
        {
            store.Close();
        }
    }

    /// <summary>
    /// Tests if the current process can access the certificate's private key
    /// </summary>
    /// <param name="cert">Certificate to test</param>
    /// <param name="errorMessage">Detailed error message if access fails</param>
    /// <returns>True if private key is accessible, false otherwise</returns>
    private static bool CanAccessPrivateKey(X509Certificate2 cert, out string errorMessage)
    {
        errorMessage = null;

        if (!cert.HasPrivateKey)
        {
            errorMessage = "Certificate does not have a private key associated with it";
            return false;
        }

        try
        {
            // Attempt to access the private key - this will throw if permissions are insufficient
            var key = cert.PrivateKey;
            if (key == null)
            {
                errorMessage = "Certificate reports having a private key, but it could not be retrieved (key is null)";
                return false;
            }

            // Try to get the key's properties to ensure we have real access
            var keySize = key.KeySize;
            return true;
        }
        catch (System.Security.Cryptography.CryptographicException ex)
        {
            // Common errors:
            // - "Keyset does not exist" = private key file not found or no read permission
            // - "Access is denied" = insufficient permissions to access the private key
            errorMessage = string.Format(
                "Cannot access certificate private key: {0}\n\n" +
                "SOLUTION:\n" +
                "Grant SQL Server service account Read permission to the private key:\n" +
                " - Run certlm.msc as Administrator\n" +
                " - Find certificate in Personal\\Certificates\n" +
                " - Right-click > All Tasks > Manage Private Keys\n" +
                " - Add SQL Server service account (e.g., 'NT SERVICE\\MSSQLSERVER')\n" +
                " - Grant Read permission\n" +
                "Technical details: {0}",
                ex.Message,
                cert.Thumbprint);
            return false;
        }
        catch (Exception ex)
        {
            errorMessage = string.Format("Unexpected error accessing private key: {0}", ex.Message);
            return false;
        }
    }

    #endregion

    #region HTTP Methods

    /// <summary>
    /// Executes an HTTP GET request with mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <returns>Response content or error message</returns>
    public static SqlString HttpGet(SqlString url, SqlString certificateThumbprint)
    {
        return ExecuteRequest(url, certificateThumbprint, RestSharp.Method.GET, SqlString.Null, SqlString.Null, SqlString.Null);
    }

    /// <summary>
    /// Executes an HTTP POST request with mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <param name="body">Request body content</param>
    /// <param name="contentType">Content-Type header (default: application/json)</param>
    /// <returns>Response content or error message</returns>
    public static SqlString HttpPost(SqlString url, SqlString certificateThumbprint, SqlString body, SqlString contentType)
    {
        return ExecuteRequest(url, certificateThumbprint, RestSharp.Method.POST, body, contentType, SqlString.Null);
    }

    /// <summary>
    /// Executes an HTTP PUT request with mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <param name="body">Request body content</param>
    /// <param name="contentType">Content-Type header (default: application/json)</param>
    /// <returns>Response content or error message</returns>
    public static SqlString HttpPut(SqlString url, SqlString certificateThumbprint, SqlString body, SqlString contentType)
    {
        return ExecuteRequest(url, certificateThumbprint, RestSharp.Method.PUT, body, contentType, SqlString.Null);
    }

    /// <summary>
    /// Executes an HTTP DELETE request with mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <returns>Response content or error message</returns>
    public static SqlString HttpDelete(SqlString url, SqlString certificateThumbprint)
    {
        return ExecuteRequest(url, certificateThumbprint, RestSharp.Method.DELETE, SqlString.Null, SqlString.Null, SqlString.Null);
    }

    /// <summary>
    /// Executes an HTTP PATCH request with mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <param name="body">Request body content</param>
    /// <param name="contentType">Content-Type header (default: application/json)</param>
    /// <returns>Response content or error message</returns>
    public static SqlString HttpPatch(SqlString url, SqlString certificateThumbprint, SqlString body, SqlString contentType)
    {
        return ExecuteRequest(url, certificateThumbprint, RestSharp.Method.PATCH, body, contentType, SqlString.Null);
    }

    /// <summary>
    /// Executes an HTTP request with custom headers and mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <param name="method">HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)</param>
    /// <param name="body">Request body content (optional)</param>
    /// <param name="contentType">Content-Type header (optional, default: application/json)</param>
    /// <param name="headers">Custom headers in format "Header1:Value1;Header2:Value2"</param>
    /// <returns>Response content or error message</returns>
    public static SqlString HttpRequestWithHeaders(
        SqlString url,
        SqlString certificateThumbprint,
        SqlString method,
        SqlString body,
        SqlString contentType,
        SqlString headers)
    {
        if (method.IsNull)
        {
            return new SqlString("ERROR: HTTP method is required");
        }

        // Parse HTTP method
        RestSharp.Method restMethod;
        switch (method.Value.ToUpper())
        {
            case "GET":
                restMethod = RestSharp.Method.GET;
                break;
            case "POST":
                restMethod = RestSharp.Method.POST;
                break;
            case "PUT":
                restMethod = RestSharp.Method.PUT;
                break;
            case "DELETE":
                restMethod = RestSharp.Method.DELETE;
                break;
            case "PATCH":
                restMethod = RestSharp.Method.PATCH;
                break;
            case "HEAD":
                restMethod = RestSharp.Method.HEAD;
                break;
            case "OPTIONS":
                restMethod = RestSharp.Method.OPTIONS;
                break;
            default:
                return new SqlString(string.Format("ERROR: Invalid HTTP method '{0}'. Supported: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS", method.Value));
        }

        return ExecuteRequest(url, certificateThumbprint, restMethod, body, contentType, headers);
    }

    #endregion

    #region Core HTTP Execution

    /// <summary>
    /// Core method to execute HTTP requests with mTLS authentication
    /// </summary>
    /// <param name="url">Target URL</param>
    /// <param name="certificateThumbprint">Client certificate thumbprint</param>
    /// <param name="method">HTTP method</param>
    /// <param name="body">Request body (optional)</param>
    /// <param name="contentType">Content-Type header (optional)</param>
    /// <param name="headers">Custom headers (optional)</param>
    /// <returns>Response content or error message</returns>
    private static SqlString ExecuteRequest(
        SqlString url,
        SqlString certificateThumbprint,
        RestSharp.Method method,
        SqlString body,
        SqlString contentType,
        SqlString headers)
    {
        RestClient client = null;

        try
        {
            // Validate required parameters
            if (url.IsNull || certificateThumbprint.IsNull)
            {
                return new SqlString("ERROR: URL and certificate thumbprint are required");
            }

            // Find and validate certificate
            var cert = FindCertificateByThumbprint(certificateThumbprint.Value);
            if (cert == null)
            {
                return new SqlString(string.Format(
                    "ERROR: Certificate with thumbprint '{0}' not found in CurrentUser\\My or LocalMachine\\My stores.\n\n" +
                    "Use dbo.ListCertificates() to see available certificates.",
                    certificateThumbprint.Value));
            }

            // Check if we can actually access the private key (not just if it exists)
            string privateKeyError;
            if (!CanAccessPrivateKey(cert, out privateKeyError))
            {
                return new SqlString(string.Format(
                    "ERROR: Certificate with thumbprint '{0}' found, but private key is not accessible.\n\n{1}",
                    certificateThumbprint.Value,
                    privateKeyError));
            }

            // Configure RestClient with mTLS
            client = new RestClient(url.Value);
            client.ClientCertificates = new X509Certificate2Collection { cert };

            // RestSharp/.NET Framework will use default certificate validation
            // which properly validates the server's certificate chain and SSL policy

            // Create request
            var request = new RestRequest(method);

            // Add request body if provided
            if (!body.IsNull && !string.IsNullOrEmpty(body.Value))
            {
                var contentTypeValue = (!contentType.IsNull && !string.IsNullOrEmpty(contentType.Value))
                    ? contentType.Value
                    : "application/json";
                request.AddParameter(contentTypeValue, body.Value, ParameterType.RequestBody);
            }

            // Add custom headers if provided
            if (!headers.IsNull && !string.IsNullOrEmpty(headers.Value))
            {
                var headerPairs = headers.Value.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var pair in headerPairs)
                {
                    var parts = pair.Split(new[] { ':' }, 2);
                    if (parts.Length == 2)
                    {
                        request.AddHeader(parts[0].Trim(), parts[1].Trim());
                    }
                }
            }

            // Configure TLS protocols (TLS 1.3 and 1.2 for modern security)
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls13 | SecurityProtocolType.Tls12;

            // Execute request
            var response = client.Execute(request);

            // Return response or error
            if (response.IsSuccessful)
            {
                return new SqlString(response.Content ?? string.Empty);
            }
            else
            {
                return new SqlString(string.Format(
                    "ERROR: HTTP {0} - {1}\n{2}",
                    (int)response.StatusCode,
                    response.StatusDescription ?? "No description",
                    response.Content ?? string.Empty));
            }
        }
        catch (Exception ex)
        {
            return new SqlString(string.Format("ERROR: {0}\n{1}", ex.Message, ex.StackTrace));
        }
        finally
        {
            // Clean up resources
            // Note: RestClient in RestSharp 106.x doesn't implement IDisposable
            // Certificate disposal is managed by .NET garbage collection
        }
    }

    #endregion

    #region Certificate Listing

    /// <summary>
    /// Lists all certificates in CurrentUser\My and LocalMachine\My stores
    /// </summary>
    /// <returns>Formatted list of certificates with details</returns>
    public static SqlString ListCertificates()
    {
        try
        {
            var result = new StringBuilder();
            int totalCount = 0;

            // List CurrentUser certificates
            result.AppendLine("=== CurrentUser\\My Store ===");
            var userCerts = ListCertificatesFromStore(StoreLocation.CurrentUser);
            totalCount += AppendCertificateList(result, userCerts);

            // List LocalMachine certificates
            result.AppendLine("=== LocalMachine\\My Store ===");
            var machineCerts = ListCertificatesFromStore(StoreLocation.LocalMachine);
            totalCount += AppendCertificateList(result, machineCerts);

            // Add total count at the beginning
            result.Insert(0, string.Format("Total certificates found: {0}\n\n", totalCount));

            return new SqlString(result.ToString());
        }
        catch (Exception ex)
        {
            return new SqlString(string.Format("ERROR: {0}", ex.Message));
        }
    }

    /// <summary>
    /// Helper method to list certificates from a specific store location
    /// </summary>
    /// <param name="storeLocation">Certificate store location</param>
    /// <returns>Certificate collection</returns>
    private static X509Certificate2Collection ListCertificatesFromStore(StoreLocation storeLocation)
    {
        X509Store store = new X509Store(StoreName.My, storeLocation);
        try
        {
            store.Open(OpenFlags.ReadOnly);
            return store.Certificates;
        }
        finally
        {
            store.Close();
        }
    }

    /// <summary>
    /// Helper method to append certificate details to string builder
    /// </summary>
    /// <param name="builder">StringBuilder to append to</param>
    /// <param name="certificates">Certificate collection</param>
    /// <returns>Number of certificates added</returns>
    private static int AppendCertificateList(StringBuilder builder, X509Certificate2Collection certificates)
    {
        if (certificates.Count == 0)
        {
            builder.AppendLine("No certificates found\n");
            return 0;
        }

        builder.AppendLine(string.Format("Found {0} certificate(s):\n", certificates.Count));
        foreach (X509Certificate2 cert in certificates)
        {
            builder.AppendLine(string.Format("Subject: {0}", cert.Subject));
            builder.AppendLine(string.Format("Thumbprint: {0}", cert.Thumbprint));
            builder.AppendLine(string.Format("Issuer: {0}", cert.Issuer));
            builder.AppendLine(string.Format("Valid From: {0}", cert.NotBefore));
            builder.AppendLine(string.Format("Valid To: {0}", cert.NotAfter));
            builder.AppendLine(string.Format("Has Private Key: {0}", cert.HasPrivateKey));
            builder.AppendLine("---");
        }
        builder.AppendLine();

        return certificates.Count;
    }

    #endregion
}
