@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
cd /d "%~dp0"

if not exist config.bat (
    echo config.bat tidak ditemukan.
    goto :gagal
)
call config.bat
set "PATH=%PG_BIN%;%PATH%"
set PGPASSWORD=%PG_PASS%
set PGCLIENTENCODING=UTF8
set PSQL_ARGS=-h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d %PG_DB% -t -A -q

where psql >nul 2>&1
if errorlevel 1 (
    echo psql tidak ditemukan. Cek PG_BIN di config.bat
    goto :gagal
)
where git >nul 2>&1
if errorlevel 1 (
    echo Git belum terpasang.
    goto :gagal
)

echo.
echo === [1/3] Ekspor layer dari PostgreSQL (schema sewerage) ===
if not exist data mkdir data
del /q data\*.geojson 2>nul

set JUMLAH=0
for /f "usebackq delims=" %%T in (`psql %PSQL_ARGS% -c "SELECT table_name FROM sewerage.v_layers ORDER BY 1"`) do (
    echo   - %%T
    psql %PSQL_ARGS% -c "SELECT sewerage.layer_geojson('%%T')" -o "data\%%T.geojson"
    if errorlevel 1 goto :gagal
    set /a JUMLAH+=1
)
if "!JUMLAH!"=="0" (
    echo Tidak ada layer ditemukan. Cek koneksi database atau jalankan 02_build.sql dulu.
    goto :gagal
)

psql %PSQL_ARGS% -c "SELECT sewerage.layer_manifest()" -o "layers.json"
if errorlevel 1 goto :gagal

echo.
echo === [2/3] Commit ke Git ===
git add -A
git diff --cached --quiet
if not errorlevel 1 (
    echo Tidak ada perubahan data. Selesai.
    goto :selesai
)
git commit -m "Update data WebGIS Sewerage %date% %time:~0,5%"
if errorlevel 1 goto :gagal

echo.
echo === [3/3] Push ke GitHub ===
git push origin HEAD
if errorlevel 1 goto :gagal

echo.
echo BERHASIL. Web akan berubah dalam 1-2 menit.
goto :selesai

:gagal
echo.
echo !!! GAGAL. Baca pesan error di atas. !!!

:selesai
echo.
pause
