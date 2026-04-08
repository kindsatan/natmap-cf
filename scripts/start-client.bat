@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM NATMap Client 启动脚本
REM 通过 API 获取最新映射地址并启动 client.exe

REM 配置参数
set TENANT_ID=3
set APP_ID=3
set TOKEN=zhc
set TRANSPORT=tcp

echo 正在获取最新映射地址...

REM 使用 PowerShell 解析 JSON（更可靠）
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'https://nm.kszhc.top/api/get?tenant_id=%TENANT_ID%&app_id=%APP_ID%').public_ip"') do (
    set "IP=%%a"
)

for /f "delims=" %%b in ('powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'https://nm.kszhc.top/api/get?tenant_id=%TENANT_ID%&app_id=%APP_ID%').public_port"') do (
    set "PORT=%%b"
)

REM 检查是否获取成功
if "%IP%"=="" (
    echo 错误: 无法获取 IP 地址
    pause
    exit /b 1
)

if "%PORT%"=="" (
    echo 错误: 无法获取端口号
    pause
    exit /b 1
)

echo 获取到映射地址: %IP%:%PORT%
echo.

REM 启动 client.exe
echo 正在启动 client.exe...
client.exe -transport %TRANSPORT% -server %IP%:%PORT% -token %TOKEN%

REM 如果 client.exe 退出，暂停显示错误信息
if errorlevel 1 (
    echo.
    echo client.exe 已退出，返回码: %errorlevel%
    pause
)
