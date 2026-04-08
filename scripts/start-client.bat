@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM NATMap Client 启动脚本
REM 通过 API 获取最新映射地址并启动 client.exe

REM 配置参数
set API_URL=https://nm.kszhc.top/api/get?tenant=喀什信海通电子科技有限公司&app=http2tunnel1
set TOKEN=zhc
set TRANSPORT=tcp

REM 获取映射数据
echo 正在获取最新映射地址...
for /f "delims=" %%i in ('powershell -Command "try { $r=Invoke-RestMethod -Uri '%API_URL%' -Method GET; Write-Host ('{\"ip\":\"' + $r.public_ip + '\",\"port\":' + $r.public_port + '}') } catch { Write-Host '{\"error\":\"' + $_.Exception.Message + '"}' }"') do set RESULT=%%i

REM 解析 JSON
echo 解析响应数据...
for /f "tokens=2 delims=:" %%a in ('echo !RESULT! ^| findstr "ip"') do (
    set IP_RAW=%%a
    set IP=!IP_RAW:"=!
    set IP=!IP: =!
    set IP=!IP:,=!
)

for /f "tokens=2 delims=:" %%b in ('echo !RESULT! ^| findstr "port"') do (
    set PORT_RAW=%%b
    set PORT=!PORT_RAW:"=!
    set PORT=!PORT: =!
    set PORT=!PORT:}=!
)

REM 检查是否获取成功
if "!IP!"=="" (
    echo 错误: 无法获取 IP 地址
    echo 响应内容: !RESULT!
    pause
    exit /b 1
)

if "!PORT!"=="" (
    echo 错误: 无法获取端口号
    echo 响应内容: !RESULT!
    pause
    exit /b 1
)

echo 获取到映射地址: !IP!:!PORT!
echo.

REM 启动 client.exe
echo 正在启动 client.exe...
echo 服务器地址: !IP!:!PORT!
echo 传输协议: %TRANSPORT%
echo Token: %TOKEN%
echo.

client.exe -transport %TRANSPORT% -server !IP!:!PORT! -token %TOKEN%

REM 如果 client.exe 退出，暂停显示错误信息
if errorlevel 1 (
    echo.
    echo client.exe 已退出，返回码: %errorlevel%
    pause
)

endlocal
