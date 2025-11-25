@echo off
REM Build script for RestClr SQL Server CLR Assembly

echo ================================================
echo Building RestClr - SQL Server CLR Assembly
echo ================================================
echo.

REM Check if MSBuild is available
where msbuild >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: MSBuild not found in PATH
    echo Please run this script from a Visual Studio Developer Command Prompt
    echo or add MSBuild to your PATH
    pause
    exit /b 1
)

echo Restoring NuGet packages...
msbuild RestClr.csproj /t:Restore /p:Configuration=Release
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to restore NuGet packages
    pause
    exit /b 1
)

echo.
echo Building RestClr assembly...
msbuild RestClr.csproj /p:Configuration=Release /p:Platform=AnyCPU
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo ================================================
echo Build completed successfully!
echo ================================================
echo.
echo Output files are in: bin\Release\
echo.
echo Main assembly: bin\Release\RestClr.dll
echo Dependencies:
echo   - bin\Release\RestSharp.dll
echo   - bin\Release\System.Buffers.dll
echo   - bin\Release\System.Memory.dll
echo   - bin\Release\System.Runtime.CompilerServices.Unsafe.dll
echo   - bin\Release\System.Numerics.Vectors.dll
echo.
echo Next steps:
echo   1. Edit Deploy.sql and update the database name
echo   2. Update the file paths in Deploy.sql to match your build output
echo   3. Run Deploy.sql in SQL Server Management Studio
echo.
pause
