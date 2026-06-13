@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  cms-finder.bat
REM  Scan a server IP for WordPress AND Joomla sites in one pass and
REM  write each CMS to its own result file:
REM      wpresult.txt      - WordPress domains
REM      joomlaresult.txt  - Joomla domains
REM
REM  Usage:   cms-finder.bat <IP>
REM  Example: cms-finder.bat 72.60.89.132
REM
REM  Requires: curl (built into Windows 10 1803+ / Windows 11)
REM  Note: the free HackerTarget API is rate-limited (~50/day per IP).
REM ============================================================

if "%~1"=="" (
    echo Usage: %~nx0 ^<IP^>
    echo Example: %~nx0 72.60.89.132
    exit /b 1
)

set "TARGET_IP=%~1"
set "WP_OUT=wpresult.txt"
set "JM_OUT=joomlaresult.txt"

set "DOMAINS_TMP=%TEMP%\cms_domains_%RANDOM%.txt"
set "PAGE_TMP=%TEMP%\cms_page_%RANDOM%.txt"

where curl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl not found. Use Windows 10 1803+ or install curl.
    exit /b 1
)

echo.
echo === CMS finder (WordPress + Joomla) ===
echo Target IP : %TARGET_IP%
echo WordPress : %WP_OUT%
echo Joomla    : %JM_OUT%
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

REM Fresh per-CMS output files
break > "%WP_OUT%"
break > "%JM_OUT%"

set /a WP=0
set /a JM=0
set /a IDX=0

for /f "usebackq delims=" %%D in ("%DOMAINS_TMP%") do (
    set "DOMAIN=%%D"
    set /a IDX+=1
    if not "!DOMAIN!"=="" (
        <nul set /p "=[!IDX!/%TOTAL%] !DOMAIN! ... "

        set "CMS="

        REM --- Pull homepage once, test both CMSes ---
        curl -s -L -m 15 -A "Mozilla/5.0 (cms-finder)" "http://!DOMAIN!/" -o "%PAGE_TMP%" 2>nul
        if exist "%PAGE_TMP%" (
            findstr /i /c:"wp-content" /c:"wp-includes" /c:"/wp-json" /c:"content=\"WordPress" "%PAGE_TMP%" >nul 2>&1
            if not errorlevel 1 set "CMS=WordPress"
            if not defined CMS (
                findstr /i /c:"/media/system/js" /c:"/media/jui" /c:"com_content" /c:"option=com_" /c:"content=\"Joomla" "%PAGE_TMP%" >nul 2>&1
                if not errorlevel 1 set "CMS=Joomla"
            )
        )

        REM --- Fallbacks on the CMS-specific login paths ---
        if not defined CMS (
            curl -s -L -m 15 -A "Mozilla/5.0 (cms-finder)" "http://!DOMAIN!/wp-login.php" -o "%PAGE_TMP%" 2>nul
            if exist "%PAGE_TMP%" (
                findstr /i /c:"user_login" /c:"wp-submit" /c:"loginform" "%PAGE_TMP%" >nul 2>&1
                if not errorlevel 1 set "CMS=WordPress"
            )
        )
        if not defined CMS (
            curl -s -L -m 15 -A "Mozilla/5.0 (cms-finder)" "http://!DOMAIN!/administrator/" -o "%PAGE_TMP%" 2>nul
            if exist "%PAGE_TMP%" (
                findstr /i /c:"mod-login" /c:"form-login" /c:"option=com_login" /c:"Joomla" "%PAGE_TMP%" >nul 2>&1
                if not errorlevel 1 set "CMS=Joomla"
            )
        )

        if defined CMS (
            echo !CMS!
            if "!CMS!"=="WordPress" (
                echo !DOMAIN!>> "%WP_OUT%"
                set /a WP+=1
            )
            if "!CMS!"=="Joomla" (
                echo !DOMAIN!>> "%JM_OUT%"
                set /a JM+=1
            )
        ) else (
            echo -
        )
    )
)

del "%DOMAINS_TMP%" 2>nul
del "%PAGE_TMP%" 2>nul

echo.
echo === Done ===
echo WordPress: %WP%  -^> %WP_OUT%
echo Joomla:    %JM%  -^> %JM_OUT%
endlocal
