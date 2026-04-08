@echo off
chcp 65001 >nul

REM NATMap Client 启动脚本
REM 通过 API 获取最新映射地址并启动 client.exe

REM 配置参数
set TENANT_ID=3
set APP_ID=3
set TOKEN=zhc
set TRANSPORT=tcp

echo 正在获取最新映射地址...

REM 使用 curl 获取数据
curl -s "https://nm.kszhc.top/api/get?tenant_id=%TENANT_ID%&app_id=%APP_ID%" > %TEMP%\natmap_response.json

REM 解析 JSON 获取 IP 和端口
for /f "tokens=2 delims=:" %%a in ('findstr "public_ip" %TEMP%\natmap_response.json') do (
    set IP=%%a
    set IP=!IP:"=!
    set IP=!IP: =!
    set IP=!IP:,=!
)

for /f "tokens=2 delims=:" %%b in ('findstr "public_port" %TEMP%\natmap_response.json') do (
    set PORT=%%b
    set PORT=!PORT:"=!
    set PORT=!PORT: =!
    set PORT=!PORT:,=!
    set PORT=!PORT:}=!
)

REM 删除临时文件
del %TEMP%\natmap_response.json 2>nul

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
