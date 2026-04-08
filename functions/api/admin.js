// 完整的 Admin API - 支持租户、应用、映射的 CRUD 操作

// GET - 获取数据列表
export async function onRequestGet(context) {
  try {
    const db = context.env.DB
    const url = new URL(context.request.url)
    const type = url.searchParams.get("type") || "all"
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }

    let result = {}

    // 获取租户列表
    if (type === "all" || type === "tenants") {
      const tenantsResult = await db.prepare(
        "SELECT id, name, api_key, created_at FROM tenants ORDER BY id"
      ).all()
      let tenants = Array.isArray(tenantsResult) ? tenantsResult : (tenantsResult.results || [])
      tenants = tenants.map(t => ({
        ...t,
        created_at: formatBeijingTime(t.created_at)
      }))
      result.tenants = tenants
    }

    // 获取应用列表
    if (type === "all" || type === "apps") {
      const appsResult = await db.prepare(
        `SELECT a.id, a.app_name, a.tenant_id, a.description, a.created_at, t.name as tenant_name 
         FROM apps a 
         JOIN tenants t ON a.tenant_id = t.id 
         ORDER BY a.id`
      ).all()
      let apps = Array.isArray(appsResult) ? appsResult : (appsResult.results || [])
      apps = apps.map(a => ({
        ...a,
        created_at: formatBeijingTime(a.created_at)
      }))
      result.apps = apps
    }

    // 获取映射列表
    if (type === "all" || type === "mappings") {
      const mappingsResult = await db.prepare(
        `SELECT m.id, m.public_ip, m.public_port, m.local_ip, m.local_port, m.protocol, 
                m.updated_at, m.tenant_id, m.app_id,
                t.name as tenant_name, a.app_name
         FROM mappings m
         JOIN tenants t ON m.tenant_id = t.id
         JOIN apps a ON m.app_id = a.id
         ORDER BY m.updated_at DESC
         LIMIT 100`
      ).all()
      let mappings = Array.isArray(mappingsResult) ? mappingsResult : (mappingsResult.results || [])
      mappings = mappings.map(m => ({
        ...m,
        updated_at: formatBeijingTime(m.updated_at)
      }))
      result.mappings = mappings
    }

    return Response.json(result)
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}

// POST - 创建数据
export async function onRequestPost(context) {
  try {
    const db = context.env.DB
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }

    const body = await context.request.json()
    const { type, data } = body

    // 输入验证和清理
    if (!type || !data) {
      return new Response(JSON.stringify({error: "Missing type or data"}), {
        status: 400,
        headers: {"Content-Type": "application/json"}
      })
    }

    switch (type) {
      case "tenant":
        return await createTenant(db, data)
      case "app":
        return await createApp(db, data)
      default:
        return new Response(JSON.stringify({error: "Unknown type"}), {
          status: 400,
          headers: {"Content-Type": "application/json"}
        })
    }
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}

// PUT - 更新数据
export async function onRequestPut(context) {
  try {
    const db = context.env.DB
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }

    const body = await context.request.json()
    const { type, id, data } = body

    if (!type || !id || !data) {
      return new Response(JSON.stringify({error: "Missing type, id or data"}), {
        status: 400,
        headers: {"Content-Type": "application/json"}
      })
    }

    switch (type) {
      case "tenant":
        return await updateTenant(db, id, data)
      case "app":
        return await updateApp(db, id, data)
      default:
        return new Response(JSON.stringify({error: "Unknown type"}), {
          status: 400,
          headers: {"Content-Type": "application/json"}
        })
    }
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}

// DELETE - 删除数据
export async function onRequestDelete(context) {
  try {
    const db = context.env.DB
    const kv = context.env.NATMAP_KV
    const url = new URL(context.request.url)
    const type = url.searchParams.get("type")
    const id = url.searchParams.get("id")
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }

    if (!type || !id) {
      return new Response(JSON.stringify({error: "Missing type or id"}), {
        status: 400,
        headers: {"Content-Type": "application/json"}
      })
    }

    switch (type) {
      case "tenant":
        return await deleteTenant(db, id)
      case "app":
        return await deleteApp(db, id)
      case "mapping":
        return await deleteMapping(db, kv, id)
      default:
        return new Response(JSON.stringify({error: "Unknown type"}), {
          status: 400,
          headers: {"Content-Type": "application/json"}
        })
    }
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}

// ===== 辅助函数 =====

// 格式化北京时间为字符串
function formatBeijingTime(dateStr) {
  if (!dateStr) return null
  try {
    const utcDate = new Date(dateStr + 'Z')
    const beijingDate = new Date(utcDate.getTime() + 8 * 60 * 60 * 1000)
    return beijingDate.toISOString().slice(0, 19).replace('T', ' ')
  } catch {
    return dateStr
  }
}

// 清理输入字符串（防止 XSS）
function sanitize(str) {
  if (typeof str !== 'string') return ''
  return str.replace(/[<>"']/g, '').trim()
}

// ===== CRUD 操作函数 =====

async function createTenant(db, data) {
  const name = sanitize(data.name)
  const apiKey = sanitize(data.api_key)
  
  if (!name || !apiKey) {
    return new Response(JSON.stringify({error: "名称和API Key不能为空"}), {
      status: 400,
      headers: {"Content-Type": "application/json"}
    })
  }

  // 检查名称是否已存在
  const existing = await db.prepare(
    "SELECT id FROM tenants WHERE name = ?"
  ).bind(name).first()
  
  if (existing) {
    return new Response(JSON.stringify({error: "公司名称已存在"}), {
      status: 409,
      headers: {"Content-Type": "application/json"}
    })
  }

  const result = await db.prepare(
    "INSERT INTO tenants (name, api_key) VALUES (?, ?)"
  ).bind(name, apiKey).run()

  return Response.json({
    success: true,
    message: "公司创建成功",
    id: result.meta?.last_row_id
  })
}

async function createApp(db, data) {
  const tenantId = parseInt(data.tenant_id)
  const appName = sanitize(data.app_name)
  const description = data.description ? sanitize(data.description) : null
  
  if (!tenantId || !appName) {
    return new Response(JSON.stringify({error: "所属公司和应用名称不能为空"}), {
      status: 400,
      headers: {"Content-Type": "application/json"}
    })
  }

  // 检查公司是否存在
  const tenant = await db.prepare(
    "SELECT id FROM tenants WHERE id = ?"
  ).bind(tenantId).first()
  
  if (!tenant) {
    return new Response(JSON.stringify({error: "所属公司不存在"}), {
      status: 404,
      headers: {"Content-Type": "application/json"}
    })
  }

  // 检查应用名称是否已存在
  const existing = await db.prepare(
    "SELECT id FROM apps WHERE tenant_id = ? AND app_name = ?"
  ).bind(tenantId, appName).first()
  
  if (existing) {
    return new Response(JSON.stringify({error: "该应用名称已存在"}), {
      status: 409,
      headers: {"Content-Type": "application/json"}
    })
  }

  const result = await db.prepare(
    "INSERT INTO apps (tenant_id, app_name, description) VALUES (?, ?, ?)"
  ).bind(tenantId, appName, description).run()

  return Response.json({
    success: true,
    message: "应用创建成功",
    id: result.meta?.last_row_id
  })
}

async function updateTenant(db, id, data) {
  const name = sanitize(data.name)
  const apiKey = sanitize(data.api_key)
  
  if (!name || !apiKey) {
    return new Response(JSON.stringify({error: "名称和API Key不能为空"}), {
      status: 400,
      headers: {"Content-Type": "application/json"}
    })
  }

  // 检查是否与其他租户冲突
  const existing = await db.prepare(
    "SELECT id FROM tenants WHERE name = ? AND id != ?"
  ).bind(name, id).first()
  
  if (existing) {
    return new Response(JSON.stringify({error: "公司名称已存在"}), {
      status: 409,
      headers: {"Content-Type": "application/json"}
    })
  }

  await db.prepare(
    "UPDATE tenants SET name = ?, api_key = ? WHERE id = ?"
  ).bind(name, apiKey, id).run()

  return Response.json({
    success: true,
    message: "公司更新成功"
  })
}

async function updateApp(db, id, data) {
  const tenantId = parseInt(data.tenant_id)
  const appName = sanitize(data.app_name)
  const description = data.description ? sanitize(data.description) : null
  
  if (!tenantId || !appName) {
    return new Response(JSON.stringify({error: "所属公司和应用名称不能为空"}), {
      status: 400,
      headers: {"Content-Type": "application/json"}
    })
  }

  // 检查是否与其他应用冲突
  const existing = await db.prepare(
    "SELECT id FROM apps WHERE tenant_id = ? AND app_name = ? AND id != ?"
  ).bind(tenantId, appName, id).first()
  
  if (existing) {
    return new Response(JSON.stringify({error: "该应用名称已存在"}), {
      status: 409,
      headers: {"Content-Type": "application/json"}
    })
  }

  await db.prepare(
    "UPDATE apps SET tenant_id = ?, app_name = ?, description = ? WHERE id = ?"
  ).bind(tenantId, appName, description, id).run()

  return Response.json({
    success: true,
    message: "应用更新成功"
  })
}

async function deleteTenant(db, id) {
  // 检查是否有关联的应用
  const apps = await db.prepare(
    "SELECT COUNT(*) as count FROM apps WHERE tenant_id = ?"
  ).bind(id).first()
  
  if (apps.count > 0) {
    return new Response(JSON.stringify({error: "该公司下还有应用，无法删除"}), {
      status: 409,
      headers: {"Content-Type": "application/json"}
    })
  }

  await db.prepare("DELETE FROM tenants WHERE id = ?").bind(id).run()

  return Response.json({
    success: true,
    message: "公司删除成功"
  })
}

async function deleteApp(db, id) {
  // 检查是否有关联的映射
  const mappings = await db.prepare(
    "SELECT COUNT(*) as count FROM mappings WHERE app_id = ?"
  ).bind(id).first()
  
  if (mappings.count > 0) {
    return new Response(JSON.stringify({error: "该应用下还有映射记录，无法删除"}), {
      status: 409,
      headers: {"Content-Type": "application/json"}
    })
  }

  await db.prepare("DELETE FROM apps WHERE id = ?").bind(id).run()

  return Response.json({
    success: true,
    message: "应用删除成功"
  })
}

async function deleteMapping(db, kv, id) {
  // 先查询出映射信息，用于清除缓存
  let mappingInfo = null
  if (kv) {
    try {
      mappingInfo = await db.prepare(
        "SELECT tenant_id, app_id FROM mappings WHERE id = ?"
      ).bind(id).first()
    } catch (e) {
      console.error('Query mapping for cache clear error:', e)
    }
  }
  
  await db.prepare("DELETE FROM mappings WHERE id = ?").bind(id).run()
  
  // 清除对应的 KV 缓存
  if (kv && mappingInfo) {
    const cacheKey = `mapping:${mappingInfo.tenant_id}:${mappingInfo.app_id}`
    await kv.delete(cacheKey).catch(e => console.error('KV delete error:', e))
  }

  return Response.json({
    success: true,
    message: "映射记录删除成功"
  })
}
