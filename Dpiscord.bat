@echo off
setlocal enabledelayedexpansion
title ByeDPI Strateji ^& Kisayol Hazirlayici

:: Karakter seti uyumu
chcp 1254 >nul

:: --- YAPILANDIRMA ---
set "DPI_SUBDIR=byedpi"
set "STRATEGY_FILE=%DPI_SUBDIR%\strategies.txt"
set "CIADPI_EXE=%DPI_SUBDIR%\ciadpi.exe"
set "DLL_SOURCE=version.dll"
set "TEST_URL=https://updates.discord.com"
set "PORT=8848"
set "VBS_NAME=opendiscord.vbs"

:DNS_KONTROL
cls
echo [1] DNS Zehirlenmesi Kontrol Ediliyor...
set "LOCAL_IP="
set "SAFE_IP="

for /f "tokens=2 delims=: " %%a in ('nslookup updates.discord.com 2^>nul ^| findstr /i "Address" ^| findstr /v "#"') do set "LOCAL_IP=%%a"
for /f "tokens=2 delims=: " %%a in ('nslookup updates.discord.com 1.1.1.1 2^>nul ^| findstr /i "Address" ^| findstr /v "1.1.1.1"') do set "SAFE_IP=%%a"

if "%LOCAL_IP%"=="" (echo [-] Yerel IP alýnamadý. & pause & goto DNS_KONTROL)

set "LOCAL_COMP=%LOCAL_IP:~0,5%"
set "SAFE_COMP=%SAFE_IP:~0,5%"

if "%LOCAL_COMP%" neq "%SAFE_COMP%" (
    setlocal DisableDelayedExpansion
    echo/
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo HATA: DNS Zehirlenmesi Saptandý!
    echo Lütfen Windows DNS adresinizi deðiþtirin.
    echo/
    echo DNS degistirdiginiz halde bu hatayý alýyorsaniz, servis 
    echo saðlayýcýnýz müdahale ediyor demektir. YogaDNS kullanýn.
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo/
    endlocal
    echo Tekrar kontrol etmek için ENTER'a basýn...
    pause >nul
    goto DNS_KONTROL
)

echo [+] DURUM: DNS Temiz.
echo.
echo [2] ByeDPI stratejisi bulup Masaüstü kýsayolu oluþturmak için ENTER'a basýn.
pause >nul

:STRATEJI_DENE
echo.
if not exist "%STRATEGY_FILE%" (
    echo HATA: %STRATEGY_FILE% bulunamadý!
    pause
    exit
)

:: --- STRATEJI SAYISINI HESAPLA ---
set "TOTAL_STRATS=0"
for /f "usebackq" %%a in ("%STRATEGY_FILE%") do set /a TOTAL_STRATS+=1

echo [%TOTAL_STRATS%] adet strateji taranacak...
echo.

set "CURRENT_INDEX=0"
for /f "usebackq tokens=*" %%s in ("%STRATEGY_FILE%") do (
    set /a CURRENT_INDEX+=1
    set "STRAT=%%s"
    
    echo Deneniyor (!CURRENT_INDEX!/%TOTAL_STRATS%^): !STRAT!
    
    taskkill /f /im ciadpi.exe >nul 2>&1
    
    :: Programý baþlatýrken parametreleri týrnaksýz ama güvenli geçiyoruz
    start /b "" "%CIADPI_EXE%" !STRAT! -p %PORT%
    
    :: Test süresi (timeout bazen parantez hatasý verebilir, alternatif uyku)
    ping 127.0.0.1 -n 4 >nul
    
    curl -I --socks5-hostname 127.0.0.1:%PORT% %TEST_URL% --connect-timeout 4 >nul 2>&1
    if !errorlevel! equ 0 (
        echo.
        echo [+] ÇALIÞAN STRATEJI BULUNDU (!CURRENT_INDEX!/%TOTAL_STRATS%^): !STRAT!
        set "BEST_STRAT=!STRAT!"
        goto BASARILI
    )
)

echo.
echo HATA: Hiçbir strateji çalýþmadý!
pause
exit

:BASARILI
taskkill /f /im ciadpi.exe >nul 2>&1

:: --- DISCORD APP KLASÖRÜNÜ BUL ---
set "APP_DIR="
for /d %%i in ("%LOCALAPPDATA%\Discord\app-*") do (
    if exist "%%i\Discord.exe" set "APP_DIR=%%i"
)

if defined APP_DIR (
    if exist "%DLL_SOURCE%" (
        copy /y "%DLL_SOURCE%" "!APP_DIR!\version.dll" >nul
        echo [+] DLL kopyalandý: !APP_DIR!
    )
)

:: --- VBS LAUNCHER OLUÞTUR ---
set "VBS_PATH=%~dp0%VBS_NAME%"
set "FULL_CIADPI_PATH=%~dp0%CIADPI_EXE%"

(
echo Option Explicit
echo Dim shell : Set shell = CreateObject^("WScript.Shell"^)
echo On Error Resume Next
echo shell.Run "taskkill /F /T /IM ciadpi.exe", 0, True
echo shell.Run "taskkill /F /T /IM Discord.exe", 0, True
echo On Error GoTo 0
echo Dim q : q = Chr^(34^)
echo shell.Run "cmd /c start " ^& q ^& q ^& " /b " ^& q ^& "%FULL_CIADPI_PATH%" ^& q ^& " %BEST_STRAT% -p %PORT%", 0, False
echo WScript.Sleep 0
echo shell.Run q ^& "%LOCALAPPDATA%\Discord\Update.exe" ^& q ^& " --processStart Discord.exe --a=--proxy-server=socks5://127.0.0.1:%PORT%", 0, False
) > "%VBS_PATH%"

:: --- MASAÜSTÜ KISAYOL ---
set "SC_PATH=%USERPROFILE%\Desktop\Discord (DPI).lnk"
powershell -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SC_PATH%'); $s.TargetPath = '%VBS_PATH%'; $s.WorkingDirectory = '%~dp0'; $s.IconLocation = '%LOCALAPPDATA%\Discord\app.ico'; $s.Save()"

echo [+] Masaüstü kýsayolu oluþturuldu.

:: --- STARTUP KONTROL ---
echo.
set /p "ans=Sistem açýlýþýna (Startup) eklemek ister misiniz? (E/H): "
if /i "%ans%" neq "E" goto BITIS

:: Kopyalama iþlemini parantez içinden çýkarýp deðiþkene atýyoruz
set "SRC_LNK=%USERPROFILE%\Desktop\Discord (DPI).lnk"
set "DST_LNK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Discord (DPI).lnk"

:: Kopyalama komutu
copy /y "%SRC_LNK%" "%DST_LNK%" >nul 2>&1

if %errorlevel% equ 0 (
    echo [+] Baþlangýca eklendi.
) else (
    echo [-] HATA: Kýsayol kopyalanamadý!
)
:BITIS
echo.
echo ÝÞLEM TAMAMLANDI.
pause