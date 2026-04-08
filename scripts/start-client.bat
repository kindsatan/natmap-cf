@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM NATMap Client 启动脚本
REM 通过 API 获取最新映射地址并启动 client.exe

REM 配置参数
REM 使用 tenant_id 和 app_id 替代中文名称，避免编码问题
set TENANT_ID=3
set APP_ID=3
set TOKEN=zhc
set TRANSPORT=tcp

echo 正在获取最新映射地址...

REM 创建临时 PowerShell 脚本
set PS_SCRIPT=%TEMP%\natmap_get_ip_%RANDOM%.ps1
echo $url = 'https://nm.kszhc.top/api/get?tenant_id=%TENANT_ID%^&app_id=%APP_ID%'; > "%PS_SCRIPT%"
echo try { >> "%PS_SCRIPT%"
echo     $r = Invoke-RestMethod -Uri $url -Method GET -UseBasicParsing; >> "%PS_SCRIPT%"
echo     if ($r.public_ip -and $r.public_port) { >> "%PS_SCRIPT%"
echo         Write-Host ('IP=' + $r.public_ip); >> "%PS_SCRIPT%"
echo         Write-Host ('PORT=' + $r.public_port); >> "%PS_SCRIPT%"
echo     } else { >> "%PS_SCRIPT%"
echo         Write-Host 'ERROR=无法解析响应数据'; >> "%PS_SCRIPT%"
echo     } >> "%PS_SCRIPT%"
echo } catch { >> "%PS_SCRIPT%"
echo     Write-Host ('ERROR=' + $_.Exception.Message); >> "%PS_SCRIPT%"
echo } >> "%PS_SCRIPT%"

REM 执行 PowerShell 脚本
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"') do (
    set "LINE=%%i"
    set "PREFIX=!LINE:~0,3!"
    if "!PREFIX!=="IP=" set IP=!LINE:~3!
    set "PREFIX=!LINE:~0,5!"
    if "!PREFIX!=="PORT=" set PORT=!LINE:~5!
    set "PREFIX=!LINE:~0,6!"
    if "!PREFIX!=="ERROR=" set ERROR_MSG=!LINE:~6!
)

REM 删除临时脚本
del "%PS_SCRIPT%" 2>nul

REM 检查是否获取成功
if defined ERROR_MSG (
    echo 错误: !ERROR_MSG!
    pause
    exit /b 1
)

if "!IP!"=="" (
    echo 错误: 无法获取 IP 地址
    pause
    exit /b 1
)

if "!PORT!"=="" (
    echo 错误: 无法获取端口号
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
