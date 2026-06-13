@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  wp-finder.bat
REM  Find all WordPress sites hosted on a given server IP.
REM
REM  Usage:   wp-finder.bat <IP> [output.txt]
REM  Example: wp-finder.bat 72.60.89.132 wp-sites.txt
REM
REM  How it works:
REM   1. Reverse-IP lookup (HackerTarget API) -> every domain on the IP
REM   2. For each domain, fetch the homepage + /wp-login.php
REM   3. If WordPress markers are found, write the domain to the txt file
REM
REM  Requires: curl (built into Windows 10 1803+ / Windows 11)
REM  Note: the free HackerTarget API is rate-limited (~50/day per IP).
REM ============================================================

if "%~1"=="" (
    echo Usage: %~nx0 ^<IP^> [output.txt]
    echo Example: %~nx0 72.60.89.132 wp-sites.txt
    exit /b 1
)

set "TARGET_IP=%~1"
set "OUTFILE=%~2"
if "%OUTFILE%"=="" set "OUTFILE=wordpress-sites.txt"

set "DOMAINS_TMP=%TEMP%\wpf_domains_%RANDOM%.txt"
set "PAGE_TMP=%TEMP%\wpf_page_%RANDOM%.txt"

where curl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl not found. Use Windows 10 1803+ or install curl.
    exit /b 1
)

echo.
echo === WordPress finder ===
echo Target IP : %TARGET_IP%
echo Output    : %OUTFILE%
echo.
echo [*] Reverse-IP lookup...

curl -s "https://api.hackertarget.com/reverseiplookup/?q=%TARGET_IP%" -o "%DOMAINS_TMP%"

if not exist "%DOMAINS_TMP%" (
    echo [ERROR] Lookup failed - no response.
    exit /b 1
)

REM Detect API error / no-results / rate-limit responses
findstr /i /c:"No DNS A records" /c:"API count exceeded" /c:"error" /c:"invalid" "%DOMAINS_TMP%" >nul
if not errorlevel 1 (
    echo [INFO] Reverse-IP API returned no usable domains:
    type "%DOMAINS_TMP%"
    echo.
    echo This IP has no domains indexed by HackerTarget, or you hit the
    echo daily rate limit ^(~50 lookups/day from one source IP^).
    del "%DOMAINS_TMP%" 2>nul
    exit /b 1
)

REM Count domains found
set /a TOTAL=0
for /f "usebackq delims=" %%D in ("%DOMAINS_TMP%") do set /a TOTAL+=1
echo [*] %TOTAL% domain(s) returned for %TARGET_IP%
echo.

REM Fresh output file
break > "%OUTFILE%"

set /a FOUND=0
set /a IDX=0

for /f "usebackq delims=" %%D in ("%DOMAINS_TMP%") do (
    set "DOMAIN=%%D"
    set /a IDX+=1
    if not "!DOMAIN!"=="" (
        <nul set /p "=[!IDX!/%TOTAL%] !DOMAIN! ... "

        set "ISWP="

        REM 1) Scan homepage for WordPress fingerprints
        curl -s -L -m 15 -A "Mozilla/5.0 (wp-finder)" "http://!DOMAIN!/" -o "%PAGE_TMP%" 2>nul
        if exist "%PAGE_TMP%" (
            findstr /i /c:"wp-content" /c:"wp-includes" /c:"/wp-json" /c:"content=\"WordPress" "%PAGE_TMP%" >nul 2>&1
            if not errorlevel 1 set "ISWP=1"
        )

        REM 2) Fallback: check /wp-login.php for the login form
        if not defined ISWP (
            curl -s -L -m 15 -A "Mozilla/5.0 (wp-finder)" "http://!DOMAIN!/wp-login.php" -o "%PAGE_TMP%" 2>nul
            if exist "%PAGE_TMP%" (
                findstr /i /c:"user_login" /c:"wp-submit" /c:"loginform" "%PAGE_TMP%" >nul 2>&1
                if not errorlevel 1 set "ISWP=1"
            )
        )

        if defined ISWP (
            echo WordPress
            echo !DOMAIN!>> "%OUTFILE%"
            set /a FOUND+=1
        ) else (
            echo -
        )
    )
)

del "%DOMAINS_TMP%" 2>nul
del "%PAGE_TMP%" 2>nul

echo.
echo === Done ===
echo WordPress sites found: %FOUND%
echo Saved to: %OUTFILE%
endlocal
