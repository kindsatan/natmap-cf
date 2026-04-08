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

REM 获取映射数据
echo 正在获取最新映射地址...

for /f "delims=" %%i in ('powershell -NoProfile -Command "
    $url = 'https://nm.kszhc.top/api/get?tenant_id=%TENANT_ID%&app_id=%APP_ID%';
    try {
        $r = Invoke-RestMethod -Uri $url -Method GET -UseBasicParsing;
        if ($r.public_ip -and $r.public_port) {
            Write-Host ('IP=' + $r.public_ip);
            Write-Host ('PORT=' + $r.public_port);
        } else {
            Write-Host 'ERROR=无法解析响应数据';
        }
    } catch {
        Write-Host ('ERROR=' + $_.Exception.Message);
    }
"') do (
    set "LINE=%%i"
    if "!LINE:~0,3!="IP=" set IP=!LINE:~3!
    if "!LINE:~0,5!="PORT=" set PORT=!LINE:~5!
    if "!LINE:~0,6!="ERROR=" set ERROR_MSG=!LINE:~6!
)

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
