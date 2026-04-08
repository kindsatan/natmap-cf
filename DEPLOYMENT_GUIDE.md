# NATMap Cloudflare Pages 部署指南

## 项目概述

NATMap 是一个部署在 Cloudflare Pages 上的 NAT 穿透映射服务，用于动态更新和查询 NAT 穿透后的公网地址。

**功能特性：**
- 动态更新公网 IP 和端口映射
- 查询映射记录
- 多租户支持
- 现代化的管理后台
- 跨平台客户端脚本

---

## 系统架构

```
Cloudflare Pages (静态托管 + Functions)
├── 静态文件
│   ├── index.html          # 首页
│   └── admin.html          # 管理后台 (React + Material-UI)
│
├── Functions (API)
│   ├── _middleware.js      # 认证中间件
│   └── api/
│       ├── admin.js        # 管理 API (CRUD)
│       ├── get.js          # 查询映射
│       ├── update.js       # 更新映射
│       └── test.js         # 健康检查
│
└── 客户端脚本
    └── scripts/
        ├── update.sh       # Linux/macOS 更新脚本
        ├── update.ps1      # Windows 更新脚本
        ├── get.sh          # Linux/macOS 查询脚本
        ├── get.ps1         # Windows 查询脚本
        ├── connect.sh      # Linux/macOS 连接脚本
        └── connect.ps1     # Windows 连接脚本
```

---

## 部署步骤

### 1. 创建 D1 数据库

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 进入 **Workers & Pages** → **D1**
3. 点击 **Create database**
4. 填写名称：`natmap-db`
5. 创建完成

### 2. 初始化数据库表

进入数据库 → **Console**，执行以下 SQL：

```sql
-- 租户表
CREATE TABLE tenants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    api_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 应用表
CREATE TABLE apps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id INTEGER NOT NULL,
    app_name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

-- 映射表
CREATE TABLE mappings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id INTEGER NOT NULL,
    app_id INTEGER NOT NULL,
    public_ip TEXT NOT NULL,
    public_port INTEGER NOT NULL,
    local_ip TEXT,
    local_port INTEGER,
    protocol TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 3. 创建 Pages 项目

1. 进入 **Workers & Pages** → **Pages** → **Create application**
2. 选择 **Connect to Git**
3. 授权并选择 GitHub 仓库 `natmap-cf`
4. 配置构建设置：
   - **Build command**: `npm run deploy` (或 `echo "No build needed"`)
   - **Build output directory**: 留空
5. 点击 **Save and Deploy**

### 4. 绑定 D1 数据库

1. 进入项目 → **Settings** → **Functions** → **D1 database bindings**
2. 添加绑定：
   - **Variable name**: `DB`
   - **Database**: `natmap-db`
3. 保存并重新部署

### 5. 配置管理后台密钥

1. 进入项目 → **Settings** → **Environment variables**
2. 添加变量：
   - **Variable name**: `ADMIN_KEY`
   - **Value**: 设置一个强密码（如 `YourStrongPassword123!`）
3. 保存并重新部署

---

## 管理后台使用

### 访问地址

```
https://your-domain.pages.dev/admin.html?key=YOUR_ADMIN_KEY
```

### 功能说明

**公司管理：**
- 添加公司：输入公司名称和 API Key
- 编辑公司：修改名称或 API Key
- 删除公司：删除前会检查是否有关联应用

**应用管理：**
- 添加应用：选择所属公司，输入应用名称
- 编辑应用：修改所属公司或应用名称
- 删除应用：删除前会检查是否有关联映射

**映射记录：**
- 查看所有映射记录（显示最新100条）
- 删除映射记录
- 显示信息：公网IP:端口、本地IP:端口、协议、更新时间

---

## API 接口文档

### 更新映射

```http
POST /api/update
Content-Type: application/json
X-API-Key: your-api-key

{
    "app": "vpn",
    "ip": "1.2.3.4",
    "port": 12345,
    "proto": "tcp",
    "local_ip": "192.168.1.100",
    "local_port": 9001
}
```

**响应：**
```json
{"status": "ok"}
```

### 查询映射

```http
GET /api/get?tenant=companyA&app=vpn
```

**响应：**
```json
{
    "public_ip": "1.2.3.4",
    "public_port": 12345,
    "updated_at": "2026-04-08 15:30:00"
}
```

### 健康检查

```http
GET /api/test
```

**响应：**
```
OK
```

---

## 客户端脚本使用

### Windows (PowerShell)

```powershell
# 查询映射
.\scripts\get.ps1

# 更新映射
.\scripts\update.ps1 -PublicIp "1.2.3.4" -PublicPort 12345
```

### Linux/macOS (Bash)

```bash
# 查询映射
./scripts/get.sh

# 更新映射
./scripts/update.sh 1.2.3.4 12345 :: 0 tcp 192.168.1.100
```

---

## NATMap 集成示例

### 更新脚本 (domain.sh)

```bash
#!/bin/bash

API="https://your-domain.pages.dev/api/update"
API_KEY="abc123apikey"
APP="vpn"

PUB_IP=$1
PUB_PORT=$2
PROTO=$5
LOCAL_IP=$6

curl -s -X POST "$API" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d "{
        \"app\":\"$APP\",
        \"ip\":\"$PUB_IP\",
        \"port\":$PUB_PORT,
        \"proto\":\"$PROTO\",
        \"local_ip\":\"$LOCAL_IP\",
        \"local_port\":9001
    }"
```

### NATMap 启动命令

```bash
natmap \
    -s stun.kszhc.top \
    -h www.baidu.com \
    -b 60001 \
    -e /root/domain.sh \
    -t 192.168.199.148 \
    -p 9001
```

---

## 安全建议

1. **API Key 管理**
   - 定期更换 API Key
   - 为不同应用使用不同的 API Key
   - 避免在代码中硬编码 API Key

2. **Admin Key 保护**
   - 使用强密码
   - 不要泄露管理后台 URL
   - 定期更换 Admin Key

3. **数据库安全**
   - 定期备份 D1 数据库
   - 监控异常访问模式

---

## 故障排查

### 404 错误
- 检查 Functions 是否正确部署
- 确认 D1 数据库绑定是否配置

### 401/403 错误
- 检查 API Key 是否正确
- 确认请求头格式是否正确

### 数据库错误
- 检查表结构是否正确创建
- 确认外键关系是否正确

---

## 技术栈

- **平台**: Cloudflare Pages + D1
- **前端**: React 18 + Material-UI 5
- **后端**: Cloudflare Pages Functions
- **数据库**: SQLite (D1)

---

## 许可证

MIT License
