export async function onRequestGet(context){
  try {
    const db = context.env.DB
    const kv = context.env.NATMAP_KV
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }
    
    const url = new URL(context.request.url)
    const tenantId = url.searchParams.get("tenant_id")
    const appId = url.searchParams.get("app_id")
    
    if (!tenantId || !appId) {
      return new Response(JSON.stringify({error: "Missing tenant_id or app_id parameter"}), {
        status: 400,
        headers: {"Content-Type": "application/json"}
      })
    }

    const cacheKey = `mapping:${tenantId}:${appId}`
    
    // 1. 先尝试从 KV 读取缓存
    if (kv) {
      try {
        const cached = await kv.get(cacheKey, { type: 'json' })
        if (cached) {
          return Response.json(cached)
        }
      } catch (e) {
        // KV 读取失败，继续查询 D1
        console.error('KV read error:', e)
      }
    }

    // 2. KV 未命中或不可用，查询 D1
    const result = await db.prepare(`
      SELECT public_ip,public_port,updated_at
      FROM mappings m
      WHERE m.tenant_id=? AND m.app_id=?
      ORDER BY updated_at DESC
      LIMIT 1
    `)
    .bind(parseInt(tenantId), parseInt(appId))
    .first()

    if(!result){
      return new Response(JSON.stringify({error: "not found"}), {
        status: 404,
        headers: {"Content-Type": "application/json"}
      })
    }

    // 将 UTC 时间转换为北京时间 (UTC+8)
    if (result.updated_at) {
      const utcDate = new Date(result.updated_at + 'Z')
      const beijingDate = new Date(utcDate.getTime() + 8 * 60 * 60 * 1000)
      result.updated_at = beijingDate.toISOString().slice(0, 19).replace('T', ' ')
    }

    // 3. 写入 KV 缓存（异步，不阻塞响应）
    if (kv) {
      context.waitUntil(
        kv.put(cacheKey, JSON.stringify(result), { 
          expirationTtl: 30  // 30秒过期
        }).catch(e => console.error('KV write error:', e))
      )
    }

    return Response.json(result)
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}