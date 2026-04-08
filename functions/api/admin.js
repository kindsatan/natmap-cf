export async function onRequestGet(context) {
  try {
    const db = context.env.DB
    
    if (!db) {
      return new Response(JSON.stringify({error: "Database not configured"}), {
        status: 500,
        headers: {"Content-Type": "application/json"}
      })
    }

    // 获取所有租户列表
    const tenants = await db.prepare(
      "SELECT id, name, created_at FROM tenants ORDER BY id"
    ).all()

    // 获取所有应用列表
    const apps = await db.prepare(
      "SELECT a.id, a.app_name, a.tenant_id, t.name as tenant_name FROM apps a JOIN tenants t ON a.tenant_id = t.id ORDER BY a.id"
    ).all()

    return Response.json({
      tenants: tenants.results || [],
      apps: apps.results || []
    })
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}

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
    const action = body.action

    if (action === "add_tenant") {
      const { name, api_key } = body
      
      if (!name || !api_key) {
        return new Response(JSON.stringify({error: "Missing name or api_key"}), {
          status: 400,
          headers: {"Content-Type": "application/json"}
        })
      }

      const result = await db.prepare(
        "INSERT INTO tenants (name, api_key) VALUES (?, ?)"
      ).bind(name, api_key).run()

      return Response.json({
        success: true,
        message: "Tenant added successfully",
        id: result.meta?.last_row_id
      })
    }

    if (action === "add_app") {
      const { tenant_id, app_name } = body
      
      if (!tenant_id || !app_name) {
        return new Response(JSON.stringify({error: "Missing tenant_id or app_name"}), {
          status: 400,
          headers: {"Content-Type": "application/json"}
        })
      }

      const result = await db.prepare(
        "INSERT INTO apps (tenant_id, app_name) VALUES (?, ?)"
      ).bind(tenant_id, app_name).run()

      return Response.json({
        success: true,
        message: "App added successfully",
        id: result.meta?.last_row_id
      })
    }

    return new Response(JSON.stringify({error: "Unknown action"}), {
      status: 400,
      headers: {"Content-Type": "application/json"}
    })
  } catch (error) {
    return new Response(JSON.stringify({error: error.message}), {
      status: 500,
      headers: {"Content-Type": "application/json"}
    })
  }
}
