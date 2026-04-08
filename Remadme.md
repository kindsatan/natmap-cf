是的，你说的 Cloudflare Pages 直接绑定 D1 数据库是现在官方推荐方式。
如果你 通过 Cloudflare Dashboard 绑定 D1，通常 不需要 wrangler.toml（除非你用 CLI 自动化部署）。

下面给你一套 完整 Pages + D1 绑定部署步骤。

一、创建 D1 数据库

进入
Cloudflare Dashboard

打开：

Workers & Pages
 → D1

点击：

Create database

填写：

Database name: natmap-db

创建完成。

二、初始化数据库表

进入数据库：

natmap-db

点击：

Console

执行 SQL：

CREATE TABLE tenants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    api_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE apps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id INTEGER NOT NULL,
    app_name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

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
三、初始化租户和应用

继续执行：

INSERT INTO tenants (name,api_key)
VALUES ('companyA','abc123apikey');

INSERT INTO apps (tenant_id,app_name)
VALUES (1,'vpn');
四、创建 Pages 项目

进入：

Workers & Pages
 → Pages

点击：

Create application

选择：

Upload assets

或者

Connect Git

推荐 Git 部署。

五、Pages 项目结构

你的代码仓库结构：

pages
 ├ api
 │  ├ update.js
 │  └ get.js
 └ _middleware.js

例如：

natmap-cf
 └ pages
    ├ api
    │  ├ update.js
    │  └ get.js
    └ _middleware.js
六、绑定 D1 数据库

进入：

Pages
 → natmap-cf
 → Settings

打开：

Functions

点击：

D1 database bindings

添加：

Variable name : DB
Database      : natmap-db

保存。

此时：

context.env.DB

就能直接使用。

七、_middleware.js

路径：

pages/_middleware.js

代码：

export async function onRequest(context) {

  const { request, env, next } = context
  const url = new URL(request.url)

  if (!url.pathname.startsWith("/api/")) {
    return next()
  }

  if (url.pathname === "/api/update") {

    const api_key = request.headers.get("X-API-Key")

    if (!api_key) {
      return new Response("missing api_key",{status:401})
    }

    const tenant = await env.DB.prepare(
      "SELECT id FROM tenants WHERE api_key=?"
    ).bind(api_key).first()

    if (!tenant) {
      return new Response("invalid api_key",{status:403})
    }

    context.data.tenant_id = tenant.id
  }

  return next()
}
八、update.js

路径：

pages/api/update.js

代码：

export async function onRequestPost(context){

  const db = context.env.DB
  const tenant_id = context.data.tenant_id
  const body = await context.request.json()

  const app = body.app
  const ip = body.ip
  const port = body.port
  const proto = body.proto
  const local_ip = body.local_ip
  const local_port = body.local_port

  const appRow = await db.prepare(
    "SELECT id FROM apps WHERE tenant_id=? AND app_name=?"
  ).bind(tenant_id,app).first()

  if(!appRow){
    return new Response("app not found",{status:404})
  }

  await db.prepare(
    "DELETE FROM mappings WHERE tenant_id=? AND app_id=?"
  ).bind(tenant_id,appRow.id).run()

  await db.prepare(`
    INSERT INTO mappings
    (tenant_id,app_id,public_ip,public_port,local_ip,local_port,protocol,updated_at)
    VALUES (?,?,?,?,?,?,?,CURRENT_TIMESTAMP)
  `)
  .bind(
    tenant_id,
    appRow.id,
    ip,
    port,
    local_ip,
    local_port,
    proto
  )
  .run()

  return Response.json({status:"ok"})
}
九、get.js

路径：

pages/api/get.js

代码：

export async function onRequestGet(context){

  const db = context.env.DB
  const url = new URL(context.request.url)

  const tenant = url.searchParams.get("tenant")
  const app = url.searchParams.get("app")

  const result = await db.prepare(`
    SELECT public_ip,public_port,updated_at
    FROM mappings m
    JOIN tenants t ON m.tenant_id=t.id
    JOIN apps a ON m.app_id=a.id
    WHERE t.name=? AND a.app_name=?
    ORDER BY updated_at DESC
    LIMIT 1
  `)
  .bind(tenant,app)
  .first()

  if(!result){
    return new Response("not found",{status:404})
  }

  return Response.json(result)
}
十、natmap 更新脚本
/root/domain.sh
#!/bin/bash

API="https://natmap-cf.pages.dev/api/update"
API_KEY="abc123apikey"
APP="vpn"

PUB_IP=$1
PUB_PORT=$2
IPV6=$3
OUT_PORT=$4
PROTO=$5
LOCAL_IP=$6

curl -s -X POST $API \
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

权限：

chmod +x /root/domain.sh
十一、natmap 启动
natmap \
-s stun.kszhc.top \
-h www.baidu.com \
-b 60001 \
-e /root/domain.sh \
-t 192.168.199.148 \
-p 9001 >> /root/natmap.log &
十二、客户端连接
connect.sh
#!/bin/bash

API="https://natmap-cf.pages.dev/api/get?tenant=companyA&app=vpn"

DATA=$(curl -s $API)

IP=$(echo $DATA | jq -r .public_ip)
PORT=$(echo $DATA | jq -r .public_port)

echo "connect $IP:$PORT"

nc $IP $PORT
十三、总结

使用 Cloudflare Pages Dashboard 绑定 D1：

✔ 不需要 wrangler.toml
✔ 不需要 CLI
✔ 部署更简单

只有在以下情况才需要 wrangler.toml：

CLI 自动部署
CI/CD
多环境配置
Workers 项目

如果你愿意，我可以再给你一套 更高级版本（强烈推荐）：

客户端永远访问固定域名

vpn.example.com

即使：

natmap IP变化
natmap PORT变化

客户端 完全不需要重新获取地址。
这是很多 大型 NAT 穿透系统的架构方案。