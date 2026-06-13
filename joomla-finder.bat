@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  joomla-finder.bat
REM  Find all Joomla sites hosted on a given server IP.
REM
REM  Usage:   joomla-finder.bat <IP> [output.txt]
REM  Example: joomla-finder.bat 72.60.89.132 joomla-sites.txt
REM
REM  How it works:
REM   1. Reverse-IP lookup (HackerTarget API) -> every domain on the IP
REM   2. For each domain, fetch the homepage + /administrator/
REM   3. If Joomla markers are found, write the domain to the txt file
REM
REM  Requires: curl (built into Windows 10 1803+ / Windows 11)
REM  Note: the free HackerTarget API is rate-limited (~50/day per IP).
REM ============================================================

if "%~1"=="" (
    echo Usage: %~nx0 ^<IP^> [output.txt]
    echo Example: %~nx0 72.60.89.132 joomla-sites.txt
    exit /b 1
)

set "TARGET_IP=%~1"
set "OUTFILE=%~2"
if "%OUTFILE%"=="" set "OUTFILE=joomla-sites.txt"

REM Validate IPv4 shape (rejects typos/domains, avoids wasting rate-limited lookups)
echo %TARGET_IP%|findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [ERROR] "%TARGET_IP%" is not a valid IPv4 address.
    echo Example: %~nx0 72.60.89.132
    exit /b 1
)

set "DOMAINS_TMP=%TEMP%\jf_domains_%RANDOM%.txt"
set "PAGE_TMP=%TEMP%\jf_page_%RANDOM%.txt"

where curl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl not found. Use Windows 10 1803+ or install curl.
    exit /b 1
)

echo.
echo === Joomla finder ===
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

        set "ISJ="

        REM 1) Scan homepage for Joomla fingerprints
        curl -s -L -m 15 -A "Mozilla/5.0 (joomla-finder)" "http://!DOMAIN!/" -o "%PAGE_TMP%" 2>nul
        if exist "%PAGE_TMP%" (
            findstr /i /c:"/media/system/js" /c:"/media/jui" /c:"com_content" /c:"option=com_" /c:"content=\"Joomla" "%PAGE_TMP%" >nul 2>&1
            if not errorlevel 1 set "ISJ=1"
        )

        REM 2) Fallback: check /administrator/ for the Joomla admin login
        if not defined ISJ (
            curl -s -L -m 15 -A "Mozilla/5.0 (joomla-finder)" "http://!DOMAIN!/administrator/" -o "%PAGE_TMP%" 2>nul
            if exist "%PAGE_TMP%" (
                findstr /i /c:"mod-login" /c:"form-login" /c:"option=com_login" /c:"Joomla" "%PAGE_TMP%" >nul 2>&1
                if not errorlevel 1 set "ISJ=1"
            )
        )

        if defined ISJ (
            echo Joomla
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
echo Joomla sites found: %FOUND%
echo Saved to: %OUTFILE%
endlocal
